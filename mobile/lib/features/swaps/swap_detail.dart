import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/avatar.dart';
import '../../design_system/widgets/status_badge.dart';
import 'swap.dart';

class SwapDetail extends StatefulWidget {
  const SwapDetail({super.key, required this.swap});
  final Swap swap;

  @override
  State<SwapDetail> createState() => _SwapDetailState();
}

class _SwapDetailState extends State<SwapDetail> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.swap;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.md),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  _CircleIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: Insets.md),
                  Avatar(initials: s.initials, color: avatarColorFor(s.id), size: 36),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.partner, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text('${s.mine} ↔ ${s.theirs}',
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  StatusBadge(status: s.status),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Insets.lg),
                children: [
                  _SectionCard(
                    title: 'Sessions',
                    icon: Icons.schedule_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (s.next != null) _UpcomingSession(next: s.next!, format: s.format),
                        Text(
                          '${s.sessions} session${s.sessions == 1 ? '' : 's'} completed',
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (s.status == 'active') ...[
                    const SizedBox(height: Insets.lg),
                    _SectionCard(
                      title: 'Actions',
                      child: Column(
                        children: [
                          const SizedBox(height: Insets.sm),
                          _OutlineAction(
                            icon: Icons.add_rounded,
                            label: 'Propose new session',
                            onTap: () {},
                          ),
                          const SizedBox(height: Insets.sm),
                          if (!_confirming)
                            _OutlineAction(
                              icon: Icons.check_circle_outline_rounded,
                              label: 'Mark complete',
                              color: AppColors.success,
                              onTap: () => setState(() => _confirming = true),
                            )
                          else
                            _ConfirmComplete(
                              partner: s.partner,
                              onCancel: () => setState(() => _confirming = false),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: scheme.onSurface),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.icon, required this.child});
  final String title;
  final IconData? icon;
  final Widget child;

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
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
              ],
              Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: Insets.md),
          child,
        ],
      ),
    );
  }
}

class _UpcomingSession extends StatelessWidget {
  const _UpcomingSession({required this.next, required this.format});
  final String next;
  final String format;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upcoming',
              style: text.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(next, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text(format, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
                ),
                child: const Text('Reschedule'),
              ),
              const SizedBox(width: Insets.sm),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  foregroundColor: scheme.onSurfaceVariant,
                  side: BorderSide(color: scheme.outlineVariant),
                  textStyle: text.labelMedium,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
                ),
                child: const Text('Decline'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({required this.icon, required this.label, this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurface;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15, color: c),
        label: Text(label, style: TextStyle(color: c)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          side: BorderSide(color: color?.withValues(alpha: 0.4) ?? scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        ),
      ),
    );
  }
}

class _ConfirmComplete extends StatelessWidget {
  const _ConfirmComplete({required this.partner, required this.onCancel});
  final String partner;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Both you and $partner must confirm to complete this swap and free up an active-swap slot.',
            style: text.bodySmall?.copyWith(color: AppColors.offerFg),
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size.fromHeight(38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xs)),
                  ),
                  child: const Text('Confirm complete'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xs)),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
