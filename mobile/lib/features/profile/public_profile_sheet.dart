import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/avatar.dart';
import '../../design_system/widgets/skill_tag.dart';
import '../chat/chat_thread.dart';
import '../safety/safety_repository.dart';
import 'models/public_profile.dart';
import 'models/review.dart';
import 'profile_providers.dart';

/// Opens a popup showing [userId]'s public profile — avatar, rating, bio,
/// skills taught/wanted, and reviews — with a Report/Block menu, mirroring
/// what's already on the Discovery card. [showMessageButton] is turned off
/// when opened from inside an existing chat thread, where offering to
/// message the person you're already messaging would be redundant.
Future<void> showPublicProfileSheet(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  bool showMessageButton = true,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PublicProfileSheet(
      userId: userId,
      showMessageButton: showMessageButton,
    ),
  );
}

class _PublicProfileSheet extends ConsumerWidget {
  const _PublicProfileSheet({
    required this.userId,
    required this.showMessageButton,
  });
  final String userId;
  final bool showMessageButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final profileAsync = ref.watch(publicProfileProvider(userId));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Couldn’t load this profile',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          data: (profile) => _ProfileBody(
            profile: profile,
            showMessageButton: showMessageButton,
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile, required this.showMessageButton});
  final PublicProfile profile;
  final bool showMessageButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tagsAsync = ref.watch(userTagsProvider(profile.id));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.md),
          child: Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              0,
              Insets.lg,
              Insets.lg,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Avatar(
                    initials: profile.initials,
                    color: avatarColorFor(profile.id),
                    size: 64,
                    photoUrl: profile.photoUrl,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: text.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              profile.ratingAvg.toStringAsFixed(1),
                              style: text.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              profile.ratingCount == 1
                                  ? ' · 1 review'
                                  : ' · ${profile.ratingCount} reviews',
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (profile.location.displayName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.place_rounded,
                                size: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  profile.location.displayName!,
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
                  _ProfileMenu(userId: profile.id, name: profile.displayName),
                ],
              ),
              if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: Insets.md),
                Text(
                  profile.bio!,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: Insets.lg),
              tagsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => const SizedBox.shrink(),
                data: (tags) {
                  final teach = tags.where((t) => t.isOffer).toList();
                  final learn = tags.where((t) => !t.isOffer).toList();
                  if (teach.isEmpty && learn.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (teach.isNotEmpty) ...[
                        Text(
                          'Teach:',
                          style: text.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in teach)
                              SkillTag.offer(t.skill.name, bare: true),
                          ],
                        ),
                      ],
                      if (teach.isNotEmpty && learn.isNotEmpty)
                        const SizedBox(height: Insets.md),
                      if (learn.isNotEmpty) ...[
                        Text(
                          'Learn:',
                          style: text.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in learn)
                              SkillTag.want(t.skill.name, bare: true),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: Insets.lg),
              _ReviewsSection(userId: profile.id),
            ],
          ),
        ),
        if (showMessageButton)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              0,
              Insets.lg,
              Insets.md,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  openChatWith(context, ref, profile.id);
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('Message'),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewsSection extends ConsumerStatefulWidget {
  const _ReviewsSection({required this.userId});
  final String userId;

  @override
  ConsumerState<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends ConsumerState<_ReviewsSection> {
  static const _pageSize = 5;
  int _visibleCount = _pageSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reviewsAsync = ref.watch(userReviewsProvider(widget.userId));
    final count = reviewsAsync.asData?.value.length;

    // Reopening this popup always starts fresh (it's a new widget instance
    // each time), but a refetch of an already-open one — e.g. after leaving
    // a review elsewhere — should still reset back to the first page.
    ref.listen<AsyncValue<List<Review>>>(userReviewsProvider(widget.userId), (
      _,
      next,
    ) {
      if (next.isRefreshing) setState(() => _visibleCount = _pageSize);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Reviews',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '($count)',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Insets.md),
        reviewsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(Insets.md),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text(
            'Couldn’t load reviews',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          data: (reviews) {
            if (reviews.isEmpty) {
              return Text(
                'No reviews yet',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              );
            }
            final visible = reviews.take(_visibleCount).toList();
            return Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  _ReviewRow(review: visible[i]),
                  if (i < visible.length - 1) const SizedBox(height: Insets.md),
                ],
                if (_visibleCount < reviews.length) ...[
                  const SizedBox(height: Insets.md),
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _visibleCount += _pageSize),
                      child: const Text('Load more'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final initials = review.reviewerName.trim().isEmpty
        ? '?'
        : review.reviewerName
              .trim()
              .split(RegExp(r'\s+'))
              .map((w) => w[0])
              .take(2)
              .join()
              .toUpperCase();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Avatar(
          initials: initials,
          color: avatarColorFor(review.reviewerName),
          size: 36,
          photoUrl: review.reviewerPhoto,
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    review.reviewerName,
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    children: List.generate(
                      review.rating.clamp(0, 5),
                      (_) => const Icon(
                        Icons.star_rounded,
                        size: 11,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  review.comment!,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu({required this.userId, required this.name});
  final String userId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_vert_rounded,
          size: 18,
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
          .report(targetUserId: userId, reason: reason);
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
      await ref.read(safetyRepositoryProvider).block(userId);
      if (context.mounted) {
        Navigator.pop(
          context,
        ); // close the profile sheet — nothing left to do here
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
