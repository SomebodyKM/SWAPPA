import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/sub_page.dart';
import 'admin_repository.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Users'),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.md,
                Insets.lg,
                Insets.sm,
              ),
              child: TextField(
                onChanged: (v) =>
                    ref.read(adminUserSearchProvider.notifier).state = v,
                decoration: const InputDecoration(
                  hintText: 'Search by name or email…',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminUsersProvider),
                child: usersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(Insets.xl),
                        child: Text(
                          'Couldn’t load users',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  data: (users) {
                    if (users.isEmpty) {
                      return ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Center(
                              child: Text(
                                'No users found',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.lg,
                        0,
                        Insets.lg,
                        Insets.lg,
                      ),
                      children: [
                        for (final u in users) ...[
                          _UserRow(user: u),
                          const SizedBox(height: Insets.md),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.user});
  final AdminUser user;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(adminUsersProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _reasonDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required Future<void> Function(String reason) onSubmit,
  }) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !context.mounted) return;
    await _act(context, ref, () => onSubmit(reason));
  }

  void _openActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(user.displayName),
              subtitle: Text(user.email ?? ''),
            ),
            const Divider(height: 1),
            if (user.status != 'banned')
              ListTile(
                leading: const Icon(
                  Icons.block_rounded,
                  color: AppColors.destructive,
                ),
                title: const Text(
                  'Ban',
                  style: TextStyle(color: AppColors.destructive),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _reasonDialog(
                    context,
                    ref,
                    title: 'Ban ${user.displayName}',
                    onSubmit: (reason) => ref
                        .read(adminRepositoryProvider)
                        .banUser(user.id, reason),
                  );
                },
              ),
            if (user.status == 'active')
              ListTile(
                leading: const Icon(Icons.pause_circle_outline_rounded),
                title: const Text('Suspend'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _reasonDialog(
                    context,
                    ref,
                    title: 'Suspend ${user.displayName}',
                    onSubmit: (reason) => ref
                        .read(adminRepositoryProvider)
                        .suspendUser(user.id, reason),
                  );
                },
              ),
            if (user.status != 'active')
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                ),
                title: const Text('Reinstate'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _act(
                    context,
                    ref,
                    () => ref.read(adminRepositoryProvider).unbanUser(user.id),
                  );
                },
              ),
            ListTile(
              leading: Icon(
                user.isAdmin
                    ? Icons.remove_moderator_outlined
                    : Icons.admin_panel_settings_outlined,
              ),
              title: Text(user.isAdmin ? 'Remove admin role' : 'Make admin'),
              onTap: () {
                Navigator.pop(sheetContext);
                _act(
                  context,
                  ref,
                  () => ref
                      .read(adminRepositoryProvider)
                      .setRole(user.id, user.isAdmin ? 'user' : 'admin'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (statusLabel, statusColor) = switch (user.status) {
      'banned' => ('Banned', AppColors.destructive),
      'suspended' => ('Suspended', const Color(0xFFB45309)),
      _ => ('Active', AppColors.success),
    };
    return GestureDetector(
      onTap: () => _openActions(context, ref),
      child: Container(
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (user.isAdmin) ...[
                        const SizedBox(width: 6),
                        const _StatusChip(
                          label: 'Admin',
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                  if (user.email != null)
                    Text(
                      user.email!,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            _StatusChip(label: statusLabel, color: statusColor),
          ],
        ),
      ),
    );
  }
}
