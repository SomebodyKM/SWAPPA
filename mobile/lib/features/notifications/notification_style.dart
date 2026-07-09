import 'package:flutter/material.dart';

/// Maps a notification `type` string to the accent color/icon it renders
/// with, per the SWAPPA notification design spec's type system. `type`
/// strings come straight from the backend (see `notification.service.ts`
/// callers) and don't line up 1:1 with the spec's rows, so related backend
/// types are folded into the closest spec row — e.g. every non-terminal
/// swap-lifecycle event (`swap_requested`, `swap_status_changed`,
/// `swap_finish_requested`) shares the neutral violet "swap" look.
///
/// `session_completed` is deliberately NOT treated as the celebratory
/// moment — a swap can span multiple sessions, so one session finishing
/// doesn't mean the swap is done. Only `swap_completed` (the mutual
/// "confirm finished" flow at the swap level) gets the green/celebratory
/// treatment. `message_received` never reaches the notification *feed*
/// (the Chat tab's own unread badge covers that), but it does reach the
/// foreground banner/OS notification — see `notification_presenter.dart`.
class NotificationStyle {
  const NotificationStyle({
    required this.icon,
    required this.accentColor,
    required this.iconColor,
    this.isWarning = false,
    this.isCelebratory = false,
  });

  final IconData icon;

  /// Full-saturation accent — the banner's left bar and the ~14%-opacity
  /// icon-container tint.
  final Color accentColor;

  /// Icon draw color. Matches [accentColor] except for the yellow "match"
  /// row, where the spec calls for a dark-violet icon so it doesn't wash
  /// out against the pale-yellow tint.
  final Color iconColor;

  /// Warnings get a calm entry only — no bounce, no celebration.
  final bool isWarning;

  /// Positive, one-shot-worthy moments (match, swap completed) — allowed a
  /// small icon pop on entry.
  final bool isCelebratory;
}

const _violet = Color(0xFF7B5CFF);
const _darkViolet = Color(0xFF3B0764);
const _yellow = Color(0xFFFFD23F);
const _green = Color(0xFF34E08B);
const _amber = Color(0xFFF5A623);
const _grey = Color(0xFF9CA3AF);

NotificationStyle styleForType(String type) {
  switch (type) {
    case 'message_received':
      return const NotificationStyle(
        icon: Icons.chat_bubble_rounded,
        accentColor: _violet,
        iconColor: _violet,
      );
    case 'match':
    case 'mutual_match':
      return const NotificationStyle(
        icon: Icons.auto_awesome_rounded,
        accentColor: _yellow,
        iconColor: _darkViolet,
        isCelebratory: true,
      );
    case 'session_proposed':
    case 'session_responded':
      return const NotificationStyle(
        icon: Icons.calendar_month_rounded,
        accentColor: _violet,
        iconColor: _violet,
      );
    case 'swap_requested':
    case 'swap_status_changed':
    case 'swap_finish_requested':
      return const NotificationStyle(
        icon: Icons.handshake_rounded,
        accentColor: _violet,
        iconColor: _violet,
      );
    case 'swap_completed':
      return const NotificationStyle(
        icon: Icons.emoji_events_rounded,
        accentColor: _green,
        iconColor: _green,
        isCelebratory: true,
      );
    case 'session_completed':
    case 'session_finish_requested':
      return const NotificationStyle(
        icon: Icons.event_available_rounded,
        accentColor: _violet,
        iconColor: _violet,
      );
    case 'review_received':
      return const NotificationStyle(
        icon: Icons.star_rounded,
        accentColor: _green,
        iconColor: _green,
      );
    case 'credits_low':
    case 'credits_topped_up':
    case 'subscription_changed':
      return const NotificationStyle(
        icon: Icons.monetization_on_rounded,
        accentColor: _amber,
        iconColor: _amber,
      );
    case 'moderation_action':
    case 'no_show_reported':
    case 'report_submitted':
      return const NotificationStyle(
        icon: Icons.warning_rounded,
        accentColor: _grey,
        iconColor: _grey,
        isWarning: true,
      );
    case 'skill_submitted':
      return const NotificationStyle(
        icon: Icons.school_rounded,
        accentColor: _violet,
        iconColor: _violet,
      );
    case 'bug_submitted':
      return const NotificationStyle(
        icon: Icons.bug_report_rounded,
        accentColor: _violet,
        iconColor: _violet,
      );
    default:
      return const NotificationStyle(
        icon: Icons.notifications_rounded,
        accentColor: _grey,
        iconColor: _grey,
      );
  }
}
