import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/segmented_toggle.dart';
import '../../design_system/widgets/swappa_logo.dart';
import '../ai/ai_sheet.dart';
import '../ai/paywall_sheet.dart';
import '../chat/chat_thread.dart';
import 'discovery_providers.dart';
import 'match.dart';
import 'widgets/discovery_map_view.dart';
import 'widgets/match_card.dart';
import 'widgets/soft_paywall.dart';

void _noop() {}

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
            Expanded(child: isMap ? const _DiscoveryMap() : const _MatchList()),
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
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.sm,
        Insets.lg,
        Insets.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SwappaWordmark(),
              const Spacer(),
              _TryHarderChip(onTap: () => showAiSheet(context, 'deep-rematch')),
            ],
          ),
          const SizedBox(height: Insets.md),
          TextField(
            onChanged: (v) =>
                ref.read(discoverySearchProvider.notifier).state = v,
            decoration: const InputDecoration(
              hintText: 'Find a skill to learn…',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              // Map only ever plots local (located, radius-filtered) candidates,
              // so the mode filter locks to Local while in map view.
              if (isMap)
                const PillFilter(label: 'Local', active: true, onTap: _noop)
              else
                for (final f in const ['all', 'local', 'remote']) ...[
                  PillFilter(
                    label: f[0].toUpperCase() + f.substring(1),
                    active: mode == f,
                    onTap: () =>
                        ref.read(discoveryModeProvider.notifier).state = f,
                  ),
                  const SizedBox(width: 6),
                ],
              const Spacer(),
              SegmentedToggle<bool>(
                value: isMap,
                onChanged: (v) {
                  ref.read(discoveryIsMapProvider.notifier).state = v;
                  if (v) {
                    ref.read(discoveryModeProvider.notifier).state = 'local';
                  }
                },
                options: const [
                  SegmentOption(
                    value: false,
                    label: 'List',
                    icon: Icons.view_agenda_rounded,
                  ),
                  SegmentOption(
                    value: true,
                    label: 'Map',
                    icon: Icons.map_rounded,
                  ),
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
    final async = ref.watch(filteredMatchesProvider);
    return async.when(
      loading: () => const _MatchSkeletonList(),
      error: (e, _) => _ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(matchesProvider),
      ),
      data: (result) {
        if (result.items.isEmpty) return const _EmptyState();
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            4,
            Insets.lg,
            Insets.xxl,
          ),
          children: [
            for (final m in result.items) ...[
              MatchCard(
                match: m,
                onMessage: () => openChatWith(context, ref, m.candidateId),
                onIcebreaker: () async {
                  final text = await showAiSheet(
                    context,
                    'icebreaker',
                    matchUserId: m.candidateId,
                  );
                  if (text != null && context.mounted) {
                    await openChatWith(
                      context,
                      ref,
                      m.candidateId,
                      initialDraft: text,
                    );
                  }
                },
              ),
              const SizedBox(height: Insets.md),
            ],
            if (result.capped && result.hiddenCount > 0)
              _LockedPaywall(
                teasers: result.teasers,
                hiddenCount: result.hiddenCount,
                onExplore: () => showPaywallSheet(context),
              ),
          ],
        );
      },
    );
  }
}

/// The locked tail of the results: real (non-identifying) teaser cards for a
/// few of the hidden matches, followed by an "Explore Premium" card — so
/// free users see there's genuinely someone there, not just a wall.
class _LockedPaywall extends StatelessWidget {
  const _LockedPaywall({
    required this.teasers,
    required this.hiddenCount,
    required this.onExplore,
  });

  final List<MatchTeaser> teasers;
  final int hiddenCount;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final t in teasers) ...[
          MatchTeaserCard(teaser: t),
          const SizedBox(height: Insets.md),
        ],
        SoftPaywall(hiddenCount: hiddenCount, onExplore: onExplore),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),
    );
  }
}

class _DiscoveryMap extends StatelessWidget {
  const _DiscoveryMap();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 4, Insets.lg, Insets.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: const DiscoveryMapView(),
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
            Icon(
              Icons.search_off_rounded,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: Insets.md),
            Text(
              'No matches yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Add skills you want to learn to start finding swap partners.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
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
            Text(
              'Couldn’t load matches',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Insets.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
