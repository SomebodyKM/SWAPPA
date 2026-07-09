import { Types } from 'mongoose';
import { User, UserDoc } from '../models/user.model';
import { SkillTag } from '../models/skillTag.model';
import { tierLimits } from '../config/limits';
import { safetyService } from './safety.service';
import { serializeUserLocation, SerializedLocation } from './locationPresenter';
import { Errors } from '../utils/errors';

export type MatchMode = 'local' | 'remote';

export interface MatchQuery {
  skillId?: string;
  mode: MatchMode;
  radius?: number; // meters (local only)
  mutualOnly?: boolean;
  uncapped?: boolean; // Deep Re-Match (paid AI action) bypasses the free-tier result cap
}

export interface MatchResult {
  candidateId: string;
  displayName: string;
  photoUrl?: string;
  ratingAvg: number;
  sharedSkillIds: string[]; // skills the candidate teaches that the seeker wants
  teachesName?: string; // display name of a skill the candidate teaches
  wantsName?: string; // display name of a skill the candidate wants to learn
  mutual: boolean;
  location: SerializedLocation; // free/premium presentation rules applied — never hand-rolled
  score: number;
}

/**
 * A non-identifying preview of a match hidden behind the free-tier cap — no
 * candidateId/displayName/photoUrl/ratingAvg, so it's safe to send even
 * though the person themselves stays locked. Lets free users see "there's
 * someone who teaches X, 3km away" without revealing who.
 */
export interface MatchTeaser {
  teachesName?: string;
  wantsName?: string;
  distanceLabel: string | null;
  mutual: boolean;
}

const PROFICIENCY_WEIGHT: Record<string, number> = {
  beginner: 1,
  intermediate: 2,
  advanced: 3,
  expert: 4,
};

/** Common shape iterated over regardless of which query produced it. */
interface Candidate {
  _id: Types.ObjectId;
  displayName: string;
  photoUrl?: string;
  ratingAvg: number;
  location?: UserDoc['location'];
  distanceMeters?: number; // present only for 'local' mode ($geoNear-computed)
}

export const matchingService = {
  /**
   * Discovery + matching. Free-tier results are capped at `tierLimits.matchResults`
   * and the local radius is clamped to the tier's max (FR-004/FR-007/FR-031).
   */
  async findMatches(
    userId: string,
    q: MatchQuery,
  ): Promise<{
    items: MatchResult[];
    capped: boolean;
    limit: number;
    totalCount: number;
    teasers: MatchTeaser[];
  }> {
    const me = await User.findById(userId).select('tier location');
    if (!me) throw Errors.notFound('User not found');
    const limits = tierLimits(me.tier);

    // What I want and what I offer.
    const [wantedSkills, offeredSkills] = await Promise.all([
      SkillTag.find({ user: userId, kind: 'want' }).distinct('skill'),
      SkillTag.find({ user: userId, kind: 'offer' }).distinct('skill'),
    ]);

    const targetSkills = q.skillId ? [new Types.ObjectId(q.skillId)] : (wantedSkills as Types.ObjectId[]);

    // Candidates: users who teach one of the target skills.
    const candidateSkills = new Map<string, Set<string>>(); // candidateId -> sharedSkillIds
    const proficiencyByCandidate = new Map<string, number>();
    if (targetSkills.length > 0) {
      const offerTags = await SkillTag.find({
        kind: 'offer',
        skill: { $in: targetSkills },
        user: { $ne: new Types.ObjectId(userId) },
      });
      for (const tag of offerTags) {
        const cid = String(tag.user);
        if (!candidateSkills.has(cid)) candidateSkills.set(cid, new Set());
        candidateSkills.get(cid)!.add(String(tag.skill));
        const w = PROFICIENCY_WEIGHT[tag.proficiency ?? 'beginner'] ?? 1;
        proficiencyByCandidate.set(cid, Math.max(proficiencyByCandidate.get(cid) ?? 0, w));
      }
    }

    let candidateIds = [...candidateSkills.keys()];

    // TEMP fallback while real skill-tag matching test data is sparse: if
    // skill-based matching finds nobody, browse everyone else instead so
    // Discovery has real cards to test against. Remove once accounts have
    // enough real offer/want tags for the skill-matching path to populate
    // Discovery on its own.
    if (candidateIds.length === 0) {
      const everyone = await User.find({ _id: { $ne: new Types.ObjectId(userId) }, status: 'active' }).select('_id');
      candidateIds = everyone.map((u) => String(u._id));
    }

    if (candidateIds.length === 0) return { items: [], capped: false, limit: limits.matchResults, totalCount: 0, teasers: [] };

    // Display-only: a representative "teaches"/"wants" skill name per
    // candidate for the Discovery card — independent of the matching logic
    // above (which only tracks *my* wanted skills), so it still shows
    // something for browse-all fallback candidates too.
    const teachesNameByCandidate = new Map<string, string>();
    const wantsNameByCandidate = new Map<string, string>();
    const displayTags = await SkillTag.find({
      user: { $in: candidateIds.map((id) => new Types.ObjectId(id)) },
      kind: { $in: ['offer', 'want'] },
    }).populate<{ skill: { name: string } }>('skill', 'name');
    for (const tag of displayTags) {
      const cid = String(tag.user);
      const name = tag.skill?.name;
      if (!name) continue;
      if (tag.kind === 'offer' && !teachesNameByCandidate.has(cid)) teachesNameByCandidate.set(cid, name);
      if (tag.kind === 'want' && !wantsNameByCandidate.has(cid)) wantsNameByCandidate.set(cid, name);
    }

    // Mutual candidates: those who want one of my offered skills.
    let mutualSet = new Set<string>();
    if (offeredSkills.length > 0) {
      const mutualTags = await SkillTag.find({
        kind: 'want',
        skill: { $in: offeredSkills },
        user: { $in: candidateIds.map((id) => new Types.ObjectId(id)) },
      }).distinct('user');
      mutualSet = new Set(mutualTags.map((u) => String(u)));
    }

    // Exclude users the seeker has blocked or been blocked by (FR-034).
    const blocked = await safetyService.blockedUserIds(userId);
    const candidateObjectIds = candidateIds.map((id) => new Types.ObjectId(id));

    // Radius is clamped to the tier's max server-side — a client can request
    // less, never more (FR-004/FR-007/FR-031).
    const radius = Math.min(q.radius ?? limits.mapRadiusMeters, limits.mapRadiusMeters);
    const myCoords = me.location?.point?.coordinates;

    let candidates: Candidate[];
    if (q.mode === 'local') {
      // No location of my own → nothing can be "local" (need both ends to compute a distance).
      if (!myCoords) return { items: [], capped: false, limit: limits.matchResults, totalCount: 0, teasers: [] };

      // $geoNear uses the location.point 2dsphere index directly — candidates
      // outside `radius` are excluded by MongoDB, never loaded into memory.
      candidates = await User.aggregate<Candidate>([
        {
          $geoNear: {
            near: { type: 'Point', coordinates: myCoords },
            distanceField: 'distanceMeters',
            maxDistance: radius,
            spherical: true,
            // Admin accounts are never real swap candidates (FR-034-adjacent —
            // not a safety exclusion, just not a real user to match with).
            query: { _id: { $in: candidateObjectIds, $nin: blocked }, status: 'active', role: { $ne: 'admin' } },
          },
        },
        { $project: { displayName: 1, photoUrl: 1, ratingAvg: 1, location: 1, distanceMeters: 1 } },
      ]);
    } else {
      candidates = await User.find({
        _id: { $in: candidateObjectIds, $nin: blocked },
        status: 'active',
        role: { $ne: 'admin' },
      }).select('displayName photoUrl ratingAvg location');
    }

    let results: MatchResult[] = [];
    for (const u of candidates) {
      const cid = String(u._id);
      const mutual = mutualSet.has(cid);
      if (q.mutualOnly && !mutual) continue;

      const distanceMeters = q.mode === 'local' ? (u.distanceMeters ?? null) : null;
      const proximityScore = distanceMeters === null ? 0 : Math.max(0, 50 - distanceMeters / 1000);
      const score =
        (mutual ? 1000 : 0) +
        u.ratingAvg * 10 +
        (proficiencyByCandidate.get(cid) ?? 0) * 5 +
        proximityScore;

      results.push({
        candidateId: cid,
        displayName: u.displayName,
        photoUrl: u.photoUrl,
        ratingAvg: u.ratingAvg,
        sharedSkillIds: [...(candidateSkills.get(cid) ?? [])],
        teachesName: teachesNameByCandidate.get(cid),
        wantsName: wantsNameByCandidate.get(cid),
        mutual,
        location: serializeUserLocation(u, { tier: me.tier, location: me.location }),
        score,
      });
    }

    results.sort((a, b) => b.score - a.score);

    // Free tier sees only the top N (FR-004/FR-031), unless this is an uncapped Deep Re-Match.
    const limit = limits.matchResults;
    const totalCount = results.length;
    const capped = me.tier === 'free' && !q.uncapped && totalCount > limit;

    // A handful of non-identifying previews from just past the cap — lets
    // free users see "someone teaches X, 3km away" for the hidden tail
    // without revealing who, so browsing still feels alive under the cap
    // rather than a hard wall.
    const TEASER_PREVIEW_COUNT = 5;
    const teasers: MatchTeaser[] = capped
      ? results.slice(limit, limit + TEASER_PREVIEW_COUNT).map((r) => ({
          teachesName: r.teachesName,
          wantsName: r.wantsName,
          distanceLabel: r.location.distanceLabel,
          mutual: r.mutual,
        }))
      : [];

    if (me.tier === 'free' && !q.uncapped) results = results.slice(0, limit);

    return { items: results, capped, limit, totalCount, teasers };
  },
};
