import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_typography.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/avatar.dart';
import 'settings/settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _teach = ['Guitar', 'Photography', 'Yoga'];
  static const _learn = ['Mandarin Chinese', 'Watercolour'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.sm),
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
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.settings_rounded, size: 17, color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Insets.lg, 4, Insets.lg, Insets.xxl),
                children: [
                  _ProfileHeaderCard(),
                  const SizedBox(height: Insets.md),
                  _SkillsCard(teach: _teach, learn: _learn),
                  const SizedBox(height: Insets.md),
                  _ReviewsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
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
                ),
                child: Text('JK',
                    style: GoogleFonts.fredoka(
                        fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Jordan Kim', style: text.titleMedium),
                        const SizedBox(width: Insets.sm),
                        _pill(context, 'Free'),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.place_rounded, size: 12, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text('London, UK (approx.)',
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 12, color: AppColors.accent),
                        const SizedBox(width: 3),
                        Text('4.8', style: AppTypography.tabular(size: 12, color: scheme.onSurface)),
                        Text(' · 12 reviews',
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Musician & photographer looking to expand horizons. Love learning something genuinely new each week!',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
    );
  }
}

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({required this.teach, required this.learn});
  final List<String> teach;
  final List<String> learn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skillHeader(context, 'Can teach', '${teach.length}/3 free limit'),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final s in teach) _tag(context, s, AppColors.offerBg, AppColors.offerFg)],
          ),
          const SizedBox(height: Insets.md),
          _skillHeader(context, 'Want to learn', '${learn.length}/3'),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in learn)
                _tag(context, s, AppColors.primary.withValues(alpha: 0.08), AppColors.primary),
            ],
          ),
          const SizedBox(height: Insets.md),
          // Add skill (dashed pill)
          DecoratedBox(
            decoration: const BoxDecoration(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(
                  color: scheme.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('Add skill',
                      style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillHeader(BuildContext context, String title, String hint) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(hint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _tag(BuildContext context, String s, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Text(s,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _ReviewsCard extends StatelessWidget {
  static const _reviews = [
    ('Luca Romano', 'Jordan is a fantastic teacher — patient, encouraging, and so musical!', 5),
    ('Priya Sharma', 'Great swap partner. Really flexible with scheduling too.', 5),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reviews', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: Insets.md),
          for (var i = 0; i < _reviews.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(
                    initials: _reviews[i].$1.split(' ').map((w) => w[0]).take(2).join(),
                    color: avatarColorFor(_reviews[i].$1),
                    size: 36),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_reviews[i].$1,
                              style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          Row(
                            children: List.generate(
                              _reviews[i].$3,
                              (_) => const Icon(Icons.star_rounded, size: 11, color: AppColors.accent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(_reviews[i].$2,
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
            if (i < _reviews.length - 1) const SizedBox(height: Insets.md),
          ],
        ],
      ),
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
