import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

/// A user the signed-in user has blocked (`GET /safety/blocks`, `target` populated).
class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.targetUserId,
    required this.name,
    this.photoUrl,
    required this.blockedAt,
  });

  final String id;
  final String targetUserId;
  final String name;
  final String? photoUrl;
  final DateTime? blockedAt;

  static Map<String, dynamic> _target(dynamic v) =>
      v is Map ? v.cast<String, dynamic>() : const {};

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    final target = _target(json['target']);
    return BlockedUser(
      id: (json['_id'] ?? json['id']).toString(),
      targetUserId: (target['_id'] ?? target['id'] ?? '').toString(),
      name: (target['displayName'] ?? 'Unknown') as String,
      photoUrl: target['photoUrl'] as String?,
      blockedAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

/// A report the signed-in user has filed against someone else
/// (`GET /safety/reports`, `target` populated) — their own report history.
class MyReport {
  const MyReport({
    required this.id,
    required this.targetName,
    this.targetPhotoUrl,
    this.reason,
    required this.status,
    this.resolutionNote,
    required this.createdAt,
  });

  final String id;
  final String targetName;
  final String? targetPhotoUrl;
  final String? reason;
  final String status; // open | reviewing | resolved | dismissed
  final String? resolutionNote;
  final DateTime? createdAt;

  static Map<String, dynamic> _target(dynamic v) =>
      v is Map ? v.cast<String, dynamic>() : const {};

  factory MyReport.fromJson(Map<String, dynamic> json) {
    final target = _target(json['target']);
    return MyReport(
      id: (json['_id'] ?? json['id']).toString(),
      targetName: (target['displayName'] ?? 'Unknown') as String,
      targetPhotoUrl: target['photoUrl'] as String?,
      reason: json['reason'] as String?,
      status: (json['status'] ?? 'open') as String,
      resolutionNote: json['resolutionNote'] as String?,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class SafetyRepository {
  SafetyRepository(this._api);
  final ApiClient _api;

  Future<void> report({required String targetUserId, required String reason}) =>
      _api.postJson(
        '/safety/reports',
        body: {'targetUserId': targetUserId, 'reason': reason},
      );

  /// Blocking excludes the target from Discovery in both directions
  /// (`safetyService.blockedUserIds` — already applied server-side).
  Future<void> block(String targetUserId) =>
      _api.postJson('/safety/blocks', body: {'targetUserId': targetUserId});

  Future<List<BlockedUser>> listBlocks() async {
    final data = await _api.getJson('/safety/blocks');
    return _items(data).map(BlockedUser.fromJson).toList();
  }

  Future<void> unblock(String targetUserId) =>
      _api.deleteJson('/safety/blocks/$targetUserId');

  Future<List<MyReport>> listMyReports() async {
    final data = await _api.getJson('/safety/reports');
    return _items(data).map(MyReport.fromJson).toList();
  }

  List<Map<String, dynamic>> _items(dynamic data) {
    final list = (data is Map ? data['items'] : data) as List? ?? const [];
    return list.cast<Map<String, dynamic>>();
  }
}

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepository(ref.watch(apiClientProvider)),
);

final blockedUsersProvider = FutureProvider<List<BlockedUser>>((ref) {
  return ref.watch(safetyRepositoryProvider).listBlocks();
});

final myReportsProvider = FutureProvider<List<MyReport>>((ref) {
  return ref.watch(safetyRepositoryProvider).listMyReports();
});
