import 'package:flutter/material.dart';

import '../../app/app_shell.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/sub_page.dart';
import '../../design_system/widgets/swappa_logo.dart';
import 'widgets/auth_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 1;
  final _name = TextEditingController();
  final _teach = <String>{};
  final _learn = <String>{};

  static const _teachOpts = ['Guitar', 'Cooking', 'Photography', 'Yoga', 'Drawing', 'Coding'];
  static const _learnOpts = ['Mandarin', 'Spanish', 'Watercolour', 'Web Dev', 'Pottery', 'Baking'];

  void _enterApp() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, Insets.md, 24, Insets.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SwappaWordmark(iconSize: 36),
                  const Spacer(),
                  if (_step == 1)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text('Log in',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: Insets.xl),
              // Progress
              Row(
                children: [
                  for (var s = 1; s <= 3; s++) ...[
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: s <= _step ? AppColors.primary : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                      ),
                    ),
                    if (s < 3) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: Insets.xl),
              if (_step == 1) ..._step1(context) else if (_step == 2) ..._step2(context) else ..._step3(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _step1(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return [
      Text('Create your account', style: text.headlineSmall),
      const SizedBox(height: 2),
      Text('Trade skills directly — teach one, learn one.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: Insets.lg),
      const GoogleButton(label: 'Sign up with Google'),
      const SizedBox(height: Insets.lg),
      const AuthDivider(),
      const SizedBox(height: Insets.lg),
      const FieldGroup(label: 'Email or phone', child: FilledField(hint: 'you@example.com or +44 7700…')),
      const SizedBox(height: Insets.md),
      const FieldGroup(label: 'Password', child: FilledField(obscure: true, hint: '••••••••')),
      const SizedBox(height: Insets.lg),
      // Welcome bonus banner
      Container(
        padding: const EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.card_giftcard_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('10 free credits to start',
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text('One-time welcome bonus — try an AI action right away.',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Insets.lg),
      SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: () => setState(() => _step = 2), child: const Text('Create account')),
      ),
    ];
  }

  List<Widget> _step2(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return [
      Text('Your profile', style: text.headlineSmall),
      const SizedBox(height: 2),
      Text('Help your swap partners get to know you.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: Insets.lg),
      Center(
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(Radii.xl),
          ),
          child: Text(_name.text.isNotEmpty ? _name.text[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(height: Insets.lg),
      FieldGroup(
        label: 'Display name',
        child: FilledField(controller: _name, hint: 'Jordan Kim', onChanged: (_) => setState(() {})),
      ),
      const SizedBox(height: Insets.md),
      const FieldGroup(
        label: 'Short bio',
        child: FilledField(maxLines: 3, hint: 'A sentence or two about you and your interests…'),
      ),
      const SizedBox(height: Insets.lg),
      SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: () => setState(() => _step = 3), child: const Text('Continue')),
      ),
    ];
  }

  List<Widget> _step3(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final canFinish = _teach.isNotEmpty && _learn.isNotEmpty;
    return [
      Text('Your skills', style: text.headlineSmall),
      const SizedBox(height: 2),
      Text('Add at least one you teach and one to learn.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: Insets.lg),
      Text('I can teach',
          style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
      const SizedBox(height: Insets.sm),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in _teachOpts)
            _ChoiceChip(
              label: s,
              selected: _teach.contains(s),
              selectedColor: AppColors.offerFg,
              selectedBg: AppColors.offerBg,
              onTap: () => setState(() => _teach.contains(s) ? _teach.remove(s) : _teach.add(s)),
            ),
        ],
      ),
      const SizedBox(height: Insets.lg),
      Text('I want to learn',
          style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
      const SizedBox(height: Insets.sm),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in _learnOpts)
            _ChoiceChip(
              label: s,
              selected: _learn.contains(s),
              selectedColor: Colors.white,
              selectedBg: AppColors.primary,
              onTap: () => setState(() => _learn.contains(s) ? _learn.remove(s) : _learn.add(s)),
            ),
        ],
      ),
      const SizedBox(height: Insets.xl),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: canFinish ? _enterApp : null,
          child: const Text('Start swapping 🎉'),
        ),
      ),
    ];
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.selectedBg,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color selectedBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
            color: selected ? selectedBg : scheme.outlineVariant,
            width: 2,
          ),
        ),
        child: Text(
          selected ? '✓ $label' : label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? selectedColor : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
