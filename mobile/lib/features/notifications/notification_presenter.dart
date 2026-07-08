import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/local_notifications.dart';
import '../../core/providers.dart';
import '../../design_system/widgets/notification_popup.dart';
import '../swaps/swap_repository.dart';
import 'notification_navigation.dart';
import 'notification_repository.dart';
import 'notification_style.dart';

/// Handles a foreground notification regardless of transport — the normal
/// path is the live Socket.IO `notification` event, but the backend falls
/// back to an FCM push whenever it thinks the recipient is offline
/// (`notification.service.ts`'s room check). If that check ever races with
/// a reconnect and fires while the app is actually still foregrounded, FCM
/// delivers it to [FirebaseMessaging.onMessage] instead of auto-showing
/// anything — Android/iOS never auto-display a "foreground" push. Routing
/// both transports through here means that case is covered too, and
/// invalidation + the OS-notification/in-app-popup split only lives once.
Future<void> handleForegroundNotification(
  BuildContext context,
  WidgetRef ref, {
  required String type,
  required String? title,
  required String? body,
  required Map<String, dynamic> data,
}) async {
  if (type.isEmpty) return;
  // Already looking at that exact thread — the message is already visible
  // live in the transcript, so a banner on top of it would be redundant.
  if (type == 'message_received' &&
      data['conversationId']?.toString() == activeConversationId) {
    return;
  }
  if (kSwapRelatedNotificationTypes.contains(type)) {
    ref.invalidate(mySwapsProvider);
    ref.invalidate(upcomingSessionsProvider);
  }
  ref.invalidate(notificationsProvider);

  final message = (body != null && body.isNotEmpty) ? body : title;
  if (message == null || message.isEmpty || !context.mounted) return;

  final settings = await FirebaseMessaging.instance.getNotificationSettings();
  final osAllowed =
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
  if (!context.mounted) return;

  if (osAllowed) {
    final localNotifications = ref.read(localNotificationServiceProvider);
    if (type == 'message_received') {
      localNotifications.showMessage(
        senderName: title ?? 'New message',
        senderPhotoUrl: data['senderPhotoUrl']?.toString(),
        body: message,
      );
    } else {
      localNotifications.show(
        title: title ?? 'SWAPPA',
        body: message,
        color: styleForType(type).accentColor,
      );
    }
    return;
  }

  showInAppNotificationPopup(
    context,
    title: title ?? 'SWAPPA',
    body: message,
    type: type,
    onTap: () => handleNotificationTap(context, ref, type: type, data: data),
  );
}
