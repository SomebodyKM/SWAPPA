import 'package:flutter/material.dart';

import '../../../design_system/app_theme.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/avatar.dart';
import '../../../design_system/widgets/status_badge.dart';
import '../swap.dart';

class SwapCard extends StatelessWidget {
  const SwapCard({super.key, required this.swap, this.onOpen});

  final Swap swap;
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
            Avatar(initials: swap.initials, color: avatarColorFor(swap.id), size: 40),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(swap.partner,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text('${swap.mine} ↔ ${swap.theirs}',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  if (swap.next != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 12, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text('${swap.next} · ${swap.format}',
                              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            StatusBadge(status: swap.status),
          ],
        ),
      ),
    );
  }
}
