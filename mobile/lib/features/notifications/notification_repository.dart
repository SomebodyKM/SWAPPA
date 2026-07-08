import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';

/// Mirrors the backend `Notification` document (`GET/PATCH/DELETE /notifications`)
/// and the realtime `notification` socket event, which shares the same shape.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String type; // message_received | match | swap_status_changed | ...
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    data: data,
    read: read ?? this.read,
    createdAt: createdAt,
  );

  String get relativeTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] ?? json['_id']).toString(),
      type: (json['type'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      read: (json['read'] as bool?) ?? false,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class NotificationRepository {
  NotificationRepository(this._api);
  final ApiClient _api;

  Future<List<AppNotification>> list({String? cursor}) async {
    final data = await _api.getJson(
      '/notifications',
      query: cursor != null ? {'cursor': cursor} : null,
    );
    final items = (data is Map ? data['items'] : null) as List? ?? const [];
    return items
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) =>
      _api.patchJson('/notifications/$id', body: const {});
  Future<void> markAllRead() =>
      _api.postJson('/notifications/read-all', body: const {});
  Future<void> remove(String id) => _api.deleteJson('/notifications/$id');
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(apiClientProvider)),
);

/// The signed-in user's notification feed, keyed to the user id so switching
/// accounts re-fetches instead of serving the previous session's list.
///
/// Excludes `message_received` — new messages already have their own unread
/// badge on the Chat tab, so surfacing them here too would double-count.
final notificationsProvider = FutureProvider<List<AppNotification>>((
  ref,
) async {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) return const [];
  final items = await ref.watch(notificationRepositoryProvider).list();
  return items.where((n) => n.type != 'message_received').toList();
});

/// Unread count for the bell/nav badges — the single source both read from
/// so they can never disagree. Recomputes whenever [notificationsProvider]
/// refreshes (including after a realtime push).
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider).asData?.value ?? const [];
  return notifs.where((n) => !n.read).length;
});
