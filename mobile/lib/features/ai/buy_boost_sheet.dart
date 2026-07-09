import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_typography.dart';
import '../../design_system/tokens.dart';
import '../wallet/credit_repository.dart';
import 'sheet_scaffold.dart';

Future<void> showBuyBoostSheet(BuildContext context) {
  return showAppSheet(context, child: const _BuyBoost());
}

/// Presentation-only metadata keyed by productId — `GET /credits/packs` only
/// ever returns productId + credits (the real price comes from the store at
/// purchase time), so price/label/badge stay static placeholders here until
/// RevenueCat is wired on mobile.
class _PackDisplay {
  const _PackDisplay(this.label, this.price, this.ppu, [this.badge]);
  final String label;
  final String price;
  final String ppu;
  final String? badge;
}

const _display = <String, _PackDisplay>{
  'boost_small': _PackDisplay('Small', '£1.99', '8p / credit'),
  'boost_medium': _PackDisplay('Medium', '£4.99', '8p / credit', 'Popular'),
  'boost_large': _PackDisplay('Large', '£9.99', '7p / credit', 'Best value'),
};
const _fallbackDisplay = _PackDisplay('Pack', '—', '');

class _BuyBoost extends ConsumerStatefulWidget {
  const _BuyBoost();

  @override
  ConsumerState<_BuyBoost> createState() => _BuyBoostState();
}

class _BuyBoostState extends ConsumerState<_BuyBoost> {
  int _sel = 1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final packsAsync = ref.watch(boostPacksProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Buy Boost Credits', style: text.headlineSmall),
        const SizedBox(height: 2),
        Text(
          'Permanent credits that never expire. Better value in bulk.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Insets.lg),
        packsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            'Couldn’t load Boost packs',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          data: (packs) {
            if (packs.isEmpty) return const SizedBox.shrink();
            final sel = _sel.clamp(0, packs.length - 1);
            final chosenDisplay =
                _display[packs[sel].productId] ?? _fallbackDisplay;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < packs.length; i++) ...[
                  _PackRow(
                    pack: packs[i],
                    display: _display[packs[i].productId] ?? _fallbackDisplay,
                    selected: sel == i,
                    onTap: () => setState(() => _sel = i),
                  ),
                  const SizedBox(height: Insets.md),
                ],
                const SizedBox(height: 2),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.foreground,
                    ),
                    child: Text(
                      'Buy ${chosenDisplay.label} Pack — ${chosenDisplay.price}',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: Insets.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.pack,
    required this.display,
    required this.selected,
    required this.onTap,
  });
  final BoostPack pack;
  final _PackDisplay display;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: selected ? AppColors.primary : scheme.outlineVariant,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            _Radio(selected: selected),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        display.label,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (display.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: Text(
                            display.badge!,
                            style: text.labelSmall?.copyWith(
                              color: AppColors.foreground,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${pack.credits} credits · ${display.ppu}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              display.price,
              style: AppTypography.tabular(size: 18, color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : scheme.onSurfaceVariant,
          width: 2,
        ),
      ),
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
