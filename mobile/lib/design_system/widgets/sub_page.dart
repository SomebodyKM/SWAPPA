import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../tokens.dart';

/// Back-header used by sub-pages (Settings pages, etc.). Place at the top of a
/// Scaffold body.
class SubPageHeader extends StatelessWidget {
  const SubPageHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
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
          const SizedBox(width: Insets.md),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

/// Uppercase field label + child (form fields).
class FieldGroup extends StatelessWidget {
  const FieldGroup({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Filled form input matching the design's muted-background fields.
class FilledField extends StatelessWidget {
  const FilledField({
    super.key,
    this.controller,
    this.hint,
    this.obscure = false,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Full-width primary save/CTA button.
class SaveButton extends StatelessWidget {
  const SaveButton({super.key, this.label = 'Save changes', this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

/// Card wrapper with an optional title header and rows (Settings sections).
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text(title!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// A tappable settings row with a chevron.
class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({super.key, required this.label, this.onTap, this.showDivider = true});
  final String label;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 14),
            child: Row(
              children: [
                Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
                Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, indent: Insets.lg, color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ],
    );
  }
}
