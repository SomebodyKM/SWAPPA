import { matchingService } from '../src/services/matching.service';
import { User, UserDoc } from '../src/models/user.model';
import { Skill } from '../src/models/skill.model';
import { SkillTag } from '../src/models/skillTag.model';
import { TIER_LIMITS } from '../src/config/limits';

const LONDON: [number, number] = [-0.14, 51.54];

/** Moves `km` due north — plenty accurate for placing test fixtures at a known distance. */
function pointNorthKm(base: [number, number], km: number): [number, number] {
  return [base[0], base[1] + km / 111.32];
}

async function makeUser(
  displayName: string,
  point: [number, number] | null,
  over: Partial<Record<string, unknown>> = {},
): Promise<UserDoc> {
  return User.create({
    email: `${displayName.toLowerCase()}-${Math.random()}@example.com`,
    passwordHash: 'x',
    displayName,
    emailVerified: true,
    location: point
      ? { point: { type: 'Point', coordinates: point }, precision: 'coarse', displayName: 'Test area' }
      : undefined,
    ...over,
  });
}

async function tag(userId: string, skillId: string, kind: 'offer' | 'want') {
  await SkillTag.create({
    user: userId,
    skill: skillId,
    kind,
    proficiency: kind === 'offer' ? 'intermediate' : undefined,
  });
}

describe('matchingService.findMatches — local radius (FR-004/FR-007/FR-031)', () => {
  // $geoNear needs the 2dsphere index built before it can run.
  beforeAll(async () => {
    await User.init();
  });

  it('only returns candidates within the tier-clamped radius, ignoring a larger client-requested radius', async () => {
    const skill = await Skill.create({ name: 'Guitar', nameNormalized: 'guitar', category: 'Music' });

    const me = await makeUser('Seeker', LONDON, { tier: 'free' });
    await tag(String(me._id), String(skill._id), 'want');

    // Within the free-tier cap (25km).
    const near = await makeUser('Near', pointNorthKm(LONDON, 5));
    await tag(String(near._id), String(skill._id), 'offer');

    // Beyond the free-tier cap (25km) but well within a maliciously large client radius.
    const far = await makeUser('Far', pointNorthKm(LONDON, 30));
    await tag(String(far._id), String(skill._id), 'offer');

    const HUGE_CLIENT_RADIUS = 5_000_000; // way past both tiers' max
    const { items } = await matchingService.findMatches(String(me._id), {
      mode: 'local',
      radius: HUGE_CLIENT_RADIUS,
    });

    const names = items.map((i) => i.displayName).sort();
    expect(names).toEqual(['Near']); // "Far" excluded even though the client asked for a huge radius
  });

  it('lets premium viewers reach further (their tier max), without changing the request', async () => {
    const skill = await Skill.create({ name: 'Pottery', nameNormalized: 'pottery', category: 'Craft' });

    const me = await makeUser('PremiumSeeker', LONDON, { tier: 'premium' });
    await tag(String(me._id), String(skill._id), 'want');

    // 30km — inside premium's cap (200km) but would be outside free's cap (25km).
    const far = await makeUser('FarButPremiumOk', pointNorthKm(LONDON, 30));
    await tag(String(far._id), String(skill._id), 'offer');

    const { items } = await matchingService.findMatches(String(me._id), { mode: 'local' });
    expect(items.map((i) => i.displayName)).toEqual(['FarButPremiumOk']);
  });

  it('returns nothing for local mode when the seeker has no location set', async () => {
    const skill = await Skill.create({ name: 'Baking', nameNormalized: 'baking', category: 'Food' });
    const me = await makeUser('NoLocation', null, { tier: 'free' });
    await tag(String(me._id), String(skill._id), 'want');

    const candidate = await makeUser('Candidate', LONDON);
    await tag(String(candidate._id), String(skill._id), 'offer');

    const { items } = await matchingService.findMatches(String(me._id), { mode: 'local' });
    expect(items).toEqual([]);
  });

  it('the free radius cap matches the configured tier limit', () => {
    expect(TIER_LIMITS.free.mapRadiusMeters).toBe(25_000);
    expect(TIER_LIMITS.premium.mapRadiusMeters).toBe(200_000);
  });
});
