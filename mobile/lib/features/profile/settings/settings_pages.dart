import 'package:flutter/material.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/avatar.dart';
import '../../../design_system/widgets/sub_page.dart';

// ── Edit Profile ─────────────────────────────────────────────────────────────
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _name = TextEditingController(text: 'Jordan Kim');
  final _bio = TextEditingController(
      text: 'Musician & photographer looking to expand horizons. Love learning something genuinely new each week!');
  final _location = TextEditingController(text: 'London, UK');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PageScaffold(
      title: 'Edit Profile',
      children: [
        Center(
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(Radii.xl),
                    ),
                    child: const Text('J',
                        style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                      child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Text('Tap to change photo',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),
        FieldGroup(label: 'Display name', child: FilledField(controller: _name, hint: 'Your name')),
        const SizedBox(height: Insets.lg),
        FieldGroup(label: 'Bio', child: FilledField(controller: _bio, maxLines: 4, hint: 'A few words about you…')),
        const SizedBox(height: Insets.lg),
        FieldGroup(label: 'General location', child: FilledField(controller: _location, hint: 'City, Country')),
        const SizedBox(height: Insets.xl),
        const SaveButton(),
      ],
    );
  }
}

// ── Email & Phone ────────────────────────────────────────────────────────────
class EmailPhonePage extends StatelessWidget {
  const EmailPhonePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _PageScaffold(
      title: 'Email & Phone',
      children: [
        FieldGroup(
          label: 'Email address',
          child: FilledField(
            controller: TextEditingController(text: 'jordan.kim@example.com'),
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        const SizedBox(height: Insets.sm),
        Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
            const SizedBox(width: 6),
            Text('Email verified', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: Insets.lg),
        FieldGroup(
          label: 'Phone number',
          child: FilledField(
            controller: TextEditingController(text: '+44 7700 900123'),
            keyboardType: TextInputType.phone,
          ),
        ),
        const SizedBox(height: Insets.sm),
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.onSurfaceVariant, width: 2),
              ),
            ),
            const SizedBox(width: 6),
            Text('Phone not verified', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const Spacer(),
            Text('Send code',
                style: text.labelMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: Insets.xl),
        const SaveButton(),
      ],
    );
  }
}

// ── Change Password (with strength meter) ────────────────────────────────────
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String _nextVal = '';
  String _confirmVal = '';

  int _strength(String pw) {
    if (pw.isEmpty) return 0;
    var s = 0;
    if (pw.length >= 8) s++;
    if (pw.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) s++;
    if (RegExp(r'[0-9]').hasMatch(pw)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final s = _strength(_nextVal);
    final color = switch (s) {
      <= 1 => const Color(0xFFEF4444),
      2 => const Color(0xFFF97316),
      3 => const Color(0xFFEAB308),
      4 => const Color(0xFF22C55E),
      _ => AppColors.success,
    };
    final mismatch = _confirmVal.isNotEmpty && _nextVal.isNotEmpty && _confirmVal != _nextVal;

    return _PageScaffold(
      title: 'Change Password',
      children: [
        const FieldGroup(label: 'Current password', child: FilledField(obscure: true, hint: '••••••••')),
        const SizedBox(height: Insets.lg),
        FieldGroup(
          label: 'New password',
          child: Column(
            children: [
              FilledField(
                controller: _next,
                obscure: true,
                hint: '••••••••',
                onChanged: (v) => setState(() => _nextVal = v),
              ),
              const SizedBox(height: Insets.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: LinearProgressIndicator(
                  value: s / 5,
                  minHeight: 6,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        FieldGroup(
          label: 'Confirm new password',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledField(
                controller: _confirm,
                obscure: true,
                hint: '••••••••',
                onChanged: (v) => setState(() => _confirmVal = v),
              ),
              if (mismatch)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text("Passwords don't match",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.destructive)),
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),
        const SaveButton(label: 'Update password'),
      ],
    );
  }
}

// ── Plan Upgrade ─────────────────────────────────────────────────────────────
class PlanUpgradePage extends StatelessWidget {
  const PlanUpgradePage({super.key});

  static const _features = <(IconData, String)>[
    (Icons.verified_rounded, 'Unlimited match results'),
    (Icons.place_rounded, 'Wider & unlimited radius'),
    (Icons.repeat_rounded, 'Up to 10 active swaps'),
    (Icons.chat_bubble_rounded, 'Multimedia chat — photos & audio'),
    (Icons.star_rounded, 'Up to 8 skill tags'),
    (Icons.monetization_on_rounded, '30 Basic credits per week'),
    (Icons.local_fire_department_rounded, 'Feed boost visibility'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _PageScaffold(
      title: 'Upgrade Plan',
      children: [
        Container(
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT PLAN',
                        style: text.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    Text('Free', style: text.titleMedium),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Text('Active',
                    style: text.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, Color(0xFF5A2EE5)],
            ),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PREMIUM',
                  style: text.labelSmall?.copyWith(
                      color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text('£7.99', style: AppTypography.tabular(size: 30, color: Colors.white)),
              Text('per month · cancel anytime',
                  style: text.bodySmall?.copyWith(color: Colors.white70)),
              const SizedBox(height: Insets.lg),
              for (final f in _features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(f.$1, size: 15, color: Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(f.$2, style: text.bodyMedium?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Insets.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Text('Start Premium'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        Center(
          child: Text('Restore purchase',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

// ── Blocked Users ────────────────────────────────────────────────────────────
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});
  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final _list = <(String, String)>[('Tom X.', 'Blocked 12 Jun'), ('Alex R.', 'Blocked 3 May')];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _PageScaffold(
      title: 'Blocked Users',
      children: [
        if (_list.isEmpty)
          _empty(context, Icons.shield_rounded, 'No blocked users')
        else
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _list.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 12),
                    child: Row(
                      children: [
                        Avatar(
                            initials: _list[i].$1.split(' ').map((w) => w[0]).take(2).join(),
                            color: avatarColorFor(_list[i].$1),
                            size: 36),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_list[i].$1,
                                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              Text(_list[i].$2,
                                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => setState(() => _list.removeAt(i)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            side: BorderSide(color: scheme.outlineVariant),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
                          ),
                          child: Text('Unblock',
                              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                      ],
                    ),
                  ),
                  if (i < _list.length - 1)
                    Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ── Report History ───────────────────────────────────────────────────────────
class ReportHistoryPage extends StatelessWidget {
  const ReportHistoryPage({super.key});

  static const _reports = <(String, String, String, String)>[
    ('Tom X.', 'Inappropriate messages', '12 Jun 2026', 'resolved'),
    ('Unknown User', 'Fake skill listing', '3 May 2026', 'under review'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _PageScaffold(
      title: 'Report History',
      children: [
        for (final r in _reports) ...[
          Container(
            padding: const EdgeInsets.all(Insets.lg),
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
                    Avatar(
                        initials: r.$1.split(' ').map((w) => w[0]).take(2).join(),
                        color: avatarColorFor(r.$1),
                        size: 36),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.$1, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          Text(r.$3, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    _reportStatus(context, r.$4),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                Text(r.$2, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),
        ],
      ],
    );
  }

  Widget _reportStatus(BuildContext context, String status) {
    final resolved = status == 'resolved';
    final bg = resolved ? AppColors.offerBg : const Color(0xFFFEF3C7);
    final fg = resolved ? AppColors.offerFg : const Color(0xFF92400E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Text(status,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Shared page scaffold ─────────────────────────────────────────────────────
class _PageScaffold extends StatelessWidget {
  const _PageScaffold({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SubPageHeader(title: title),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Insets.lg),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _empty(BuildContext context, IconData icon, String label) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(top: 80),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: Insets.sm),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    ),
  );
}
