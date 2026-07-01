import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import 'swap.dart';
import 'swap_detail.dart';
import 'widgets/swap_card.dart';

class SwapsScreen extends StatefulWidget {
  const SwapsScreen({super.key});

  @override
  State<SwapsScreen> createState() => _SwapsScreenState();
}

class _SwapsScreenState extends State<SwapsScreen> {
  String _tab = 'active';

  List<Swap> get _active => sampleSwaps.where((s) => s.status == 'active').toList();
  List<Swap> get _pending => sampleSwaps.where((s) => s.status == 'pending').toList();
  List<Swap> get _history =>
      sampleSwaps.where((s) => s.status == 'completed' || s.status == 'cancelled').toList();

  List<Swap> get _visible => switch (_tab) {
        'pending' => _pending,
        'history' => _history,
        _ => _active,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    const cap = 5;
    final activeCount = _active.length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Swaps', style: text.headlineSmall),
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          child: LinearProgressIndicator(
                            value: activeCount / cap,
                            minHeight: 6,
                            backgroundColor: scheme.surfaceContainerHighest,
                            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Text('$activeCount / $cap active',
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  _SwapTabStrip(
                    current: _tab,
                    counts: {
                      'active': _active.length,
                      'pending': _pending.length,
                      'history': _history.length,
                    },
                    onChanged: (t) => setState(() => _tab = t),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _visible.isEmpty
                  ? _EmptySwaps(tab: _tab)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(Insets.lg, 4, Insets.lg, Insets.xxl),
                      itemCount: _visible.length,
                      separatorBuilder: (_, i) => const SizedBox(height: Insets.md),
                      itemBuilder: (context, i) {
                        final s = _visible[i];
                        return SwapCard(
                          swap: s,
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => SwapDetail(swap: s)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwapTabStrip extends StatelessWidget {
  const _SwapTabStrip({required this.current, required this.counts, required this.onChanged});

  final String current;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  static const _labels = {'active': 'Active', 'pending': 'Pending', 'history': 'History'};

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
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      e.value,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: active ? AppColors.primary : scheme.onSurfaceVariant,
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
                          color: active ? AppColors.primary : scheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Text('$count',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
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

class _EmptySwaps extends StatelessWidget {
  const _EmptySwaps({required this.tab});
  final String tab;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat_rounded, size: 30, color: scheme.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: Insets.sm),
          Text('No $tab swaps yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
