import 'package:flutter/material.dart';

import '../../app/app_shell.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/sub_page.dart';
import '../../design_system/widgets/swappa_logo.dart';
import 'forgot_password_screen.dart';
import 'onboarding_screen.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _enterApp(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (_) => false,
    );
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
              Text('Welcome back', style: text.headlineMedium?.copyWith(fontSize: 30)),
              const SizedBox(height: 2),
              Text('Log in to continue swapping skills.',
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: Insets.xl),
              GoogleButton(label: 'Continue with Google', onTap: () => _enterApp(context)),
              const SizedBox(height: Insets.lg),
              const AuthDivider(),
              const SizedBox(height: Insets.lg),
              const FieldGroup(label: 'Email or phone', child: FilledField(hint: 'you@example.com or +44 7700…')),
              const SizedBox(height: Insets.md),
              const FieldGroup(label: 'Password', child: FilledField(obscure: true, hint: '••••••••')),
              const SizedBox(height: Insets.sm),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                  ),
                  child: Text('Forgot password?',
                      style: text.labelMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: Insets.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => _enterApp(context), child: const Text('Log in')),
              ),
              const SizedBox(height: Insets.lg),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?",
                        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                      ),
                      child: Text('Sign up',
                          style: text.bodyMedium?.copyWith(
                              color: AppColors.primary, fontWeight: FontWeight.w700)),
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
