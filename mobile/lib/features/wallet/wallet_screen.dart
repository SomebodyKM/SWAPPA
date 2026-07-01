import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_typography.dart';
import '../../design_system/tokens.dart';
import '../ai/buy_boost_sheet.dart';
import '../ai/paywall_sheet.dart';
import 'wallet_data.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  static const int basic = 5;
  static const int basicCap = 15;
  static const int boost = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.sm),
              child: Text('Wallet', style: text.headlineSmall),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Insets.lg, 4, Insets.lg, Insets.xxl),
                children: [
                  // Dual balances
                  Row(
                    children: [
                      Expanded(
                        child: _BalanceCard(
                          label: 'Basic Credits',
                          value: basic,
                          fraction: basic / basicCap,
                          sub: 'Refills in 5 days',
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, Color(0xFF5B21B6)],
                          ),
                          fg: Colors.white,
                          barBg: Colors.white24,
                          barFg: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: _BalanceCard(
                          label: 'Boost Credits',
                          value: boost,
                          fraction: 1,
                          sub: 'Never expire',
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.accent, Color(0xFFCA8A04)],
                          ),
                          fg: AppColors.foreground,
                          barBg: Colors.black12,
                          barFg: Colors.black26,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  Center(
                    child: Text('AI actions use Basic first, then Boost',
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                  const SizedBox(height: Insets.md),

                  // Buy boost
                  _BuyBoostButton(onTap: () => showBuyBoostSheet(context)),
                  const SizedBox(height: Insets.md),

                  // AI actions
                  _CardSection(
                    title: 'AI Actions',
                    children: [
                      for (final a in aiActions) _AiActionRow(action: a),
                    ],
                  ),
                  const SizedBox(height: Insets.md),

                  // Ledger
                  _CardSection(
                    title: 'Transaction History',
                    children: [for (final t in sampleTxns) _TxnRow(txn: t)],
                  ),
                  const SizedBox(height: Insets.md),

                  // Plan card
                  _PlanCard(onExplore: () => showPaywallSheet(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.label,
    required this.value,
    required this.fraction,
    required this.sub,
    required this.gradient,
    required this.fg,
    required this.barBg,
    required this.barFg,
  });

  final String label;
  final int value;
  final double fraction;
  final String sub;
  final Gradient gradient;
  final Color fg;
  final Color barBg;
  final Color barFg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: fg.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('$value', style: AppTypography.tabular(size: 34, color: fg)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 4,
              backgroundColor: barBg,
              valueColor: AlwaysStoppedAnimation(barFg),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyBoostButton extends StatelessWidget {
  const _BuyBoostButton({required this.onTap});
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
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: const Icon(Icons.shopping_bag_rounded, size: 18, color: AppColors.foreground),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Buy Boost Credits',
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text('Permanent · better value in bulk',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          ...children,
        ],
      ),
    );
  }
}

class _AiActionRow extends StatelessWidget {
  const _AiActionRow({required this.action});
  final AiActionInfo action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(action.icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action.label, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(action.desc, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.monetization_on_rounded, size: 11, color: scheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text('${action.cost}',
                    style: AppTypography.tabular(size: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn});
  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final positive = txn.amount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: positive
                  ? AppColors.offerBg
                  : AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(positive ? '+' : '−',
                style: TextStyle(
                    color: positive ? AppColors.offerFg : AppColors.primary,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                Text('${txn.date} · ${txn.basic ? "Basic" : "Boost"}',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(
            '${positive ? "+" : ""}${txn.amount}',
            style: AppTypography.tabular(
              size: 14,
              color: positive ? AppColors.success : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.onExplore});
  final VoidCallback onExplore;

  static const _perks = [
    '2 match results shown',
    '5 active swaps',
    '15 Basic credits / week',
    'Text chat only',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: Insets.sm),
              Text('Free Plan', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text('Current',
                    style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          for (final p in _perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_rounded, size: 13, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(p, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          const SizedBox(height: Insets.sm),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: onExplore,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
              ),
              child: const Text('Explore Premium'),
            ),
          ),
        ],
      ),
    );
  }
}
