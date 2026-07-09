import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../design_system/app_colors.dart';
import '../../../design_system/app_theme.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/avatar.dart';
import '../../../design_system/widgets/skill_tag.dart';
import '../../profile/public_profile_sheet.dart';
import '../../safety/safety_repository.dart';
import '../discovery_providers.dart';
import '../match.dart';

/// Discovery result card — avatar, name, rating, distance, teach/want tags,
/// mutual-match highlight, 3-dot menu, and quick actions (Message / Icebreaker).
/// Tapping anywhere else on the card opens the full profile popup.
class MatchCard extends ConsumerWidget {
  const MatchCard({
    super.key,
    required this.match,
    this.onMessage,
    this.onIcebreaker,
  });

  final MatchResult match;
  final VoidCallback? onMessage;
  final VoidCallback? onIcebreaker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () =>
          showPublicProfileSheet(context, ref, userId: match.candidateId),
      child: Container(
        padding: const EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: match.mutual
                ? AppColors.primary.withValues(alpha: 0.25)
                : scheme.outlineVariant,
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
                  photoUrl: match.photoUrl,
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
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            match.ratingAvg.toStringAsFixed(1),
                            style: AppTypography.tabular(
                              size: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (match.reviewCount != null)
                            Text(
                              ' (${match.reviewCount})',
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          _UserMenu(
                            candidateId: match.candidateId,
                            name: match.displayName,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.place_rounded,
                            size: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            match.distanceLabel,
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Column rather than side-by-side — keeps a long skill
                      // name from pushing the two tags into a cramped Wrap or
                      // widening the card; each tag truncates on its own line.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (match.teaches != null)
                            SkillTag.offer(match.teaches!),
                          if (match.teaches != null && match.wants != null)
                            const SizedBox(height: 6),
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
      ),
    );
  }
}

/// A locked preview for a match hidden behind the free-tier cap — shows only
/// what [MatchTeaser] carries (skill + distance), with a lock icon standing
/// in for the avatar/name/rating that stay hidden until Premium. Same
/// footprint as [MatchCard] so it reads as "one of the same cards, just
/// locked" rather than a different kind of thing.
class MatchTeaserCard extends StatelessWidget {
  const MatchTeaserCard({super.key, required this.teaser});
  final MatchTeaser teaser;

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
          color: teaser.mutual
              ? AppColors.primary.withValues(alpha: 0.25)
              : scheme.outlineVariant,
        ),
        boxShadow: softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (teaser.mutual) ...[
            const _MutualBadge(),
            const SizedBox(height: Insets.sm),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium member',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (teaser.distanceLabel != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.place_rounded,
                            size: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            teaser.distanceLabel!,
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (teaser.teachesName != null)
                          SkillTag.offer(teaser.teachesName!),
                        if (teaser.teachesName != null &&
                            teaser.wantsName != null)
                          const SizedBox(height: 6),
                        if (teaser.wantsName != null)
                          SkillTag.want(teaser.wantsName!),
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
          Text(
            'Mutual Match',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
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
          textStyle: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
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
        icon: Icon(
          Icons.auto_awesome_rounded,
          size: 13,
          color: AppColors.accent,
        ),
        label: const Text('Icebreaker'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: scheme.onSurfaceVariant,
          textStyle: Theme.of(context).textTheme.labelMedium,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
        ),
      ),
    );
  }
}

class _UserMenu extends ConsumerWidget {
  const _UserMenu({required this.candidateId, required this.name});
  final String candidateId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_vert_rounded,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        onSelected: (value) {
          if (value == 'report') _report(context, ref);
          if (value == 'block') _block(context, ref);
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text('Report $name'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'block',
            child: Row(
              children: [
                Icon(
                  Icons.block_rounded,
                  size: 15,
                  color: AppColors.destructive,
                ),
                const SizedBox(width: 10),
                Text(
                  'Block $name',
                  style: const TextStyle(color: AppColors.destructive),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.xl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: Text('Report $name'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'What happened?'),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, controller.text.trim()),
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !context.mounted) return;
    try {
      await ref
          .read(safetyRepositoryProvider)
          .report(targetUserId: candidateId, reason: reason);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$name has been reported')));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.xl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: Text('Block $name?'),
        content: const Text(
          'You won’t see each other in Discovery, and neither of you can message the other.',
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.destructive,
                  ),
                  child: const Text('Block'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(safetyRepositoryProvider).block(candidateId);
      ref.invalidate(matchesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$name has been blocked')));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
