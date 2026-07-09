import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../design_system/app_colors.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets/sub_page.dart';
import 'auth_controller.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});
  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyEmail(email: widget.email, code: _code.text.trim());
      // Session is now authenticated — return to root so the gate shows the app.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).resendCode(widget.email);
      setState(() => _info = 'A new code has been sent.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
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
              const SizedBox(height: Insets.xl),
              Text('Verify your email', style: text.headlineMedium),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  children: [
                    const TextSpan(text: 'Enter the 6-digit code we sent to '),
                    TextSpan(
                      text: widget.email,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: Insets.xl),
              FieldGroup(
                label: 'Verification code',
                child: FilledField(
                  controller: _code,
                  hint: '123456',
                  keyboardType: TextInputType.number,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  _error!,
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
              const SizedBox(height: Insets.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _verify,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verify & continue'),
                ),
              ),
              const SizedBox(height: Insets.md),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _resend,
                  child: Text(
                    'Resend code',
                    style: text.labelLarge?.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
