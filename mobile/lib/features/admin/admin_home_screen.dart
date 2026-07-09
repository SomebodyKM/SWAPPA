import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/providers.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/app_typography.dart';
import '../../design_system/tokens.dart';
import '../auth/auth_controller.dart';
import '../notifications/notification_navigation.dart';
import '../notifications/notification_presenter.dart';
import '../notifications/push_repository.dart';
import 'admin_audit_log_screen.dart';
import 'admin_bug_reports_screen.dart';
import 'admin_repository.dart';
import 'admin_reports_screen.dart';
import 'admin_skills_screen.dart';
import 'admin_users_screen.dart';

/// The whole app for an admin — `_AuthGate` routes here directly the moment
/// `user.isAdmin`, skipping onboarding/priming/the main tabs entirely (admins
/// don't swap skills). Since this is the session's root screen rather than
/// something pushed onto a stack, its header has no back button — sign-out
/// lives here instead, since Settings (where it'd normally be) is never
/// reached. The server independently enforces admin-only access on every
/// `/admin/*` call too (`adminGuard`), so this screen existing client-side
/// isn't the only thing stopping a non-admin from using it.
///
/// Also owns push notifications for the admin session — `_AppShellWithPush`
/// does the equivalent for regular users, but admins never reach that widget
/// at all, so registration/listening has to live here instead.
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  // Cached rather than read from `ref` in dispose() — Riverpod forbids
  // `ref.read`/`ref.watch` once a widget is being torn down.
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _connectRealtime();
    ref.read(pushRepositoryProvider).registerToken();

    // Tapped from the system tray while backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    // Tapped from a cold start (app was killed).
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleTap(message);
    });
    // The backend falls back to FCM push whenever it thinks the recipient is
    // offline — if that races with a reconnect and fires while still
    // foregrounded, FCM delivers it here instead of auto-showing anything.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  /// The live path — while the admin has the app open with a connected
  /// socket, the backend emits here directly rather than falling back to FCM.
  Future<void> _connectRealtime() async {
    final socket = await ref.read(socketClientProvider).ensureConnected();
    if (!mounted) return;
    _socket = socket;
    socket.on('notification', _onNotification);
  }

  void _onNotification(dynamic data) {
    if (data is! Map || !mounted) return;
    final rawData = data['data'];
    handleForegroundNotification(
      context,
      ref,
      type: data['type']?.toString() ?? '',
      title: data['title']?.toString(),
      body: data['body']?.toString(),
      data: rawData is Map ? rawData.cast<String, dynamic>() : const {},
    );
  }

  void _handleTap(RemoteMessage message) {
    handleNotificationTap(
      context,
      ref,
      type: message.data['type']?.toString() ?? '',
      data: message.data,
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    handleForegroundNotification(
      context,
      ref,
      type: message.data['type']?.toString() ?? '',
      title: message.notification?.title,
      body: message.notification?.body ?? message.data['body']?.toString(),
      data: message.data,
    );
  }

  @override
  void dispose() {
    _socket?.off('notification', _onNotification);
    super.dispose();
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
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
        title: const Text('Sign out?'),
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
                  child: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final metricsAsync = ref.watch(adminMetricsProvider);
    return Scaffold(
      body: SafeArea(
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
                  Text('Admin Panel', style: text.headlineSmall),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _confirmLogout(context, ref),
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
                        Icons.logout_rounded,
                        size: 17,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminMetricsProvider),
                child: ListView(
                  padding: const EdgeInsets.all(Insets.lg),
                  children: [
                    metricsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text(
                        'Couldn’t load metrics',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      data: (m) => _MetricsGrid(metrics: m),
                    ),
                    const SizedBox(height: Insets.lg),
                    _AdminNavCard(
                      icon: Icons.flag_outlined,
                      label: 'Reports',
                      desc: 'Review and resolve user reports',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminReportsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    _AdminNavCard(
                      icon: Icons.people_outline_rounded,
                      label: 'Users',
                      desc: 'Search, ban, suspend, or promote users',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminUsersScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    _AdminNavCard(
                      icon: Icons.school_outlined,
                      label: 'Skill Moderation',
                      desc: 'Approve, edit, or remove catalog skills',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminSkillsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    _AdminNavCard(
                      icon: Icons.bug_report_outlined,
                      label: 'Bug Reports',
                      desc: 'Review bugs users have flagged',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminBugReportsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    _AdminNavCard(
                      icon: Icons.history_rounded,
                      label: 'Audit Log',
                      desc: 'Every privileged action, who did it, and when',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminAuditLogScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});
  final AdminMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Users', metrics.users, Icons.people_alt_rounded),
      ('Active swaps', metrics.activeSwaps, Icons.repeat_rounded),
      ('Completed swaps', metrics.completedSwaps, Icons.check_circle_rounded),
      ('Premium', metrics.premium, Icons.diamond_rounded),
      ('AI spends', metrics.aiSpends, Icons.auto_awesome_rounded),
      ('Boost purchases', metrics.boostPurchases, Icons.shopping_bag_rounded),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Insets.md,
      crossAxisSpacing: Insets.md,
      childAspectRatio: 1.5,
      children: [
        for (final i in items)
          _MetricCard(label: i.$1, value: i.$2, icon: i.$3),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final int value;
  final IconData icon;

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          Text(
            '$value',
            style: AppTypography.tabular(size: 24, color: scheme.onSurface),
          ),
          Text(
            label,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AdminNavCard extends StatelessWidget {
  const _AdminNavCard({
    required this.icon,
    required this.label,
    required this.desc,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    desc,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
