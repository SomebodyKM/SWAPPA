import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/tokens.dart';

/// Google sign-in — disabled/"coming soon": the normal button is rendered
/// blurred and faded behind a centered lock + label overlay, non-interactive.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: Stack(
        children: [
          // Blurred, faded, un-tappable "real" button (fills the 50px height).
          Positioned.fill(
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Opacity(
                  opacity: 0.45,
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/images/gmail-icon.svg',
                          width: 18,
                          height: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: scheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // "Coming soon" overlay.
          Positioned.fill(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Coming soon',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: scheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Text(
            'or',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(child: Divider(color: scheme.outlineVariant)),
      ],
    );
  }
}

/// Password strength result (0–4) with a label and color, tuned to feel like
/// the backend's zxcvbn scoring (heuristic client-side estimate).
class PasswordStrength {
  const PasswordStrength(this.score, this.label, this.color);
  final int score; // 0..4
  final String label;
  final Color color;

  static PasswordStrength of(String pw) {
    if (pw.isEmpty) return const PasswordStrength(0, '', Color(0xFF9CA3AF));
    var s = 0;
    if (pw.length >= 8) s++;
    if (pw.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(pw) && RegExp(r'[a-z]').hasMatch(pw)) s++;
    if (RegExp(r'[0-9]').hasMatch(pw)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) s++;
    final score = s.clamp(0, 4);
    return switch (score) {
      <= 1 => const PasswordStrength(1, 'Weak', Color(0xFFEF4444)),
      2 => const PasswordStrength(2, 'Fair', Color(0xFFF59E0B)),
      3 => const PasswordStrength(3, 'Good', Color(0xFF22C55E)),
      _ => const PasswordStrength(4, 'Strong', AppColors.success),
    };
  }
}

/// A 4-segment strength meter + label shown under a password field.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (password.isEmpty) return const SizedBox.shrink();
    final s = PasswordStrength.of(password);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (var i = 1; i <= 4; i++) ...[
            Expanded(
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: i <= s.score
                      ? s.color
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
            if (i < 4) const SizedBox(width: 4),
          ],
          const SizedBox(width: Insets.sm),
          SizedBox(
            width: 44,
            child: Text(
              s.label,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: s.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
