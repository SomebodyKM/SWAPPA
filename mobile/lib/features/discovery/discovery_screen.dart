import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/segmented_toggle.dart';
import '../../design_system/widgets/swappa_logo.dart';
import '../ai/ai_sheet.dart';
import '../ai/paywall_sheet.dart';
import '../notifications/notifications_screen.dart';
import 'discovery_providers.dart';
import 'match.dart';
import 'widgets/match_card.dart';
import 'widgets/soft_paywall.dart';

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMap = ref.watch(discoveryIsMapProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _DiscoveryAppBar(),
            Expanded(
              child: isMap ? const _MapPlaceholder() : const _MatchList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryAppBar extends ConsumerWidget {
  const _DiscoveryAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(discoveryModeProvider);
    final isMap = ref.watch(discoveryIsMapProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.md),
      child: Column(
        children: [
          Row(
            children: [
              const SwappaWordmark(),
              const Spacer(),
              _TryHarderChip(onTap: () => showAiSheet(context, 'deep-rematch')),
              const SizedBox(width: Insets.sm),
              _NotifButton(
                count: 3,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          TextField(
            onChanged: (v) => ref.read(discoverySearchProvider.notifier).state = v,
            decoration: const InputDecoration(
              hintText: 'Find a skill to learn…',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              for (final f in const ['all', 'local', 'remote']) ...[
                PillFilter(
                  label: f[0].toUpperCase() + f.substring(1),
                  active: mode == f,
                  onTap: () => ref.read(discoveryModeProvider.notifier).state = f,
                ),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              SegmentedToggle<bool>(
                value: isMap,
                onChanged: (v) => ref.read(discoveryIsMapProvider.notifier).state = v,
                options: const [
                  SegmentOption(value: false, label: 'List', icon: Icons.view_agenda_rounded),
                  SegmentOption(value: true, label: 'Map', icon: Icons.map_rounded),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchList extends ConsumerWidget {
  const _MatchList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchesProvider);
    return async.when(
      loading: () => const _MatchSkeletonList(),
      error: (e, _) => _ErrorState(message: '$e', onRetry: () => ref.invalidate(matchesProvider)),
      data: (result) {
        if (result.items.isEmpty) return const _EmptyState();
        final visible = result.capped ? result.items.take(2).toList() : result.items;
        final hidden = result.capped ? result.items.skip(2).toList() : const <MatchResult>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(Insets.lg, 4, Insets.lg, Insets.xxl),
          children: [
            for (final m in visible) ...[
              MatchCard(
                match: m,
                onMessage: () {},
                onIcebreaker: () => showAiSheet(context, 'icebreaker'),
              ),
              const SizedBox(height: Insets.md),
            ],
            if (hidden.isNotEmpty)
              _LockedPaywall(hidden: hidden, onExplore: () => showPaywallSheet(context)),
          ],
        );
      },
    );
  }
}

/// The locked tail of the results: the remaining match cards rendered blurred
/// and non-interactive, with the "Explore Premium" card floating centered on
/// top — so it reads as "there's more back there" (Discovery soft paywall).
class _LockedPaywall extends StatelessWidget {
  const _LockedPaywall({required this.hidden, required this.onExplore});

  final List<MatchResult> hidden;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    // Always render ~3 cards behind (cycling if fewer are hidden) so the
    // blurred backdrop is taller than the floating sheet — consistent across
    // the all / local / remote tabs regardless of how many are hidden.
    final behind = <MatchResult>[
      for (var i = 0; i < 3 && hidden.isNotEmpty; i++) hidden[i % hidden.length],
    ];
    return Stack(
      children: [
        // Blurred, faded, un-tappable cards.
        IgnorePointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Opacity(
              opacity: 0.25,
              child: Column(
                children: [
                  for (final m in behind) ...[
                    MatchCard(match: m),
                    const SizedBox(height: Insets.md),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Floating paywall, vertically + horizontally centered over the cards.
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
              child: SoftPaywall(hiddenCount: hidden.length, onExplore: onExplore),
            ),
          ),
        ),
      ],
    );
  }
}

class _TryHarderChip extends StatelessWidget {
  const _TryHarderChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.accent),
      label: const Text('Try harder'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: scheme.onSurfaceVariant,
        textStyle: Theme.of(context).textTheme.labelMedium,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
      ),
    );
  }
}

class _NotifButton extends StatelessWidget {
  const _NotifButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(Icons.notifications_none_rounded, size: 18, color: scheme.onSurface),
          ),
          if (count > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: Text('$count',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 4, Insets.lg, Insets.lg),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: scheme.outlineVariant),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDDD9F5), Color(0xFFB8B4DC)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_rounded, size: 40, color: AppColors.primary),
              const SizedBox(height: Insets.sm),
              Text('Map view', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('General area · Precise location is Premium',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchSkeletonList extends StatelessWidget {
  const _MatchSkeletonList();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 4, Insets.lg, Insets.xxl),
      children: List.generate(4, (_) {
        return Container(
          margin: const EdgeInsets.only(bottom: Insets.md),
          height: 132,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
        );
      }),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: Insets.md),
            Text('No matches yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Add skills you want to learn to start finding swap partners.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40),
            const SizedBox(height: Insets.md),
            Text('Couldn’t load matches', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Insets.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
