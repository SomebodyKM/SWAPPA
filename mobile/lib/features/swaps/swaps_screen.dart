import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../auth/auth_controller.dart';
import '../notifications/notification_repository.dart';
import '../notifications/notifications_screen.dart';
import 'swap_detail.dart';
import 'swap_repository.dart';
import 'widgets/swap_card.dart';

/// Concurrent-swap cap by tier — mirrors `tierLimits().activeSwaps` in
/// `api/src/config/limits.ts` (free: 2, premium: 50). There's no dedicated
/// "my limits" endpoint, so this is kept in sync by hand.
int _activeSwapCapFor(String tier) => tier == 'premium' ? 50 : 2;

/// History loads 10 at a time via "Load more" rather than dumping the
/// whole past-swaps list on screen at once.
const _kHistoryPageSize = 10;

class SwapsScreen extends ConsumerStatefulWidget {
  const SwapsScreen({super.key});

  @override
  ConsumerState<SwapsScreen> createState() => _SwapsScreenState();
}

class _SwapsScreenState extends ConsumerState<SwapsScreen> {
  int _historyVisibleCount = _kHistoryPageSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tab = ref.watch(swapsTabProvider);
    final myUserId =
        ref.watch(authControllerProvider.select((s) => s.user?.id)) ?? '';
    final tier =
        ref.watch(authControllerProvider.select((s) => s.user?.tier)) ?? 'free';
    final swapsAsync = ref.watch(mySwapsProvider);
    final sessionsAsync = ref.watch(upcomingSessionsProvider);
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: swapsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              _ErrorState(onRetry: () => ref.invalidate(mySwapsProvider)),
          data: (swaps) {
            final pending = swaps
                .where((s) => s.tabBucket == 'pending')
                .toList();
            final active = swaps.where((s) => s.tabBucket == 'active').toList();
            final history = swaps
                .where((s) => s.tabBucket == 'history')
                .toList();
            final historyVisible = history.take(_historyVisibleCount).toList();
            final hasMoreHistory = history.length > historyVisible.length;
            final visible = switch (tab) {
              'pending' => pending,
              'history' => historyVisible,
              _ => active,
            };
            // Both `requested` and `active` swaps occupy a slot against the tier cap.
            final occupied = pending.length + active.length;
            final cap = _activeSwapCapFor(tier);
            final nextBySwap = <String, SwapSession>{};
            for (final s in sessionsAsync.asData?.value ?? const []) {
              nextBySwap.putIfAbsent(s.swapId, () => s);
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(mySwapsProvider);
                ref.invalidate(upcomingSessionsProvider);
              },
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      Insets.sm,
                      Insets.lg,
                      Insets.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Your Swaps', style: text.headlineSmall),
                            const Spacer(),
                            _NotifButton(
                              count: unreadNotifications,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.sm),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(Radii.pill),
                                child: LinearProgressIndicator(
                                  value: (occupied / cap).clamp(0, 1),
                                  minHeight: 6,
                                  backgroundColor:
                                      scheme.surfaceContainerHighest,
                                  valueColor: const AlwaysStoppedAnimation(
                                    AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: Insets.sm),
                            Text(
                              '$occupied / $cap active',
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.md),
                        _SwapTabStrip(
                          current: tab,
                          counts: {
                            'active': active.length,
                            'pending': pending.length,
                            'history': history.length,
                          },
                          onChanged: (t) =>
                              ref.read(swapsTabProvider.notifier).state = t,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: visible.isEmpty
                        ? ListView(children: [_EmptySwaps(tab: tab)])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              Insets.lg,
                              4,
                              Insets.lg,
                              Insets.xxl,
                            ),
                            itemCount:
                                visible.length +
                                (tab == 'history' && hasMoreHistory ? 1 : 0),
                            separatorBuilder: (_, i) =>
                                const SizedBox(height: Insets.md),
                            itemBuilder: (context, i) {
                              if (i == visible.length) {
                                return Center(
                                  child: OutlinedButton(
                                    onPressed: () => setState(
                                      () => _historyVisibleCount +=
                                          _kHistoryPageSize,
                                    ),
                                    child: const Text('Load more'),
                                  ),
                                );
                              }
                              final s = visible[i];
                              return SwapCard(
                                swap: s,
                                myUserId: myUserId,
                                next: nextBySwap[s.id],
                                onOpen: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SwapDetail(swapId: s.id),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SwapTabStrip extends StatelessWidget {
  const _SwapTabStrip({
    required this.current,
    required this.counts,
    required this.onChanged,
  });

  final String current;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  static const _labels = {
    'active': 'Active',
    'pending': 'Pending',
    'history': 'History',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: _labels.entries.map((e) {
          final active = e.key == current;
          final count = counts[e.key] ?? 0;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: active ? scheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      e.value,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: active
                            ? AppColors.primary
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : scheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
            child: Icon(
              Icons.notifications_none_rounded,
              size: 18,
              color: scheme.onSurface,
            ),
          ),
          if (count > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySwaps extends StatelessWidget {
  const _EmptySwaps({required this.tab});
  final String tab;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.repeat_rounded,
              size: 30,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'No $tab swaps yet',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
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
              'Couldn’t load your swaps',
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
