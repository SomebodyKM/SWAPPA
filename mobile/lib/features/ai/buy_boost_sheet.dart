import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_typography.dart';
import '../../design_system/tokens.dart';
import 'sheet_scaffold.dart';

Future<void> showBuyBoostSheet(BuildContext context) {
  return showAppSheet(context, child: const _BuyBoost());
}

class _BoostPack {
  const _BoostPack(this.label, this.credits, this.price, this.ppu, [this.badge]);
  final String label;
  final int credits;
  final String price;
  final String ppu;
  final String? badge;
}

const _packs = [
  _BoostPack('Small', 10, '£1.99', '20p / credit'),
  _BoostPack('Medium', 30, '£4.99', '17p / credit', 'Popular'),
  _BoostPack('Large', 75, '£9.99', '13p / credit', 'Best value'),
];

class _BuyBoost extends StatefulWidget {
  const _BuyBoost();

  @override
  State<_BuyBoost> createState() => _BuyBoostState();
}

class _BuyBoostState extends State<_BuyBoost> {
  int _sel = 1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final chosen = _packs[_sel];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Buy Boost Credits', style: text.headlineSmall),
        const SizedBox(height: 2),
        Text('Permanent credits that never expire. Better value in bulk.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: Insets.lg),
        for (var i = 0; i < _packs.length; i++) ...[
          _PackRow(
            pack: _packs[i],
            selected: _sel == i,
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
            child: Text('Buy ${chosen.label} Pack — ${chosen.price}'),
          ),
        ),
        const SizedBox(height: Insets.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ),
      ],
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({required this.pack, required this.selected, required this.onTap});
  final _BoostPack pack;
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
                      Text(pack.label, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      if (pack.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: Text(pack.badge!,
                              style: text.labelSmall?.copyWith(
                                  color: AppColors.foreground, fontWeight: FontWeight.w700, fontSize: 10)),
                        ),
                      ],
                    ],
                  ),
                  Text('${pack.credits} credits · ${pack.ppu}',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(pack.price, style: AppTypography.tabular(size: 18, color: scheme.onSurface)),
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
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            )
          : null,
    );
  }
}
