import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows a real OS notification banner for foreground events — used only
/// when the user has granted notification permission (see
/// `_AppShellState._onNotification`), so a permitted user sees the exact
/// same system-tray style whether the app is foregrounded, backgrounded, or
/// killed. Users who haven't granted permission fall back to the in-app
/// popup instead (`design_system/widgets/notification_popup.dart`).
class LocalNotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationChannel(
    'swappa_default',
    'Swappa notifications',
    description: 'Swap requests, session reminders, and messages',
    importance: Importance.high,
  );

  // Lazy and idempotent rather than run eagerly in main() — an earlier
  // version awaited this before runApp() via a manually built
  // ProviderContainer/UncontrolledProviderScope, which crashed
  // ("setState() or markNeedsBuild() called during build") the moment a
  // provider refresh landed while an OverlayEntry (the in-app notification
  // popup) was mid-build. Plain ProviderScope plus lazy init sidesteps that
  // entirely.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  /// [color] tints the small status-bar icon (Android 5+) so a permitted
  /// user's system notification still carries the same per-type accent as
  /// the in-app popup a non-permitted user would see instead. Uses
  /// Android's "big text" style so the full body is readable when expanded,
  /// rather than a single truncated line.
  Future<void> show({
    required String title,
    required String body,
    Color? color,
  }) async {
    await _ensureInitialized();
    return _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: color,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// A chat-style notification (name, avatar, message bubble on expand) —
  /// the same "messaging style" Android's own Messages app and most chat
  /// apps use, rather than a plain title/body banner.
  Future<void> showMessage({
    required String senderName,
    String? senderPhotoUrl,
    required String body,
  }) async {
    await _ensureInitialized();
    final avatar = await _fetchAvatarBytes(senderPhotoUrl);
    final person = Person(
      name: senderName,
      icon: avatar != null ? ByteArrayAndroidIcon(avatar) : null,
    );
    return _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: senderName,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: MessagingStyleInformation(
            person,
            conversationTitle: senderName,
            messages: [Message(body, DateTime.now(), person)],
          ),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // Best-effort — a slow/failed avatar fetch shouldn't hold up or break the
  // notification, it just shows without one.
  Future<Uint8List?> _fetchAvatarBytes(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      ).get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      final data = response.data;
      return data != null ? Uint8List.fromList(data) : null;
    } catch (_) {
      return null;
    }
  }
}

final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => LocalNotificationService(),
);
