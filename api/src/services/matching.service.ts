import { Types } from 'mongoose';
import { User } from '../models/user.model';
import { SkillTag } from '../models/skillTag.model';
import { tierLimits } from '../config/limits';
import { haversineMeters } from '../utils/geo';
import { safetyService } from './safety.service';
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
  mutual: boolean;
  distanceMeters: number | null;
  score: number;
}

const PROFICIENCY_WEIGHT: Record<string, number> = {
  beginner: 1,
  intermediate: 2,
  advanced: 3,
  expert: 4,
};

export const matchingService = {
  /**
   * Discovery + matching. Free-tier results are capped at `tierLimits.matchResults`
   * and the local radius is clamped to the tier's max (FR-004/FR-007/FR-031).
   */
  async findMatches(
    userId: string,
    q: MatchQuery,
  ): Promise<{ items: MatchResult[]; capped: boolean; limit: number }> {
    const me = await User.findById(userId).select('tier location');
    if (!me) throw Errors.notFound('User not found');
    const limits = tierLimits(me.tier);

    // What I want and what I offer.
    const [wantedSkills, offeredSkills] = await Promise.all([
      SkillTag.find({ user: userId, kind: 'want' }).distinct('skill'),
      SkillTag.find({ user: userId, kind: 'offer' }).distinct('skill'),
    ]);

    const targetSkills = q.skillId ? [new Types.ObjectId(q.skillId)] : (wantedSkills as Types.ObjectId[]);
    if (targetSkills.length === 0) return { items: [], capped: false, limit: limits.matchResults };

    // Candidates: users who teach one of the target skills.
    const offerTags = await SkillTag.find({
      kind: 'offer',
      skill: { $in: targetSkills },
      user: { $ne: new Types.ObjectId(userId) },
    });

    const candidateSkills = new Map<string, Set<string>>(); // candidateId -> sharedSkillIds
    const proficiencyByCandidate = new Map<string, number>();
    for (const tag of offerTags) {
      const cid = String(tag.user);
      if (!candidateSkills.has(cid)) candidateSkills.set(cid, new Set());
      candidateSkills.get(cid)!.add(String(tag.skill));
      const w = PROFICIENCY_WEIGHT[tag.proficiency ?? 'beginner'] ?? 1;
      proficiencyByCandidate.set(cid, Math.max(proficiencyByCandidate.get(cid) ?? 0, w));
    }
    const candidateIds = [...candidateSkills.keys()];
    if (candidateIds.length === 0) return { items: [], capped: false, limit: limits.matchResults };

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

    // Load candidate users (active only).
    const users = await User.find({
      _id: { $in: candidateIds.map((id) => new Types.ObjectId(id)), $nin: blocked },
      status: 'active',
    }).select('displayName photoUrl ratingAvg location');

    const radius = Math.min(q.radius ?? limits.mapRadiusMeters, limits.mapRadiusMeters);
    const myCoords = me.location?.coordinates;

    let results: MatchResult[] = [];
    for (const u of users) {
      const cid = String(u._id);
      const mutual = mutualSet.has(cid);
      if (q.mutualOnly && !mutual) continue;

      let distanceMeters: number | null = null;
      if (q.mode === 'local') {
        if (!myCoords || !u.location?.coordinates) continue; // need both locations
        distanceMeters = haversineMeters(myCoords, u.location.coordinates);
        if (distanceMeters > radius) continue;
      }

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
        mutual,
        distanceMeters,
        score,
      });
    }

    results.sort((a, b) => b.score - a.score);

    // Free tier sees only the top N (FR-004/FR-031), unless this is an uncapped Deep Re-Match.
    const limit = limits.matchResults;
    const capped = me.tier === 'free' && !q.uncapped && results.length > limit;
    if (me.tier === 'free' && !q.uncapped) results = results.slice(0, limit);

    return { items: results, capped, limit };
  },
};
