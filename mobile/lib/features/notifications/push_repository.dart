import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/notification_permission_store.dart';
import '../../core/providers.dart';

/// Wraps FCM permission + token registration against the backend's existing
/// `POST /users/me/push-tokens`. Foreground notifications never reach here —
/// the backend only falls back to push when the user has no live socket
/// connection (see `notification.service.ts`'s online check) — this is
/// purely for a backgrounded/killed app.
class PushRepository {
  PushRepository(this._api);
  final ApiClient _api;

  Future<NotificationSettings> permissionStatus() =>
      FirebaseMessaging.instance.getNotificationSettings();

  Future<NotificationSettings> requestPermission() => FirebaseMessaging.instance
      .requestPermission(alert: true, badge: true, sound: true);

  /// Registers the current FCM token and keeps it fresh — call once
  /// permission is granted (right after the priming screen, and again on
  /// every app start so a rotated token doesn't go stale server-side).
  Future<void> registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _send(token);
    FirebaseMessaging.instance.onTokenRefresh.listen(_send);
  }

  Future<void> _send(String token) =>
      _api.postJson('/users/me/push-tokens', body: {'token': token});
}

final pushRepositoryProvider = Provider<PushRepository>(
  (ref) => PushRepository(ref.watch(apiClientProvider)),
);

final notificationPermissionStoreProvider =
    Provider<NotificationPermissionStore>(
      (ref) => NotificationPermissionStore(),
    );

/// Whether the priming screen still needs to be shown — `false` once the
/// user has either decided via the OS prompt (authorized/denied) or
/// explicitly tapped "Not now".
final notificationPrimingNeededProvider = FutureProvider<bool>((ref) async {
  final store = ref.watch(notificationPermissionStoreProvider);
  if (await store.wasSkipped) return false;
  final settings = await ref.watch(pushRepositoryProvider).permissionStatus();
  return settings.authorizationStatus == AuthorizationStatus.notDetermined;
});
