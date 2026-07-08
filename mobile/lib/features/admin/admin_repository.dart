import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider is a legacy (but supported) provider in Riverpod 3.
import 'package:flutter_riverpod/legacy.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

class AdminMetrics {
  const AdminMetrics({
    required this.users,
    required this.activeSwaps,
    required this.completedSwaps,
    required this.premium,
    required this.aiSpends,
    required this.boostPurchases,
  });

  final int users;
  final int activeSwaps;
  final int completedSwaps;
  final int premium;
  final int aiSpends;
  final int boostPurchases;

  factory AdminMetrics.fromJson(Map<String, dynamic> json) => AdminMetrics(
    users: (json['users'] ?? 0) as int,
    activeSwaps: (json['activeSwaps'] ?? 0) as int,
    completedSwaps: (json['completedSwaps'] ?? 0) as int,
    premium: (json['premium'] ?? 0) as int,
    aiSpends: (json['aiSpends'] ?? 0) as int,
    boostPurchases: (json['boostPurchases'] ?? 0) as int,
  );
}

/// A skill catalog entry as seen by admins — unlike the consumer-facing
/// [Skill] model, this carries moderation fields (`status`, `aliases`).
class AdminSkill {
  const AdminSkill({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.aliases,
  });

  final String id;
  final String name;
  final String category;
  final String status; // approved | pending
  final List<String> aliases;

  factory AdminSkill.fromJson(Map<String, dynamic> json) => AdminSkill(
    id: (json['_id'] ?? json['id']).toString(),
    name: (json['name'] ?? '') as String,
    category: (json['category'] ?? '') as String,
    status: (json['status'] ?? 'pending') as String,
    aliases: ((json['aliases'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.status,
    required this.role,
    required this.ratingAvg,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final String? email;
  final String status; // active | suspended | banned
  final String role; // user | admin
  final double ratingAvg;
  final DateTime? createdAt;

  bool get isAdmin => role == 'admin';

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: (json['_id'] ?? json['id']).toString(),
    displayName: (json['displayName'] ?? 'Unknown') as String,
    email: json['email'] as String?,
    status: (json['status'] ?? 'active') as String,
    role: (json['role'] ?? 'user') as String,
    ratingAvg: ((json['ratingAvg'] ?? 0) as num).toDouble(),
    createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
  );
}

/// A user-vs-user report (`kind: 'report'` on the backend's shared
/// Report/Block model) — reporter/target come back populated with just
/// displayName/email.
class AdminReport {
  const AdminReport({
    required this.id,
    required this.reporterName,
    required this.targetName,
    this.reason,
    required this.status,
    this.resolutionNote,
    required this.createdAt,
  });

  final String id;
  final String reporterName;
  final String targetName;
  final String? reason;
  final String status; // open | reviewing | resolved | dismissed
  final String? resolutionNote;
  final DateTime? createdAt;

  static String _name(dynamic v) =>
      v is Map ? (v['displayName'] ?? 'Unknown').toString() : 'Unknown';

  factory AdminReport.fromJson(Map<String, dynamic> json) => AdminReport(
    id: (json['_id'] ?? json['id']).toString(),
    reporterName: _name(json['reporter']),
    targetName: _name(json['target']),
    reason: json['reason'] as String?,
    status: (json['status'] ?? 'open') as String,
    resolutionNote: json['resolutionNote'] as String?,
    createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
  );
}

/// A bug report filed by a user (`BugReport` model — separate from
/// `Report`, since a bug has no target user to point at).
class AdminBugReport {
  const AdminBugReport({
    required this.id,
    required this.reporterName,
    required this.description,
    required this.status,
    this.resolutionNote,
    required this.createdAt,
  });

  final String id;
  final String reporterName;
  final String description;
  final String status; // open | resolved | dismissed
  final String? resolutionNote;
  final DateTime? createdAt;

  static String _name(dynamic v) =>
      v is Map ? (v['displayName'] ?? 'Unknown').toString() : 'Unknown';

  factory AdminBugReport.fromJson(Map<String, dynamic> json) => AdminBugReport(
    id: (json['_id'] ?? json['id']).toString(),
    reporterName: _name(json['reporter']),
    description: (json['description'] ?? '') as String,
    status: (json['status'] ?? 'open') as String,
    resolutionNote: json['resolutionNote'] as String?,
    createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
  );
}

class AdminAuditEntry {
  const AdminAuditEntry({
    required this.id,
    required this.adminName,
    required this.action,
    required this.targetType,
    required this.detail,
    required this.createdAt,
  });

  final String id;
  final String adminName;
  final String action;
  final String targetType;
  final Map<String, dynamic> detail;
  final DateTime? createdAt;

  factory AdminAuditEntry.fromJson(Map<String, dynamic> json) {
    final admin = json['admin'];
    return AdminAuditEntry(
      id: (json['_id'] ?? json['id']).toString(),
      adminName: admin is Map
          ? (admin['displayName'] ?? 'Admin').toString()
          : 'Admin',
      action: (json['action'] ?? '').toString(),
      targetType: (json['targetType'] ?? '').toString(),
      detail: (json['detail'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

/// All `/admin/*` calls — every one of these 403s server-side unless the
/// signed-in user's JWT carries `role: 'admin'` (`adminGuard`).
class AdminRepository {
  AdminRepository(this._api);
  final ApiClient _api;

  Future<AdminMetrics> metrics() async {
    final data = await _api.getJson('/admin/metrics') as Map<String, dynamic>;
    return AdminMetrics.fromJson(data);
  }

  Future<List<AdminSkill>> pendingSkills() async {
    final data = await _api.getJson('/admin/skills/pending');
    return _items(data).map(AdminSkill.fromJson).toList();
  }

  /// The full approved catalog — reuses the same public endpoint every user
  /// picks skills from (`status: 'approved'` is baked into the query
  /// server-side), just with the admin-only fields already on [AdminSkill].
  Future<List<AdminSkill>> allSkills() async {
    final data = await _api.getJson('/skills', query: {'all': 'true'});
    return _items(data).map(AdminSkill.fromJson).toList();
  }

  Future<void> createSkill({required String name, required String category}) =>
      _api.postJson(
        '/admin/skills',
        body: {'name': name, 'category': category},
      );

  Future<void> approveSkill(String id) =>
      _api.patchJson('/admin/skills/$id', body: {'status': 'approved'});

  Future<void> editSkill(String id, {String? name, String? category}) =>
      _api.patchJson(
        '/admin/skills/$id',
        body: {'name': ?name, 'category': ?category},
      );

  Future<void> deleteSkill(String id) => _api.deleteJson('/admin/skills/$id');

  Future<List<AdminUser>> listUsers({String? query}) async {
    final data = await _api.getJson(
      '/admin/users',
      query: query != null && query.isNotEmpty ? {'query': query} : null,
    );
    return _items(data).map(AdminUser.fromJson).toList();
  }

  Future<void> banUser(String id, String reason) =>
      _api.postJson('/admin/users/$id/ban', body: {'reason': reason});

  Future<void> suspendUser(String id, String reason) =>
      _api.postJson('/admin/users/$id/suspend', body: {'reason': reason});

  Future<void> unbanUser(String id) => _api.postJson('/admin/users/$id/unban');

  Future<void> setRole(String id, String role) =>
      _api.patchJson('/admin/users/$id/role', body: {'role': role});

  Future<List<AdminReport>> listReports({String? status}) async {
    final data = await _api.getJson(
      '/admin/reports',
      query: status != null && status.isNotEmpty ? {'status': status} : null,
    );
    return _items(data).map(AdminReport.fromJson).toList();
  }

  Future<void> resolveReport(String id, String note) =>
      _api.postJson('/admin/reports/$id/resolve', body: {'note': note});

  Future<void> dismissReport(String id, String note) =>
      _api.postJson('/admin/reports/$id/dismiss', body: {'note': note});

  Future<List<AdminBugReport>> listBugReports({String? status}) async {
    final data = await _api.getJson(
      '/admin/bug-reports',
      query: status != null && status.isNotEmpty ? {'status': status} : null,
    );
    return _items(data).map(AdminBugReport.fromJson).toList();
  }

  Future<void> resolveBugReport(String id, String note) =>
      _api.postJson('/admin/bug-reports/$id/resolve', body: {'note': note});

  Future<void> dismissBugReport(String id, String note) =>
      _api.postJson('/admin/bug-reports/$id/dismiss', body: {'note': note});

  Future<List<AdminAuditEntry>> auditLog() async {
    final data = await _api.getJson('/admin/audit-log');
    return _items(data).map(AdminAuditEntry.fromJson).toList();
  }

  List<Map<String, dynamic>> _items(dynamic data) {
    final list = (data is Map ? data['items'] : data) as List? ?? const [];
    return list.cast<Map<String, dynamic>>();
  }
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);

final adminMetricsProvider = FutureProvider<AdminMetrics>((ref) {
  return ref.watch(adminRepositoryProvider).metrics();
});

final adminPendingSkillsProvider = FutureProvider<List<AdminSkill>>((ref) {
  return ref.watch(adminRepositoryProvider).pendingSkills();
});

final adminAllSkillsProvider = FutureProvider<List<AdminSkill>>((ref) {
  return ref.watch(adminRepositoryProvider).allSkills();
});

/// Which of the two Skill Moderation sections is showing — 'pending' or 'all'.
final adminSkillSectionProvider = StateProvider<String>((ref) => 'pending');

final adminUserSearchProvider = StateProvider<String>((ref) => '');

final adminUsersProvider = FutureProvider<List<AdminUser>>((ref) {
  final query = ref.watch(adminUserSearchProvider);
  return ref.watch(adminRepositoryProvider).listUsers(query: query);
});

/// '' means "all statuses".
final adminReportFilterProvider = StateProvider<String>((ref) => '');

final adminReportsProvider = FutureProvider<List<AdminReport>>((ref) {
  final status = ref.watch(adminReportFilterProvider);
  return ref.watch(adminRepositoryProvider).listReports(status: status);
});

final adminAuditLogProvider = FutureProvider<List<AdminAuditEntry>>((ref) {
  return ref.watch(adminRepositoryProvider).auditLog();
});

/// '' means "all statuses".
final adminBugReportFilterProvider = StateProvider<String>((ref) => '');

final adminBugReportsProvider = FutureProvider<List<AdminBugReport>>((ref) {
  final status = ref.watch(adminBugReportFilterProvider);
  return ref.watch(adminRepositoryProvider).listBugReports(status: status);
});
