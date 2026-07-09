import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/sub_page.dart';
import '../../design_system/widgets/swappa_logo.dart';
import 'auth_controller.dart';
import 'forgot_password_screen.dart';
import 'onboarding_screen.dart';
import 'verify_email_screen.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _contact = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _contactError;
  String? _passwordError;
  String? _generalError;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _contactError = null;
      _passwordError = null;
      _generalError = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(emailOrPhone: _contact.text.trim(), password: _password.text);
      // The auth gate swaps to the app automatically.
    } on ApiException catch (e) {
      if (e.code == 'EMAIL_NOT_VERIFIED') {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VerifyEmailScreen(email: _contact.text.trim()),
            ),
          );
        }
        return;
      }
      final contactMsg = e.messageForField('emailOrPhone');
      final passwordMsg = e.messageForField('password');
      setState(() {
        _contactError = contactMsg;
        _passwordError = passwordMsg;
        _generalError = (contactMsg == null && passwordMsg == null)
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, Insets.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SwappaWordmark(iconSize: 36),
              const SizedBox(height: Insets.xxl),
              Text(
                'Welcome back',
                style: text.headlineMedium?.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 2),
              Text(
                'Log in to continue swapping skills.',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Insets.xl),
              const GoogleButton(label: 'Continue with Google'),
              const SizedBox(height: Insets.lg),
              const AuthDivider(),
              const SizedBox(height: Insets.lg),
              FieldGroup(
                label: 'Email or phone',
                child: FilledField(
                  controller: _contact,
                  hint: 'Please enter your email or phone numbers',
                  errorText: _contactError,
                  onChanged: (_) {
                    if (_contactError != null) {
                      setState(() => _contactError = null);
                    }
                  },
                ),
              ),
              const SizedBox(height: Insets.md),
              FieldGroup(
                label: 'Password',
                child: FilledField(
                  controller: _password,
                  obscure: true,
                  hint: '••••••••',
                  errorText: _passwordError,
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                ),
              ),
              if (_generalError != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  _generalError!,
                  style: text.bodySmall?.copyWith(color: AppColors.destructive),
                ),
              ],
              const SizedBox(height: Insets.sm),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  ),
                  child: Text(
                    'Forgot password?',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Insets.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _login,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Log in'),
                ),
              ),
              const SizedBox(height: Insets.lg),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingScreen(),
                        ),
                      ),
                      child: Text(
                        'Sign up',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
