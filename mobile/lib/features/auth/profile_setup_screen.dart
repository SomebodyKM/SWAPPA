import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/tier_limits.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/avatar_picker.dart';
import '../../design_system/widgets/sub_page.dart';
import '../../design_system/widgets/swappa_logo.dart';
import '../../shared/models/skill.dart';
import '../profile/profile_providers.dart';
import 'auth_controller.dart';

/// Post-signup profile + skills setup. Shown by the auth gate whenever the
/// session is authenticated but `onboardingComplete` is still false — right
/// after email verification, and again on any later login until finished.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  int _step = 1; // 1 = profile, 2 = teach, 3 = learn
  final _bio = TextEditingController();
  final Set<String> _teachIds = {};
  final Set<String> _learnIds = {};
  String _query = '';
  bool _busy = false;
  String? _error;

  int _cap() => TierLimits.of(
    ref.read(authControllerProvider).user?.tier ?? 'free',
  ).skillTagsPerKind;

  /// Try to toggle a skill in [set]; warn + refuse if it would exceed the
  /// per-kind cap (3 teach / 3 learn on free).
  void _toggle(Set<String> set, String id) {
    if (set.contains(id)) {
      setState(() => set.remove(id));
      return;
    }
    if (set.length >= _cap()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Free plan allows up to ${_cap()} skills here. Upgrade to add more.',
            ),
          ),
        );
      return;
    }
    setState(() => set.add(id));
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(profileRepositoryProvider);
    try {
      if (_bio.text.trim().isNotEmpty) {
        await repo.updateProfile(bio: _bio.text.trim());
      }
      for (final id in _teachIds) {
        await _addTagSafe(repo, id, 'offer', 'advanced');
      }
      for (final id in _learnIds) {
        await _addTagSafe(repo, id, 'want', 'beginner');
      }
      await ref.read(authControllerProvider.notifier).completeOnboarding();
      // The auth gate switches to AppShell once onboardingComplete flips.
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Adds a tag, ignoring "already added" conflicts from a prior partial run.
  Future<void> _addTagSafe(
    ProfileRepository repo,
    String id,
    String kind,
    String? prof,
  ) async {
    try {
      await repo.addTag(skillId: id, kind: kind, proficiency: prof);
    } on ApiException catch (e) {
      if (e.code == 'TAG_EXISTS') return; // already have it — fine
      rethrow;
    }
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, Insets.md, 24, Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_step > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: Insets.sm),
                      child: GestureDetector(
                        onTap: () => setState(() => _step -= 1),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  const SwappaWordmark(iconSize: 36),
                ],
              ),
              const SizedBox(height: Insets.xl),
              Row(
                children: [
                  for (var s = 1; s <= 3; s++) ...[
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: s <= _step
                              ? AppColors.primary
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                      ),
                    ),
                    if (s < 3) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: Insets.xl),
              Expanded(
                child: switch (_step) {
                  1 => _profileStep(context, text, scheme),
                  2 => _skillStep(
                    context,
                    text,
                    title: 'What can you teach?',
                    subtitle:
                        'Pick at least one skill you can share with others.',
                    selected: _teachIds,
                    chipColor: AppColors.offerFg,
                    chipBg: AppColors.offerBg,
                  ),
                  _ => _skillStep(
                    context,
                    text,
                    title: 'What do you want to learn?',
                    subtitle: 'Pick at least one skill you\'d like to pick up.',
                    selected: _learnIds,
                    chipColor: AppColors.primary,
                    chipBg: AppColors.primary.withValues(alpha: 0.1),
                  ),
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  _error!,
                  style: text.bodySmall?.copyWith(color: AppColors.destructive),
                ),
              ],
              const SizedBox(height: Insets.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _primaryAction,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_step < 3 ? 'Continue' : 'Start swapping 🎉'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback? get _primaryAction {
    if (_step == 1) {
      return () => setState(() => _step = 2);
    }
    if (_step == 2) {
      if (_teachIds.isEmpty) return null;
      return () => setState(() {
        _step = 3;
        _query = '';
      });
    }
    return _learnIds.isEmpty ? null : _finish;
  }

  Widget _profileStep(
    BuildContext context,
    TextTheme text,
    ColorScheme scheme,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your profile', style: text.headlineMedium),
          const SizedBox(height: 2),
          Text(
            'Help your swap partners get to know you.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Insets.lg),
          const Center(child: AvatarPicker(size: 80)),
          const SizedBox(height: Insets.lg),
          FieldGroup(
            label: 'Short bio',
            child: FilledField(
              controller: _bio,
              maxLines: 3,
              hint: 'A sentence or two about you and your interests…',
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillStep(
    BuildContext context,
    TextTheme text, {
    required String title,
    required String subtitle,
    required Set<String> selected,
    required Color chipColor,
    required Color chipBg,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final catalog = ref.watch(skillsCatalogProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.headlineSmall),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          '(${selected.length} / ${_cap()})',
          style: text.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Insets.md),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search skills…',
            prefixIcon: Icon(Icons.search_rounded, size: 20),
          ),
          onChanged: (v) => setState(() => _query = v.toLowerCase()),
        ),
        const SizedBox(height: Insets.md),
        Expanded(
          child: catalog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Text('Couldn’t load skills', style: text.bodyMedium),
            data: (skills) {
              final filtered = _query.isEmpty
                  ? skills
                  : skills
                        .where(
                          (s) =>
                              s.name.toLowerCase().contains(_query) ||
                              s.category.toLowerCase().contains(_query),
                        )
                        .toList();
              final grouped = groupSkillsByCategory(filtered);
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: text.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in entry.value)
                            _SkillChoiceChip(
                              skill: s,
                              selected: selected.contains(s.id),
                              selectedColor: chipColor,
                              selectedBg: chipBg,
                              onTap: () => _toggle(selected, s.id),
                            ),
                        ],
                      ),
                      const SizedBox(height: Insets.md),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SkillChoiceChip extends StatelessWidget {
  const _SkillChoiceChip({
    required this.skill,
    required this.selected,
    required this.selectedColor,
    required this.selectedBg,
    required this.onTap,
  });
  final Skill skill;
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
          selected ? '✓ ${skill.name}' : skill.name,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? selectedColor : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
