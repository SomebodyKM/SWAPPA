import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/sub_page.dart';
import 'admin_repository.dart';

class AdminSkillsScreen extends ConsumerWidget {
  const AdminSkillsScreen({super.key});

  static const _sections = [
    ('pending', 'Awaiting approval'),
    ('all', 'All skills'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(adminSkillSectionProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Skill Moderation'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: Row(
                children: [
                  for (final (value, label) in _sections) ...[
                    ChoiceChip(
                      label: Text(label),
                      selected: section == value,
                      onSelected: (_) =>
                          ref.read(adminSkillSectionProvider.notifier).state =
                              value,
                    ),
                    const SizedBox(width: Insets.sm),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Insets.sm),
            Expanded(
              child: section == 'pending'
                  ? const _PendingSkillsList()
                  : const _AllSkillsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createSkill(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Future<void> _createSkill(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.xl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: const Text('Add skill'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Name'),
              ),
              const SizedBox(height: Insets.sm),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(hintText: 'Category'),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (created != true) return;
    final name = nameController.text.trim();
    final category = categoryController.text.trim();
    if (name.isEmpty || category.isEmpty) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .createSkill(name: name, category: category);
      // Admin-authored skills land `approved` straight away, so they only
      // ever show up in "All skills" — but refresh both since the FAB is
      // reachable from either section.
      ref.invalidate(adminPendingSkillsProvider);
      ref.invalidate(adminAllSkillsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _PendingSkillsList extends ConsumerWidget {
  const _PendingSkillsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(adminPendingSkillsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminPendingSkillsProvider),
      child: skillsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Text(
                'Couldn’t load pending skills',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        data: (skills) {
          if (skills.isEmpty) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(
                    child: Text(
                      'No skills awaiting approval',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(Insets.lg),
            children: [
              for (final s in skills) ...[
                _PendingSkillRow(skill: s),
                const SizedBox(height: Insets.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PendingSkillRow extends ConsumerWidget {
  const _PendingSkillRow({required this.skill});
  final AdminSkill skill;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(adminPendingSkillsProvider);
      ref.invalidate(adminAllSkillsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.xl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: Text('Delete "${skill.name}"?'),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.destructive,
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _act(
      context,
      ref,
      () => ref.read(adminRepositoryProvider).deleteSkill(skill.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.name,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  skill.category,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline_rounded),
            color: AppColors.success,
            tooltip: 'Approve',
            onPressed: () => _act(
              context,
              ref,
              () => ref.read(adminRepositoryProvider).approveSkill(skill.id),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.destructive,
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }
}

class _AllSkillsList extends ConsumerWidget {
  const _AllSkillsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(adminAllSkillsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminAllSkillsProvider),
      child: skillsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Text(
                'Couldn’t load skills',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        data: (skills) {
          if (skills.isEmpty) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(
                    child: Text(
                      'No skills in the catalog yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(Insets.lg),
            children: [
              for (final s in skills) ...[
                _AllSkillRow(skill: s),
                const SizedBox(height: Insets.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AllSkillRow extends ConsumerWidget {
  const _AllSkillRow({required this.skill});
  final AdminSkill skill;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(adminAllSkillsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController(text: skill.name);
    final categoryController = TextEditingController(text: skill.category);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.xl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: const Text('Edit skill'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Name'),
              ),
              const SizedBox(height: Insets.sm),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(hintText: 'Category'),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    final name = nameController.text.trim();
    final category = categoryController.text.trim();
    if (name.isEmpty || category.isEmpty) return;
    await _act(
      context,
      ref,
      () => ref
          .read(adminRepositoryProvider)
          .editSkill(skill.id, name: name, category: category),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.xl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: Text('Remove "${skill.name}"?'),
        content: const Text(
          'Users who already tagged this skill will keep it, but it will no '
          'longer be searchable or offered to new users.',
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.destructive,
                  ),
                  child: const Text('Remove'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _act(
      context,
      ref,
      () => ref.read(adminRepositoryProvider).deleteSkill(skill.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.name,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  skill.category,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: scheme.onSurfaceVariant,
            tooltip: 'Edit',
            onPressed: () => _edit(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.destructive,
            tooltip: 'Remove',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }
}
