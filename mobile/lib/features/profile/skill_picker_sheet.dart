import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../shared/models/skill.dart';
import 'profile_providers.dart';

Future<void> showSkillPickerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SkillPicker(),
  );
}

class _SkillPicker extends ConsumerStatefulWidget {
  const _SkillPicker();

  @override
  ConsumerState<_SkillPicker> createState() => _SkillPickerState();
}

class _SkillPickerState extends ConsumerState<_SkillPicker> {
  String _kind = 'offer'; // offer | want
  String _proficiency = 'advanced'; // teach default; learn defaults to beginner
  String _query = '';
  bool _busy = false;
  String? _error;

  static const _profs = ['beginner', 'intermediate', 'advanced', 'expert'];

  void _selectKind(String kind) {
    setState(() {
      _kind = kind;
      _proficiency = kind == 'offer' ? 'advanced' : 'beginner';
    });
  }

  Future<void> _add(Skill skill) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .addTag(skillId: skill.id, kind: _kind, proficiency: _proficiency);
      ref.invalidate(myTagsProvider);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Not in the catalog yet — ask for a category, submit it (lands `pending`
  /// until an admin approves it), then immediately tag it too so the flow
  /// feels like adding any other skill rather than a two-step process.
  Future<void> _proposeAndAdd(String name) async {
    final categoryController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: Text('Propose "$name"'),
        content: TextField(
          controller: categoryController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Category'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    final category = categoryController.text.trim();
    if (confirmed != true || category.isEmpty || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final skill = await ref
          .read(profileRepositoryProvider)
          .proposeSkill(name: name, category: category);
      await ref
          .read(profileRepositoryProvider)
          .addTag(skillId: skill.id, kind: _kind, proficiency: _proficiency);
      ref.invalidate(myTagsProvider);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final catalog = ref.watch(skillsCatalogProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.md,
            Insets.lg,
            Insets.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              Text('Add a skill', style: text.titleLarge),
              const SizedBox(height: Insets.md),
              // Teach / Learn toggle
              Row(
                children: [
                  _kindChip(
                    'offer',
                    'I can teach',
                    AppColors.offerFg,
                    AppColors.offerBg,
                  ),
                  const SizedBox(width: Insets.sm),
                  _kindChip(
                    'want',
                    'I want to learn',
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.1),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Text(
                _kind == 'offer' ? 'Proficiency' : 'Your current level',
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final p in _profs)
                    ChoiceChip(
                      label: Text(p[0].toUpperCase() + p.substring(1)),
                      selected: _proficiency == p,
                      onSelected: (_) => setState(() => _proficiency = p),
                    ),
                ],
              ),
              const SizedBox(height: Insets.md),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search skills…',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              ),
              if (_error != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  _error!,
                  style: text.bodySmall?.copyWith(color: AppColors.destructive),
                ),
              ],
              const SizedBox(height: Insets.sm),
              Expanded(
                child: catalog.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Couldn’t load skills', style: text.bodyMedium),
                  ),
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
                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No skills match “$_query”',
                              style: text.bodyMedium,
                            ),
                            if (_query.trim().isNotEmpty) ...[
                              const SizedBox(height: Insets.md),
                              OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _proposeAndAdd(_query.trim()),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: Text('Propose “${_query.trim()}”'),
                              ),
                            ],
                          ],
                        ),
                      );
                    }
                    final grouped = groupSkillsByCategory(filtered);
                    return ListView(
                      children: [
                        for (final entry in grouped.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              entry.key.toUpperCase(),
                              style: text.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          for (final s in entry.value)
                            ListTile(
                              dense: true,
                              title: Text(s.name, style: text.bodyLarge),
                              trailing: _busy
                                  ? null
                                  : Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: AppColors.primary,
                                    ),
                              onTap: _busy ? null : () => _add(s),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kindChip(String kind, String label, Color fg, Color bg) {
    final active = _kind == kind;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectKind(kind),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? bg : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: active ? fg : scheme.outlineVariant,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: active ? fg : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
