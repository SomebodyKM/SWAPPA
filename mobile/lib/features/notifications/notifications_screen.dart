import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';

class _Notif {
  const _Notif(this.emoji, this.text, this.time, this.read);
  final String emoji;
  final String text;
  final String time;
  final bool read;
}

const _notifs = [
  _Notif('🔥', 'New mutual match with James Okafor — Web Dev ↔ Spanish', '5m', false),
  _Notif('💬', "Maya Chen: How about Saturday morning? I'm free from 9am", '2m', false),
  _Notif('📅', 'Priya Sharma accepted your session proposal for Wed 2 Jul', '1h', false),
  _Notif('✅', 'Swap with Luca Romano marked complete — 2 credits earned!', '3d', true),
  _Notif('💰', 'Your Basic credits have been refilled — 15 credits ready', '1w', true),
];

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.md),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_back_rounded, size: 18, color: scheme.onSurface),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Text('Notifications', style: text.titleLarge),
                  const Spacer(),
                  Text('Mark all read',
                      style: text.labelMedium?.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _notifs.length,
                itemBuilder: (context, i) => _NotifRow(notif: _notifs[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({required this.notif});
  final _Notif notif;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final unread = !notif.read;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 14),
      decoration: BoxDecoration(
        color: unread ? AppColors.primary.withValues(alpha: 0.04) : null,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Text(notif.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notif.text,
                    style: text.bodyMedium?.copyWith(
                      color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      height: 1.3,
                    )),
                const SizedBox(height: 2),
                Text('${notif.time} ago',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (unread) ...[
            const SizedBox(width: Insets.sm),
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}
