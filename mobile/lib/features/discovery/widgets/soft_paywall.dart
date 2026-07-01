import 'package:flutter/material.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/tokens.dart';

/// Soft paywall shown over the blurred locked matches — an "Explore Premium"
/// card (Discovery, DESIGN_INTENT §8 / export `ListView` soft paywall).
class SoftPaywall extends StatelessWidget {
  const SoftPaywall({super.key, required this.hiddenCount, this.onExplore});

  final int hiddenCount;
  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(height: Insets.md),
          Text('$hiddenCount more matches waiting',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            'Premium reveals the full ranked list and unlocks wider radius matching.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.lg),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: onExplore,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
              ),
              child: const Text('Explore Premium'),
            ),
          ),
        ],
      ),
    );
  }
}
