import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme_provider.dart';
import '../../../design_system/app_colors.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/sub_page.dart';
import 'settings_pages.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _precise = false;
  bool _notifs = true;

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

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
                            Text('Theme',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant)),
                            const SizedBox(height: Insets.md),
                            Row(
                              children: [
                                _themeOption(ThemeMode.light, Icons.light_mode_rounded, 'Light', mode),
                                const SizedBox(width: Insets.sm),
                                _themeOption(ThemeMode.dark, Icons.dark_mode_rounded, 'Dark', mode),
                                const SizedBox(width: Insets.sm),
                                _themeOption(ThemeMode.system, Icons.desktop_windows_rounded, 'System', mode),
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
                      SettingsNavRow(label: 'Edit profile', onTap: () => _push(const EditProfilePage())),
                      SettingsNavRow(label: 'Email & phone', onTap: () => _push(const EmailPhonePage())),
                      SettingsNavRow(
                          label: 'Change password',
                          showDivider: false,
                          onTap: () => _push(const ChangePasswordPage())),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  SettingsCard(
                    title: 'Privacy & Location',
                    children: [
                      _toggleRow(
                        title: 'Precise location',
                        subtitle: 'Off by default — general area is shared',
                        value: _precise,
                        onChanged: (v) => setState(() => _precise = v),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                      _toggleRow(
                        title: 'Notifications',
                        value: _notifs,
                        onChanged: (v) => setState(() => _notifs = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  SettingsCard(
                    title: 'Subscription',
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Current plan', style: Theme.of(context).textTheme.bodyMedium),
                                  Text('Free',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: () => _push(const PlanUpgradePage()),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 34),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(Radii.sm)),
                              ),
                              child: const Text('Upgrade'),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                      SettingsNavRow(label: 'Blocked users', onTap: () => _push(const BlockedUsersPage())),
                      SettingsNavRow(
                          label: 'Report history',
                          showDivider: false,
                          onTap: () => _push(const ReportHistoryPage())),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.destructive),
                    label: const Text('Sign out', style: TextStyle(color: AppColors.destructive)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: BorderSide(color: AppColors.destructive.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(ThemeMode m, IconData icon, String label, ThemeMode current) {
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
              Icon(icon, size: 18, color: active ? AppColors.primary : scheme.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: active ? AppColors.primary : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      )),
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
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: Colors.white, activeTrackColor: AppColors.primary),
        ],
      ),
    );
  }
}
