import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers.dart';
import '../../core/tier_limits.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_typography.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/avatar.dart';
import '../../design_system/widgets/proficiency_bars.dart';
import '../../shared/models/skill.dart';
import '../ai/ai_repository.dart';
import '../ai/ai_sheet.dart';
import '../auth/auth_controller.dart';
import 'models/review.dart';
import 'profile_providers.dart';
import 'settings/settings_screen.dart';
import 'skill_manage_sheet.dart';
import 'skill_picker_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).user;

    // Refresh whenever this tab becomes the active one — AppShell keeps
    // every tab mounted (IndexedStack), so without this, switching back to
    // Profile would just show whatever was cached from the last visit.
    ref.listen<int>(appTabIndexProvider, (previous, next) {
      if (next == 4 && previous != 4) {
        ref.invalidate(myTagsProvider);
        ref.invalidate(myReviewsProvider);
        ref.read(authControllerProvider.notifier).refreshUser();
      }
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.sm,
                Insets.lg,
                Insets.sm,
              ),
              child: Row(
                children: [
                  Text('Profile', style: text.headlineSmall),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.settings_rounded,
                        size: 17,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(myTagsProvider);
                  ref.invalidate(myReviewsProvider);
                  await ref.read(authControllerProvider.notifier).refreshUser();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    4,
                    Insets.lg,
                    Insets.xxl,
                  ),
                  children: [
                    if (user != null)
                      _HeaderCard(
                        name: user.displayName,
                        photoUrl: user.photoUrl,
                        tier: user.tier,
                        ratingAvg: user.ratingAvg,
                        ratingCount: user.ratingCount,
                        bio: user.bio,
                      ),
                    const SizedBox(height: Insets.md),
                    const _SkillsCard(),
                    const SizedBox(height: Insets.md),
                    const _AiToolsCard(),
                    const SizedBox(height: Insets.md),
                    const _ReviewsCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.name,
    this.photoUrl,
    required this.tier,
    required this.ratingAvg,
    required this.ratingCount,
    this.bio,
  });
  final String name;
  final String? photoUrl;
  final String tier;
  final double ratingAvg;
  final int ratingCount;
  final String? bio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final initials = name.trim().isEmpty
        ? '?'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .map((w) => w[0])
              .take(2)
              .join()
              .toUpperCase();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(Radii.md),
                  image: photoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: photoUrl == null
                    ? Text(
                        initials,
                        style: GoogleFonts.fredoka(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: text.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        _tierPill(context, tier),
                      ],
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
                          ratingAvg.toStringAsFixed(1),
                          style: AppTypography.tabular(
                            size: 12,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          ratingCount == 1
                              ? ' · 1 review'
                              : ' · $ratingCount reviews',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bio != null && bio!.trim().isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            Text(
              bio!,
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tierPill(BuildContext context, String tier) {
    final scheme = Theme.of(context).colorScheme;
    final premium = tier == 'premium';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: premium
            ? AppColors.primary
            : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        premium ? 'Premium' : 'Free',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: premium ? Colors.white : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SkillsCard extends ConsumerWidget {
  const _SkillsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tagsAsync = ref.watch(myTagsProvider);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tagsAsync.when(
            // Keep showing current tags during background reloads (no flash).
            skipLoadingOnReload: true,
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'Couldn’t load your skills',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            data: (tags) {
              final teach = tags.where((t) => t.isOffer).toList();
              final learn = tags.where((t) => !t.isOffer).toList();
              final cap = TierLimits.of(
                ref.watch(authControllerProvider).user?.tier ?? 'free',
              ).skillTagsPerKind;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skillHeader(context, 'Can teach', teach.length, cap),
                  const SizedBox(height: Insets.sm),
                  _tagWrap(
                    context,
                    ref,
                    teach,
                    AppColors.offerBg,
                    AppColors.offerFg,
                    'None yet',
                  ),
                  const SizedBox(height: Insets.md),
                  _skillHeader(context, 'Want to learn', learn.length, cap),
                  const SizedBox(height: Insets.sm),
                  _tagWrap(
                    context,
                    ref,
                    learn,
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primary,
                    'None yet',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: Insets.md),
          GestureDetector(
            onTap: () => showSkillPickerSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: scheme.outlineVariant, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Add skill',
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillHeader(BuildContext context, String title, int count, int cap) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 6),
        Text(
          '($count / $cap)',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _tagWrap(
    BuildContext context,
    WidgetRef ref,
    List<SkillTag> tags,
    Color bg,
    Color fg,
    String empty,
  ) {
    if (tags.isEmpty) {
      return Text(
        empty,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in tags)
          GestureDetector(
            onTap: () => showSkillManageSheet(context, t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.skill.name,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (t.proficiency != null) ...[
                    const SizedBox(width: 6),
                    ProficiencyBars(proficiency: t.proficiency, color: fg),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Entry points for the two AI actions that aren't tied to a specific match
/// or chat — Insight (skill demand) and Profile Optimizer (bio rewrite).
class _AiToolsCard extends StatelessWidget {
  const _AiToolsCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Tools',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Insets.md),
          _AiToolRow(
            icon: Icons.trending_up_rounded,
            title: 'Insight Report',
            subtitle: 'See demand for your skills',
            cost: AiCosts.insight,
            onTap: () => showAiSheet(context, 'insight'),
          ),
          const SizedBox(height: Insets.md),
          _AiToolRow(
            icon: Icons.shield_rounded,
            title: 'Profile Optimizer',
            subtitle: 'AI-rewritten bio to attract more swaps',
            cost: AiCosts.profileOptimizer,
            onTap: () => showAiSheet(context, 'optimizer'),
          ),
        ],
      ),
    );
  }
}

class _AiToolRow extends StatelessWidget {
  const _AiToolRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cost,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final int cost;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.monetization_on_rounded,
                size: 11,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
              Text(
                '$cost',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewsCard extends ConsumerStatefulWidget {
  const _ReviewsCard();

  @override
  ConsumerState<_ReviewsCard> createState() => _ReviewsCardState();
}

class _ReviewsCardState extends ConsumerState<_ReviewsCard> {
  static const _pageSize = 5;
  int _visibleCount = _pageSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reviewsAsync = ref.watch(myReviewsProvider);
    final count = reviewsAsync.asData?.value.length;

    // Back to the first page on a pull-to-refresh re-fetch, or the moment
    // this tab isn't the visible one anymore — AppShell keeps every tab
    // mounted (IndexedStack), so without this "load more" state would
    // otherwise silently carry over next time you come back to Profile.
    ref.listen<AsyncValue<List<Review>>>(myReviewsProvider, (_, next) {
      if (next.isRefreshing) setState(() => _visibleCount = _pageSize);
    });
    ref.listen<int>(appTabIndexProvider, (previous, next) {
      if (previous == 4 && next != 4) {
        setState(() => _visibleCount = _pageSize);
      }
    });

    return _Card(
      child: Column(
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
                  'No reviews yet — complete a swap to earn your first!',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                );
              }
              final visible = reviews.take(_visibleCount).toList();
              return Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    _ReviewRow(review: visible[i]),
                    if (i < visible.length - 1)
                      const SizedBox(height: Insets.md),
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
      ),
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

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
