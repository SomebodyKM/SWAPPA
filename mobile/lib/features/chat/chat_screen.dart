import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/avatar.dart';
import 'chat_thread.dart';
import 'conversation.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.md),
              child: Text('Chat', style: text.headlineSmall),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: sampleConversations.length,
                itemBuilder: (context, i) {
                  final c = sampleConversations[i];
                  return _ConvoRow(
                    convo: c,
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ChatThread(conversation: c)),
                    ),
                    onHold: () => _showActions(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context, Conversation c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConvoActionsSheet(convo: c),
    );
  }
}

class _ConvoRow extends StatelessWidget {
  const _ConvoRow({required this.convo, required this.onOpen, required this.onHold});
  final Conversation convo;
  final VoidCallback onOpen;
  final VoidCallback onHold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final unread = convo.unread > 0;
    return InkWell(
      onTap: onOpen,
      onLongPress: onHold,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(initials: convo.initials, color: avatarColorFor(convo.id), size: 44),
                if (unread)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                      child: Text('${convo.unread}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(convo.name,
                            style: text.titleSmall?.copyWith(
                                fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                      ),
                      Text('${convo.time} ago',
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    convo.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConvoActionsSheet extends StatelessWidget {
  const _ConvoActionsSheet({required this.convo});
  final Conversation convo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(top: Insets.md, bottom: Insets.sm),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: Insets.lg),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  Avatar(initials: convo.initials, color: avatarColorFor(convo.id), size: 44),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(convo.name,
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text(convo.last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _ActionTile(
              icon: Icons.visibility_off_rounded,
              title: 'Hide chat',
              subtitle: 'Remove from inbox without blocking',
              onTap: () => Navigator.pop(context),
            ),
            _ActionTile(
              icon: Icons.flag_outlined,
              title: 'Report',
              subtitle: 'Flag this conversation for review',
              onTap: () => Navigator.pop(context),
            ),
            _ActionTile(
              icon: Icons.person_off_rounded,
              title: 'Block',
              subtitle: 'Block and remove this person',
              danger: true,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = danger ? AppColors.destructive : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: danger
                    ? AppColors.destructive.withValues(alpha: 0.1)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
                  Text(subtitle,
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
