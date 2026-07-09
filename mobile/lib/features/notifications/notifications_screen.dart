import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import 'notification_navigation.dart';
import 'notification_repository.dart';
import 'notification_style.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Swiped-away ids, hidden immediately while the archive request is in
  // flight — Dismissible requires its item gone from the list on the very
  // next build, which a round-trip to the server can't guarantee in time.
  final Set<String> _archived = {};
  // Cached rather than read from `ref` in dispose() — Riverpod forbids
  // `ref.read`/`ref.watch` once a widget is being torn down.
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _bindSocket();
  }

  // Owns its own realtime binding rather than relying solely on AppShell's
  // global listener, so this screen refreshes the instant a notification
  // arrives while it's open — no manual pull-to-refresh needed.
  Future<void> _bindSocket() async {
    final socket = await ref.read(socketClientProvider).ensureConnected();
    if (!mounted) return;
    _socket = socket;
    socket.on('notification', _onNotification);
  }

  void _onNotification(dynamic data) {
    final type = (data is Map) ? data['type']?.toString() : null;
    if (type == null || type == 'message_received') return;
    ref.invalidate(notificationsProvider);
  }

  @override
  void dispose() {
    _socket?.off('notification', _onNotification);
    super.dispose();
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
    } on ApiException {
      // best-effort; the list still refreshes below
    }
    ref.invalidate(notificationsProvider);
  }

  Future<void> _archive(AppNotification notif) async {
    setState(() => _archived.add(notif.id));
    try {
      await ref.read(notificationRepositoryProvider).remove(notif.id);
      ref.invalidate(notificationsProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _archived.remove(notif.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final notifsAsync = ref.watch(notificationsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.sm,
                Insets.lg,
                Insets.md,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Text('Notifications', style: text.titleLarge),
                  const Spacer(),
                  GestureDetector(
                    onTap: _markAllRead,
                    child: Text(
                      'Mark all read',
                      style: text.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notifsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Couldn’t load notifications',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                data: (all) {
                  final notifs = all
                      .where((n) => !_archived.contains(n.id))
                      .toList();
                  if (notifs.isEmpty) return const _EmptyNotifications();

                  final entries = _groupByDay(notifs);
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(notificationsProvider),
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final entry = entries[i];
                        if (entry.header != null) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Insets.lg,
                              Insets.md,
                              Insets.lg,
                              Insets.xs,
                            ),
                            child: Text(
                              entry.header!,
                              style: text.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }
                        final n = entry.notif!;
                        return Dismissible(
                          key: ValueKey(n.id),
                          direction: DismissDirection.endToStart,
                          background: const _ArchiveBackground(),
                          onDismissed: (_) => _archive(n),
                          child: _NotifRow(notif: n),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A section header ("Today" / "Yesterday" / date) or a single notification
/// — mixed into one flat list so `ListView.builder` can render both without
/// a second widget tree per day.
class _FeedEntry {
  const _FeedEntry.header(this.header) : notif = null;
  const _FeedEntry.item(AppNotification n) : notif = n, header = null;

  final String? header;
  final AppNotification? notif;
}

const _months = [
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

String _dayLabel(DateTime dt) {
  final now = DateTime.now();
  final day = DateTime(dt.year, dt.month, dt.day);
  final today = DateTime(now.year, now.month, now.day);
  switch (today.difference(day).inDays) {
    case 0:
      return 'Today';
    case 1:
      return 'Yesterday';
    default:
      return '${_months[dt.month - 1]} ${dt.day}';
  }
}

/// Assumes [notifs] already arrives newest-first from the backend.
List<_FeedEntry> _groupByDay(List<AppNotification> notifs) {
  final entries = <_FeedEntry>[];
  String? lastLabel;
  for (final n in notifs) {
    final label = _dayLabel(n.createdAt);
    if (label != lastLabel) {
      entries.add(_FeedEntry.header(label));
      lastLabel = label;
    }
    entries.add(_FeedEntry.item(n));
  }
  return entries;
}

class _EmptyNotifications extends ConsumerWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              'No news yet — go find a swap!',
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            const SizedBox(height: Insets.lg),
            FilledButton(
              onPressed: () {
                ref.read(appTabIndexProvider.notifier).state = 0;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Browse Discovery'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveBackground extends StatelessWidget {
  const _ArchiveBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.archive_outlined, color: scheme.onSurfaceVariant),
    );
  }
}

class _NotifRow extends ConsumerWidget {
  const _NotifRow({required this.notif});
  final AppNotification notif;

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    if (!notif.read) {
      try {
        await ref.read(notificationRepositoryProvider).markRead(notif.id);
      } on ApiException {
        // best-effort
      }
      ref.invalidate(notificationsProvider);
    }
    if (!context.mounted) return;
    await handleNotificationTap(
      context,
      ref,
      type: notif.type,
      data: notif.data,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final unread = !notif.read;
    final style = styleForType(notif.type);
    return GestureDetector(
      onTap: () => _onTap(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: unread
              ? AppColors.primary.withValues(alpha: 0.04)
              : scheme.surface,
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed-width unread-dot gutter so icons stay aligned across
            // read and unread rows alike.
            SizedBox(
              width: 14,
              child: unread
                  ? const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: _UnreadDot(),
                    )
                  : null,
            ),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: style.accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(style.icon, color: style.iconColor, size: 20),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Text(
                        notif.relativeTime,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (notif.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      notif.body,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}
