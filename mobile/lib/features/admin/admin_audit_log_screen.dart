import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/tokens.dart';
import '../../design_system/widgets/sub_page.dart';
import 'admin_repository.dart';

class AdminAuditLogScreen extends ConsumerWidget {
  const AdminAuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(adminAuditLogProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Audit Log'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminAuditLogProvider),
                child: logAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(Insets.xl),
                        child: Text(
                          'Couldn’t load the audit log',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Center(
                              child: Text(
                                'No admin actions recorded yet',
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
                        Insets.sm,
                        Insets.lg,
                        Insets.lg,
                      ),
                      children: [
                        for (final e in entries) ...[
                          _AuditRow(entry: e),
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

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});
  final AdminAuditEntry entry;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _label(String action) => switch (action) {
    'skill_create' => 'Created a skill',
    'skill_edit' => 'Edited a skill',
    'skill_delete' => 'Deleted a skill',
    'user_ban' => 'Banned a user',
    'user_unban' => 'Reinstated a user',
    'user_suspend' => 'Suspended a user',
    'role_change' => 'Changed a user role',
    'report_resolve' => 'Resolved a report',
    'report_dismiss' => 'Dismissed a report',
    'bug_resolve' => 'Resolved a bug report',
    'bug_dismiss' => 'Dismissed a bug report',
    _ => action,
  };

  static String _when(DateTime? d) {
    if (d == null) return '';
    return '${d.day} ${_months[d.month - 1]} ${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
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
              Expanded(
                child: Text(
                  _label(entry.action),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _when(entry.createdAt),
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'by ${entry.adminName} · target: ${entry.targetType}',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (entry.detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.detail.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join(', '),
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
