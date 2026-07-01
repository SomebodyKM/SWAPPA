import 'package:flutter/material.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/app_theme.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/avatar.dart';
import '../../../design_system/widgets/skill_tag.dart';
import '../match.dart';

/// Discovery result card — avatar, name, rating, distance, teach/want tags,
/// mutual-match highlight, 3-dot menu, and quick actions (Message / Icebreaker).
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, this.onMessage, this.onIcebreaker});

  final MatchResult match;
  final VoidCallback? onMessage;
  final VoidCallback? onIcebreaker;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: match.mutual ? AppColors.primary.withValues(alpha: 0.25) : scheme.outlineVariant,
        ),
        boxShadow: softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (match.mutual) ...[
            const _MutualBadge(),
            const SizedBox(height: Insets.sm),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar(
                initials: match.initials,
                color: avatarColorFor(match.candidateId),
                size: 48,
                ringColor: match.mutual ? AppColors.primary : null,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            match.displayName,
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.star_rounded, size: 12, color: AppColors.accent),
                        const SizedBox(width: 2),
                        Text(
                          match.ratingAvg.toStringAsFixed(1),
                          style: AppTypography.tabular(size: 12, color: scheme.onSurfaceVariant),
                        ),
                        if (match.reviewCount != null)
                          Text(
                            ' (${match.reviewCount})',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        _UserMenu(name: match.displayName),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.place_rounded, size: 12, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text(match.distanceLabel,
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (match.teaches != null) SkillTag.offer(match.teaches!),
                        if (match.wants != null) SkillTag.want(match.wants!),
                      ],
                    ),
                    const SizedBox(height: Insets.md),
                    Row(
                      children: [
                        Expanded(child: _MessageButton(onTap: onMessage)),
                        const SizedBox(width: Insets.sm),
                        _IcebreakerButton(onTap: onIcebreaker),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MutualBadge extends StatelessWidget {
  const _MutualBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat_rounded, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text('Mutual Match',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  )),
        ],
      ),
    );
  }
}

class _MessageButton extends StatelessWidget {
  const _MessageButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(34),
          padding: EdgeInsets.zero,
          textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        ),
        child: const Text('Message'),
      ),
    );
  }
}

class _IcebreakerButton extends StatelessWidget {
  const _IcebreakerButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.accent),
        label: const Text('Icebreaker'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: scheme.onSurfaceVariant,
          textStyle: Theme.of(context).textTheme.labelMedium,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        ),
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_vert_rounded, size: 16, color: scheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        onSelected: (_) {},
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'report',
            child: Row(children: [
              Icon(Icons.flag_outlined, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text('Report $name'),
            ]),
          ),
          PopupMenuItem(
            value: 'block',
            child: Row(children: [
              Icon(Icons.block_rounded, size: 15, color: AppColors.destructive),
              const SizedBox(width: 10),
              Text('Block $name', style: const TextStyle(color: AppColors.destructive)),
            ]),
          ),
        ],
      ),
    );
  }
}
