import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../admin/admin_bug_reports_screen.dart';
import '../admin/admin_reports_screen.dart';
import '../admin/admin_skills_screen.dart';
import '../chat/chat_thread.dart';
import '../swaps/swap_detail.dart';
import '../swaps/swap_repository.dart';

/// Shared "where does tapping this notification go" logic — used for both
/// an in-app notification-list tap and a push notification tap (cold start
/// or backgrounded-to-foreground), since both carry the same `type`/`data`
/// shape (the backend sends push with the identical `data` map).
Future<void> handleNotificationTap(
  BuildContext context,
  WidgetRef ref, {
  required String type,
  required Map<String, dynamic> data,
}) async {
  if (type == 'message_received') {
    final senderId = data['senderId']?.toString();
    if (senderId != null && context.mounted) {
      await openChatWith(context, ref, senderId);
    }
    return;
  }
  // Admin-only — a report was just submitted, take them straight to the
  // reports queue rather than anywhere in the consumer-facing app.
  if (type == 'report_submitted') {
    if (context.mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AdminReportsScreen()));
    }
    return;
  }
  // Admin-only — a user proposed a new skill, take them straight to the
  // pending-approval queue.
  if (type == 'skill_submitted') {
    if (context.mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AdminSkillsScreen()));
    }
    return;
  }
  // Admin-only — a user filed a bug report, take them straight to the queue.
  if (type == 'bug_submitted') {
    if (context.mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AdminBugReportsScreen()));
    }
    return;
  }
  if (!kSwapRelatedNotificationTypes.contains(type)) return;

  // A declined session has nothing left to act on there — send the user to
  // wherever that swap now sits in the Swaps tab instead of its detail screen.
  if (type == 'session_responded' && data['decision'] == 'decline') {
    final swapStatus = data['swapStatus']?.toString();
    ref.read(swapsTabProvider.notifier).state = swapTabBucketFor(swapStatus);
    ref.read(appTabIndexProvider.notifier).state = 1; // Swaps tab
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    return;
  }

  final swapId = data['swapId']?.toString();
  if (swapId != null && context.mounted) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SwapDetail(swapId: swapId)));
  }
}
