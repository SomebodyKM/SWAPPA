/**
 * Server-side tunables (Constitution: caps/costs/timers MUST live server-side, not in clients).
 * Tune with real data; changing these does not require a client release.
 */

export type Tier = 'free' | 'premium';

export interface TierLimits {
  skillTagsPerKind: number; // max tags per kind (3 teach + 3 want on free)
  activeSwaps: number; // max concurrent {requested, active} swaps
  matchResults: number; // max results shown in discovery
  mapRadiusMeters: number; // max local radius
  multimediaMessaging: boolean;
  basicCreditCap: number; // Basic credit cap per cycle
}

export const TIER_LIMITS: Record<Tier, TierLimits> = {
  free: {
    skillTagsPerKind: 3,
    activeSwaps: 2,
    matchResults: 2,
    mapRadiusMeters: 25_000,
    multimediaMessaging: false,
    basicCreditCap: 20,
  },
  premium: {
    skillTagsPerKind: 50,
    activeSwaps: 50,
    matchResults: 100,
    mapRadiusMeters: 200_000,
    multimediaMessaging: true,
    basicCreditCap: 200,
  },
};

export type AiAction = 'icebreaker' | 'insight' | 'rematch' | 'profile_opt';

export const AI_ACTION_COST: Record<AiAction, number> = {
  icebreaker: 1,
  insight: 2,
  profile_opt: 2,
  rematch: 3,
};

export const CREDITS = {
  welcomeGrant: 15, // one-time Basic credits at signup
  refillCycleMs: 30 * 24 * 60 * 60 * 1000, // monthly refill
  lowBalanceThreshold: 3,
};

export const BOOST_PACKS: Record<string, number> = {
  boost_small: 25,
  boost_medium: 60,
  boost_large: 150,
};

export const ANTI_SPAM = {
  noShowAbandonWindowHours: 24,
  messageEditWindowMinutes: 15,
  reviewEditWindowHours: 24,
};

// One-time verification codes. v1 verifies EMAIL only; phone verification is a
// future update (the `channel` field is kept generic so SMS slots in later).
export const OTP = {
  length: 6,
  ttlMs: 10 * 60 * 1000, // code valid for 10 minutes
  maxAttempts: 5, // wrong-code attempts before the code is invalidated
  resendCooldownMs: 60 * 1000, // min gap between sends
};

export function tierLimits(tier: Tier): TierLimits {
  return TIER_LIMITS[tier];
}
