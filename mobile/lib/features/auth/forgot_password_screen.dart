import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/sub_page.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _contact = TextEditingController();
  bool _sent = false;

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
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back_rounded, size: 18, color: scheme.onSurface),
                ),
              ),
              const SizedBox(height: Insets.xl),
              Text('Reset password', style: text.headlineMedium),
              const SizedBox(height: 4),
              Text("Enter your email or phone number and we'll send you a reset link.",
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: Insets.xl),
              if (!_sent) ...[
                FieldGroup(
                  label: 'Email or phone',
                  child: FilledField(controller: _contact, hint: 'you@example.com or +44 7700…'),
                ),
                const SizedBox(height: Insets.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (_contact.text.trim().isNotEmpty) setState(() => _sent = true);
                    },
                    child: const Text('Send reset link'),
                  ),
                ),
              ] else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded, size: 24, color: AppColors.primary),
                      ),
                      const SizedBox(height: Insets.md),
                      Text('Check your inbox', style: text.titleMedium),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          children: [
                            const TextSpan(text: "We've sent a reset link to "),
                            TextSpan(
                              text: _contact.text,
                              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Insets.lg),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text('Back to login',
                            style: text.labelLarge?.copyWith(color: AppColors.primary)),
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
