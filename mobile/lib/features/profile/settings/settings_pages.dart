import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../design_system/app_colors.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/avatar.dart';
import '../../../design_system/widgets/avatar_picker.dart';
import '../../../design_system/widgets/sub_page.dart';
import '../../auth/auth_controller.dart';
import '../../safety/safety_repository.dart';
import '../profile_providers.dart';

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

String _shortDate(DateTime? d) {
  if (d == null) return '';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

// ── Edit Profile ─────────────────────────────────────────────────────────────
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});
  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late final _name = TextEditingController(text: _user?.displayName ?? '');
  late final _bio = TextEditingController(text: _user?.bio ?? '');
  bool _busy = false;
  String? _error;

  dynamic get _user => ref.read(authControllerProvider).user;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(displayName: _name.text.trim(), bio: _bio.text.trim());
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'Edit Profile',
      children: [
        const Center(child: AvatarPicker(size: 80)),
        const SizedBox(height: Insets.xl),
        FieldGroup(
          label: 'Display name',
          child: FilledField(controller: _name, hint: 'Your name'),
        ),
        const SizedBox(height: Insets.lg),
        FieldGroup(
          label: 'Bio',
          child: FilledField(
            controller: _bio,
            maxLines: 4,
            hint: 'A few words about you…',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Insets.md),
          Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.destructive),
          ),
        ],
        const SizedBox(height: Insets.xl),
        SaveButton(onPressed: _busy ? null : _save),
      ],
    );
  }
}

// ── Email & Phone ────────────────────────────────────────────────────────────
class EmailPhonePage extends ConsumerStatefulWidget {
  const EmailPhonePage({super.key});
  @override
  ConsumerState<EmailPhonePage> createState() => _EmailPhonePageState();
}

class _EmailPhonePageState extends ConsumerState<EmailPhonePage> {
  dynamic get _user => ref.read(authControllerProvider).user;

  late final _email = TextEditingController(text: _user?.email ?? '');
  late final _phone = TextEditingController(text: _user?.phone ?? '');
  final _code = TextEditingController();

  String? _pendingEmail; // set once a code has been sent to a new address
  bool _emailBusy = false;
  bool _phoneBusy = false;
  String? _emailError;
  String? _phoneError;
  String? _info;

  Future<void> _updateEmail() async {
    final next = _email.text.trim();
    setState(() {
      _emailBusy = true;
      _emailError = null;
      _info = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateEmail(next);
      setState(() => _pendingEmail = next);
    } on ApiException catch (e) {
      setState(() => _emailError = e.messageForField('email') ?? e.message);
    } finally {
      if (mounted) setState(() => _emailBusy = false);
    }
  }

  Future<void> _confirmEmailCode() async {
    setState(() {
      _emailBusy = true;
      _emailError = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyEmail(email: _pendingEmail!, code: _code.text.trim());
      setState(() {
        _pendingEmail = null;
        _code.clear();
        _info = 'Email updated and verified.';
      });
    } on ApiException catch (e) {
      setState(() => _emailError = e.message);
    } finally {
      if (mounted) setState(() => _emailBusy = false);
    }
  }

  Future<void> _resendEmailCode() async {
    setState(() => _emailError = null);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resendCode(_pendingEmail!);
      setState(() => _info = 'A new code has been sent.');
    } on ApiException catch (e) {
      setState(() => _emailError = e.message);
    }
  }

  Future<void> _updatePhone() async {
    setState(() {
      _phoneBusy = true;
      _phoneError = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(phone: _phone.text.trim());
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Phone number updated')));
      }
    } on ApiException catch (e) {
      setState(() => _phoneError = e.messageForField('phone') ?? e.message);
    } finally {
      if (mounted) setState(() => _phoneBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final verified =
        ref.watch(authControllerProvider).user?.emailVerified ?? false;

    return _PageScaffold(
      title: 'Email & Phone',
      children: [
        FieldGroup(
          label: 'Email address',
          child: FilledField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        const SizedBox(height: Insets.sm),
        Row(
          children: [
            Icon(
              verified
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              size: 14,
              color: verified ? AppColors.success : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              verified ? 'Email verified' : 'Email not verified',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            TextButton(
              onPressed: _emailBusy || _email.text.trim().isEmpty
                  ? null
                  : _updateEmail,
              child: Text(
                'Update email',
                style: text.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (_pendingEmail != null) ...[
          const SizedBox(height: Insets.md),
          FieldGroup(
            label: 'Verification code',
            child: FilledField(
              controller: _code,
              hint: 'Code sent to $_pendingEmail',
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              TextButton(
                onPressed: _emailBusy ? null : _confirmEmailCode,
                child: const Text('Confirm code'),
              ),
              TextButton(
                onPressed: _emailBusy ? null : _resendEmailCode,
                child: const Text('Resend'),
              ),
            ],
          ),
        ],
        if (_emailError != null) ...[
          const SizedBox(height: Insets.sm),
          Text(
            _emailError!,
            style: text.bodySmall?.copyWith(color: AppColors.destructive),
          ),
        ],
        if (_info != null) ...[
          const SizedBox(height: Insets.sm),
          Text(
            _info!,
            style: text.bodySmall?.copyWith(color: AppColors.success),
          ),
        ],
        const SizedBox(height: Insets.lg),
        FieldGroup(
          label: 'Phone number',
          child: FilledField(
            controller: _phone,
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
            Text(
              'Phone not verified',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            Text(
              'Verification coming soon',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        if (_phoneError != null) ...[
          const SizedBox(height: Insets.sm),
          Text(
            _phoneError!,
            style: text.bodySmall?.copyWith(color: AppColors.destructive),
          ),
        ],
        const SizedBox(height: Insets.xl),
        SaveButton(
          label: 'Save phone number',
          onPressed: _phoneBusy ? null : _updatePhone,
        ),
      ],
    );
  }
}

// ── Change Password (with strength meter) ────────────────────────────────────
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});
  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String _nextVal = '';
  String _confirmVal = '';
  bool _busy = false;
  String? _error;

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

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password updated')));
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final mismatch =
        _confirmVal.isNotEmpty &&
        _nextVal.isNotEmpty &&
        _confirmVal != _nextVal;
    final canSave =
        !_busy &&
        _current.text.isNotEmpty &&
        _nextVal.isNotEmpty &&
        _confirmVal == _nextVal;

    return _PageScaffold(
      title: 'Change Password',
      children: [
        FieldGroup(
          label: 'Current password',
          child: FilledField(
            controller: _current,
            obscure: true,
            hint: '••••••••',
            onChanged: (_) => setState(() {}),
          ),
        ),
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
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
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
                  child: Text(
                    "Passwords don't match",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.destructive,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Insets.md),
          Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.destructive),
          ),
        ],
        const SizedBox(height: Insets.xl),
        SaveButton(label: 'Update password', onPressed: canSave ? _save : null),
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
                    Text(
                      'CURRENT PLAN',
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text('Free', style: text.titleMedium),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Text(
                  'Active',
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
              Text(
                'PREMIUM',
                style: text.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '£7.99',
                style: AppTypography.tabular(size: 30, color: Colors.white),
              ),
              Text(
                'per month · cancel anytime',
                style: text.bodySmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: Insets.lg),
              for (final f in _features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(f.$1, size: 15, color: Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f.$2,
                          style: text.bodyMedium?.copyWith(color: Colors.white),
                        ),
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
          child: Text(
            'Restore purchase',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

// ── Blocked Users ────────────────────────────────────────────────────────────
class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedUsersProvider);
    return _PageScaffold(
      title: 'Blocked Users',
      children: [
        blockedAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Center(
              child: Text(
                'Couldn’t load blocked users',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          data: (blocked) {
            if (blocked.isEmpty) {
              return _empty(context, Icons.shield_rounded, 'No blocked users');
            }
            final scheme = Theme.of(context).colorScheme;
            return Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < blocked.length; i++) ...[
                    _BlockedUserRow(user: blocked[i]),
                    if (i < blocked.length - 1)
                      Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BlockedUserRow extends ConsumerWidget {
  const _BlockedUserRow({required this.user});
  final BlockedUser user;

  Future<void> _confirmUnblock(BuildContext context, WidgetRef ref) async {
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
        title: Text('Unblock ${user.name}?'),
        content: const Text(
          'You’ll be able to see each other in Discovery and message each other again.',
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
                  child: const Text('Unblock'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(safetyRepositoryProvider).unblock(user.targetUserId);
      ref.invalidate(blockedUsersProvider);
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 12),
      child: Row(
        children: [
          Avatar(
            initials: user.name.split(' ').map((w) => w[0]).take(2).join(),
            color: avatarColorFor(user.name),
            photoUrl: user.photoUrl,
            size: 36,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Blocked ${_shortDate(user.blockedAt)}',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _confirmUnblock(context, ref),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(color: scheme.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
            ),
            child: Text(
              'Unblock',
              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Report History ───────────────────────────────────────────────────────────
class ReportHistoryPage extends ConsumerWidget {
  const ReportHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(myReportsProvider);
    return _PageScaffold(
      title: 'Report History',
      children: [
        reportsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Center(
              child: Text(
                'Couldn’t load report history',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          data: (reports) {
            if (reports.isEmpty) {
              return _empty(context, Icons.flag_outlined, 'No reports filed');
            }
            final scheme = Theme.of(context).colorScheme;
            final text = Theme.of(context).textTheme;
            return Column(
              children: [
                for (final r in reports) ...[
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
                              initials: r.targetName
                                  .split(' ')
                                  .map((w) => w[0])
                                  .take(2)
                                  .join(),
                              color: avatarColorFor(r.targetName),
                              photoUrl: r.targetPhotoUrl,
                              size: 36,
                            ),
                            const SizedBox(width: Insets.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.targetName,
                                    style: text.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _shortDate(r.createdAt),
                                    style: text.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _reportStatus(context, r.status),
                          ],
                        ),
                        if (r.reason != null && r.reason!.isNotEmpty) ...[
                          const SizedBox(height: Insets.sm),
                          Text(
                            r.reason!,
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (r.resolutionNote != null &&
                            r.resolutionNote!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Note: ${r.resolutionNote}',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _reportStatus(BuildContext context, String status) {
    final (label, resolved) = switch (status) {
      'resolved' => ('Resolved', true),
      'dismissed' => ('Dismissed', true),
      'reviewing' => ('Reviewing', false),
      _ => ('Open', false),
    };
    final bg = resolved ? AppColors.offerBg : const Color(0xFFFEF3C7);
    final fg = resolved ? AppColors.offerFg : const Color(0xFF92400E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
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
          Icon(
            icon,
            size: 32,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    ),
  );
}
