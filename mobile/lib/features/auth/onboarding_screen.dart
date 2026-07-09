import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/sub_page.dart';
import '../../design_system/widgets/swappa_logo.dart';
import 'auth_controller.dart';
import 'verify_email_screen.dart';
import 'widgets/auth_widgets.dart';

/// Sign-up: create an account, then verify the emailed code. Profile & skill
/// setup happens afterwards in the Profile tab (wired in the Profile phase).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _pw = '';
  bool _busy = false;
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _generalError;

  Future<void> _createAccount() async {
    setState(() {
      _busy = true;
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });
    try {
      final email = await ref
          .read(authControllerProvider.notifier)
          .register(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _name.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email)),
        );
      }
    } on ApiException catch (e) {
      final nameMsg = e.messageForField('displayName');
      final emailMsg = e.messageForField('email');
      final passwordMsg = e.messageForField('password');
      setState(() {
        _nameError = nameMsg;
        _emailError = emailMsg;
        _passwordError = passwordMsg;
        _generalError =
            (nameMsg == null && emailMsg == null && passwordMsg == null)
            ? e.message
            : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, Insets.md, 24, Insets.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SwappaWordmark(iconSize: 36),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Log in',
                      style: text.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xl),
              Text('Create your account', style: text.headlineMedium),
              const SizedBox(height: 2),
              Text(
                'Trade skills directly — teach one, learn one.',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Insets.xl),
              const GoogleButton(label: 'Sign up with Google'),
              const SizedBox(height: Insets.lg),
              const AuthDivider(),
              const SizedBox(height: Insets.lg),
              FieldGroup(
                label: 'Display name',
                child: FilledField(
                  controller: _name,
                  hint: 'Please enter your display name',
                  errorText: _nameError,
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
              ),
              const SizedBox(height: Insets.md),
              FieldGroup(
                label: 'Email',
                child: FilledField(
                  controller: _email,
                  hint: 'Please enter your email',
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                  onChanged: (_) {
                    if (_emailError != null) setState(() => _emailError = null);
                  },
                ),
              ),
              const SizedBox(height: Insets.md),
              FieldGroup(
                label: 'Password',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledField(
                      controller: _password,
                      obscure: true,
                      hint: '••••••••',
                      errorText: _passwordError,
                      onChanged: (v) => setState(() {
                        _pw = v;
                        if (_passwordError != null) _passwordError = null;
                      }),
                    ),
                    PasswordStrengthMeter(password: _pw),
                  ],
                ),
              ),
              const SizedBox(height: Insets.lg),
              // Welcome bonus banner
              Container(
                padding: const EdgeInsets.all(Insets.lg),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.card_giftcard_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Free credits to start',
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'One-time welcome bonus — try an AI action right away.',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_generalError != null) ...[
                const SizedBox(height: Insets.md),
                Text(
                  _generalError!,
                  style: text.bodySmall?.copyWith(color: AppColors.destructive),
                ),
              ],
              const SizedBox(height: Insets.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _createAccount,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
