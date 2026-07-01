import 'package:flutter/material.dart';

import '../../../design_system/tokens.dart';

/// "Continue/Sign up with Google" button (visual only for now).
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const _GoogleG(),
        label: Text(label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurface)),
        style: OutlinedButton.styleFrom(
          backgroundColor: scheme.surface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        ),
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) {
    // Simple multicolor "G" mark.
    return const SizedBox(
      width: 18,
      height: 18,
      child: Icon(Icons.g_mobiledata_rounded, size: 22, color: Color(0xFF4285F4)),
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
          child: Text('or',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ),
        Expanded(child: Divider(color: scheme.outlineVariant)),
      ],
    );
  }
}
