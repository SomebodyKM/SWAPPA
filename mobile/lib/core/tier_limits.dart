/// Client-side mirror of the backend `TIER_LIMITS` (api/src/config/limits.ts).
/// Keep in sync with the server — the server is authoritative and will reject
/// over-limit actions, but these let the UI warn/disable proactively.
class TierLimits {
  const TierLimits({
    required this.skillTagsPerKind,
    required this.activeSwaps,
    required this.matchResults,
    required this.basicCreditCap,
  });

  /// Max tags per kind (e.g. 3 teach + 3 learn on free).
  final int skillTagsPerKind;
  final int activeSwaps;
  final int matchResults;

  /// Basic credits refilled up to per cycle (monthly) — mirrors
  /// `TIER_LIMITS.basicCreditCap` in `api/src/config/limits.ts`.
  final int basicCreditCap;

  static const free = TierLimits(
    skillTagsPerKind: 3,
    activeSwaps: 2,
    matchResults: 2,
    basicCreditCap: 20,
  );
  static const premium = TierLimits(
    skillTagsPerKind: 50,
    activeSwaps: 50,
    matchResults: 100,
    basicCreditCap: 200,
  );

  static TierLimits of(String tier) => tier == 'premium' ? premium : free;
}
