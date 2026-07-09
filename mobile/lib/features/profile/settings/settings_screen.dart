import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/theme_provider.dart';
import '../../../design_system/app_colors.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/sub_page.dart';
import '../../auth/auth_controller.dart';
import '../../notifications/push_repository.dart';
import '../../support/support_repository.dart';
import '../location/location_picker_screen.dart';
import 'settings_pages.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifs = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }

  // The switch is its own on/off preference — not a direct mirror of the OS
  // authorization status, since that can only ever be granted or denied,
  // never freely flipped back and forth the way a toggle needs to be. An
  // explicit prior choice (stored) wins; otherwise it starts from whatever
  // the OS already reports (e.g. granted via the earlier priming screen).
  Future<void> _loadNotificationStatus() async {
    final store = ref.read(notificationPermissionStoreProvider);
    final pref = await store.enabledPreference;
    if (pref != null) {
      if (!mounted) return;
      setState(() => _notifs = pref);
      return;
    }
    final settings = await ref.read(pushRepositoryProvider).permissionStatus();
    if (!mounted) return;
    setState(() {
      _notifs =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    });
  }

  // Turning on only needs a real OS ask when permission isn't already
  // granted — and if the user hasn't granted it yet (or denied it before),
  // every attempt to switch on retries the ask, since there's no other way
  // in-app to know the moment they finally allow it from Settings.
  Future<void> _toggleNotifications(bool wantOn) async {
    final store = ref.read(notificationPermissionStoreProvider);
    if (!wantOn) {
      await store.setEnabled(false);
      if (!mounted) return;
      setState(() => _notifs = false);
      return;
    }

    final repo = ref.read(pushRepositoryProvider);
    final current = await repo.permissionStatus();
    var granted =
        current.authorizationStatus == AuthorizationStatus.authorized ||
        current.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) {
      final result = await repo.requestPermission();
      granted =
          result.authorizationStatus == AuthorizationStatus.authorized ||
          result.authorizationStatus == AuthorizationStatus.provisional;
    }
    if (granted) await repo.registerToken();
    await store.setEnabled(granted);
    if (!mounted) return;
    setState(() => _notifs = granted);
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'SWAPPA needs notification permission — allow it when asked, or enable it from your device Settings.',
          ),
        ),
      );
    }
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  /// Goes straight to every admin in real time, mirroring how a proposed
  /// skill notifies admins for approval.
  Future<void> _reportBug(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final description = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.xl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: const Text('Report a bug'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'What went wrong?'),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, controller.text.trim()),
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (description == null || description.isEmpty || !context.mounted) {
      return;
    }
    try {
      await ref.read(supportRepositoryProvider).submitBugReport(description);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks — we’ll take a look')),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Insets.lg),
                children: [
                  SettingsCard(
                    title: 'Appearance',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: Insets.md),
                            Row(
                              children: [
                                _themeOption(
                                  ThemeMode.light,
                                  Icons.light_mode_rounded,
                                  'Light',
                                  mode,
                                ),
                                const SizedBox(width: Insets.sm),
                                _themeOption(
                                  ThemeMode.dark,
                                  Icons.dark_mode_rounded,
                                  'Dark',
                                  mode,
                                ),
                                const SizedBox(width: Insets.sm),
                                _themeOption(
                                  ThemeMode.system,
                                  Icons.desktop_windows_rounded,
                                  'System',
                                  mode,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  SettingsCard(
                    title: 'Account',
                    children: [
                      SettingsNavRow(
                        label: 'Edit profile',
                        onTap: () => _push(const EditProfilePage()),
                      ),
                      SettingsNavRow(
                        label: 'Email & phone',
                        onTap: () => _push(const EmailPhonePage()),
                      ),
                      SettingsNavRow(
                        label: 'Change password',
                        showDivider: false,
                        onTap: () => _push(const ChangePasswordPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  SettingsCard(
                    title: 'Privacy & Location',
                    children: [
                      SettingsNavRow(
                        label: 'Your location',
                        trailing:
                            ref
                                .watch(authControllerProvider)
                                .user
                                ?.location
                                .displayName ??
                            'Remote',
                        onTap: () => _push(const LocationPickerScreen()),
                      ),
                      _toggleRow(
                        title: 'Notifications',
                        value: _notifs,
                        onChanged: _toggleNotifications,
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  SettingsCard(
                    title: 'Safety & Support',
                    children: [
                      SettingsNavRow(
                        label: 'Blocked users',
                        onTap: () => _push(const BlockedUsersPage()),
                      ),
                      SettingsNavRow(
                        label: 'Report history',
                        onTap: () => _push(const ReportHistoryPage()),
                      ),
                      SettingsNavRow(
                        label: 'Report a bug',
                        showDivider: false,
                        onTap: () => _reportBug(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  SettingsCard(
                    title: 'Subscription',
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.lg,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current plan',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    'Free',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: () => _push(const PlanUpgradePage()),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 34),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(Radii.sm),
                                ),
                              ),
                              child: const Text('Upgrade'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      }
                    },
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 16,
                      color: AppColors.destructive,
                    ),
                    label: const Text(
                      'Sign out',
                      style: TextStyle(color: AppColors.destructive),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: BorderSide(
                        color: AppColors.destructive.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  _DangerZoneCard(onDelete: _confirmDeleteAccount),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final user = ref.read(authControllerProvider).user;
    final target = (user?.email?.isNotEmpty ?? false)
        ? user!.email!
        : (user?.phone ?? '');
    if (target.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteAccountDialog(target: target),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Couldn’t delete account: $e')));
      }
    }
  }

  Widget _themeOption(
    ThemeMode m,
    IconData icon,
    String label,
    ThemeMode current,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final active = m == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(themeModeProvider.notifier).state = m,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: active ? AppColors.primary : scheme.outlineVariant,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? AppColors.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: active ? AppColors.primary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// Bordered "Danger zone" card — matches the design reference's delete-account
/// section (warning-tinted header strip + row with a delete pill button).
class _DangerZoneCard extends StatelessWidget {
  const _DangerZoneCard({required this.onDelete});
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: AppColors.destructive.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.destructive.withValues(alpha: 0.04),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.destructive.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: AppColors.destructive,
                ),
                const SizedBox(width: 8),
                Text(
                  'Danger zone',
                  style: text.labelMedium?.copyWith(
                    color: AppColors.destructive,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete account',
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Permanently remove your account and all data',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.sm),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 14,
                    color: AppColors.destructive,
                  ),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.destructive,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: BorderSide(
                      color: AppColors.destructive.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmation modal — the user must type their registered email/phone
/// (rather than a generic "DELETE") to enable the destructive action.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.target});
  final String target;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _input = TextEditingController();

  bool get _matches =>
      _input.text.trim().toLowerCase() == widget.target.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: scheme.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Insets.xl,
        vertical: Insets.xl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.xl,
          Insets.lg,
          Insets.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 26,
                color: AppColors.destructive,
              ),
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Delete your account?',
              style: text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(
                    text:
                        'This will permanently delete your profile, swaps, messages, and credits. ',
                  ),
                  TextSpan(
                    text: 'This cannot be undone.',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  children: [
                    const TextSpan(text: 'TYPE '),
                    TextSpan(
                      text: widget.target,
                      style: TextStyle(color: scheme.onSurface),
                    ),
                    const TextSpan(text: ' TO CONFIRM'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            FilledField(
              controller: _input,
              hint: widget.target,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _matches
                        ? () => Navigator.pop(context, true)
                        : null,
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
      ),
    );
  }
}
