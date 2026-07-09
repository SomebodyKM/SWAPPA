import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../discovery/match.dart';

/// Mirrors `AI_ACTION_COST` in `api/src/config/limits.ts` — kept in sync by
/// hand since there's no endpoint that exposes it, only one that enforces it.
class AiCosts {
  static const icebreaker = 1;
  static const insight = 2;
  static const profileOptimizer = 2;
  static const rematch = 3;
}

class SkillDemand {
  const SkillDemand({required this.skill, required this.wanters});
  final String skill;
  final int wanters;

  factory SkillDemand.fromJson(Map<String, dynamic> json) => SkillDemand(
    skill: (json['skill'] ?? '').toString(),
    wanters: (json['wanters'] ?? 0) as int,
  );
}

class InsightReport {
  const InsightReport({required this.summary, required this.demand});
  final String summary;
  final List<SkillDemand> demand;

  factory InsightReport.fromJson(Map<String, dynamic> json) => InsightReport(
    summary: (json['summary'] ?? '').toString(),
    demand: ((json['demand'] as List?) ?? const [])
        .map((e) => SkillDemand.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ProfileOptimizerResult {
  const ProfileOptimizerResult({
    required this.suggestedBio,
    required this.suggestedTags,
  });
  final String suggestedBio;
  final List<String> suggestedTags;

  factory ProfileOptimizerResult.fromJson(Map<String, dynamic> json) =>
      ProfileOptimizerResult(
        suggestedBio: (json['suggestedBio'] ?? '').toString(),
        suggestedTags: ((json['suggestedTags'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Credit-metered AI actions (`POST /ai/*`) — the backend only ever deducts
/// credits once a result is actually generated (never on failure), so a
/// thrown [ApiException] here always means nothing was charged.
class AiRepository {
  AiRepository(this._api);
  final ApiClient _api;

  Future<String> icebreaker(String matchUserId) async {
    final data =
        await _api.postJson(
              '/ai/icebreaker',
              body: {'matchUserId': matchUserId},
            )
            as Map;
    return (data['message'] ?? '').toString();
  }

  Future<InsightReport> insight() async {
    final data = await _api.postJson('/ai/insight') as Map;
    return InsightReport.fromJson(
      (data['report'] as Map).cast<String, dynamic>(),
    );
  }

  Future<List<MatchResult>> rematch({String? skillId, String? mode}) async {
    final data =
        await _api.postJson(
              '/ai/rematch',
              body: {'skillId': ?skillId, 'mode': ?mode},
            )
            as Map;
    final items = (data['matches'] as List?) ?? const [];
    return items
        .map((e) => MatchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProfileOptimizerResult> profileOptimizer() async {
    final data = await _api.postJson('/ai/profile-optimizer') as Map;
    return ProfileOptimizerResult.fromJson(data.cast<String, dynamic>());
  }
}

final aiRepositoryProvider = Provider<AiRepository>(
  (ref) => AiRepository(ref.watch(apiClientProvider)),
);
