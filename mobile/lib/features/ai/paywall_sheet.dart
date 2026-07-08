import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_typography.dart';
import '../../design_system/tokens.dart';
import 'sheet_scaffold.dart';

Future<void> showPaywallSheet(BuildContext context) {
  return showAppSheet(context, child: const _Paywall());
}

class _Paywall extends StatelessWidget {
  const _Paywall();

  static const _perks = <(IconData, String)>[
    (Icons.verified_rounded, 'Unlimited match results'),
    (Icons.place_rounded, 'Wider & unlimited radius'),
    (Icons.repeat_rounded, 'Up to 10 active swaps'),
    (Icons.chat_bubble_rounded, 'Multimedia chat — photos & audio'),
    (Icons.star_rounded, 'Up to 8 skill tags'),
    (Icons.monetization_on_rounded, '30 Basic credits per week'),
    (Icons.local_fire_department_rounded, 'Feed boost visibility'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 26,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: Insets.md),
        Text('Go Premium', style: text.headlineMedium),
        const SizedBox(height: 2),
        Text(
          'Swap more, learn more, connect deeper.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Insets.lg),
        ..._perks.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Icon(p.$1, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Text(
                    p.$2,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '£7.99',
                    style: AppTypography.tabular(
                      size: 24,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/ month',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Cancel anytime · billed monthly · no contracts',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Start Premium'),
          ),
        ),
        const SizedBox(height: Insets.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Not now',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}
