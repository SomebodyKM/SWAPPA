import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/sub_page.dart';
import 'admin_repository.dart';

const _filters = <(String, String)>[
  ('', 'All'),
  ('open', 'Open'),
  ('resolved', 'Resolved'),
  ('dismissed', 'Dismissed'),
];

class AdminBugReportsScreen extends ConsumerWidget {
  const AdminBugReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(adminBugReportsProvider);
    final activeFilter = ref.watch(adminBugReportFilterProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Bug Reports'),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                children: [
                  for (final f in _filters) ...[
                    ChoiceChip(
                      label: Text(f.$2),
                      selected: activeFilter == f.$1,
                      onSelected: (_) =>
                          ref
                                  .read(adminBugReportFilterProvider.notifier)
                                  .state =
                              f.$1,
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Insets.sm),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminBugReportsProvider),
                child: reportsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(Insets.xl),
                        child: Text(
                          'Couldn’t load bug reports',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  data: (reports) {
                    if (reports.isEmpty) {
                      return ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Center(
                              child: Text(
                                'No bug reports here',
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
                        for (final r in reports) ...[
                          _BugReportRow(report: r),
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

class _BugReportRow extends ConsumerWidget {
  const _BugReportRow({required this.report});
  final AdminBugReport report;

  bool get _open => report.status == 'open';

  Future<void> _noteDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required Future<void> Function(String note) onSubmit,
  }) async {
    final controller = TextEditingController();
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
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Note (optional)'),
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
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await onSubmit(controller.text.trim());
      ref.invalidate(adminBugReportsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (statusLabel, statusColor) = switch (report.status) {
      'resolved' => ('Resolved', AppColors.success),
      'dismissed' => ('Dismissed', scheme.onSurfaceVariant),
      _ => ('Open', const Color(0xFFB45309)),
    };
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
                  report.reporterName,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  statusLabel,
                  style: text.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            report.description,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (report.resolutionNote != null &&
              report.resolutionNote!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Note: ${report.resolutionNote}',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (_open) ...[
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _noteDialog(
                      context,
                      ref,
                      title: 'Dismiss bug report',
                      onSubmit: (note) => ref
                          .read(adminRepositoryProvider)
                          .dismissBugReport(report.id, note),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _noteDialog(
                      context,
                      ref,
                      title: 'Resolve bug report',
                      onSubmit: (note) => ref
                          .read(adminRepositoryProvider)
                          .resolveBugReport(report.id, note),
                    ),
                    child: const Text('Resolve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
