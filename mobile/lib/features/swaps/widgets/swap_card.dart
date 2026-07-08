import 'package:flutter/material.dart';

import '../../../design_system/app_theme.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/avatar.dart';
import '../../../design_system/widgets/status_badge.dart';
import '../swap_repository.dart';

class SwapCard extends StatelessWidget {
  const SwapCard({
    super.key,
    required this.swap,
    required this.myUserId,
    this.next,
    this.onOpen,
  });

  final SwapRecord swap;
  final String myUserId;
  final SwapSession? next;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: softShadow(context),
        ),
        child: Row(
          children: [
            Avatar(
              initials: swap.initials,
              color: avatarColorFor(swap.otherUserId),
              size: 40,
              photoUrl: swap.otherUserPhotoUrl,
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    swap.otherUserName,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${swap.myTeachSkill(myUserId).name} ↔ ${swap.myLearnSkill(myUserId).name}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${next!.whenLabel} · ${next!.formatLabel}',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            StatusBadge(status: swap.badgeStatus),
          ],
        ),
      ),
    );
  }
}
