import 'package:flutter/material.dart';

import '../../design_system/tokens.dart';

/// Shared bottom-sheet chrome: rounded top corners, a drag handle, safe-area
/// padding, and scrollable content. Used by the AI / paywall / buy-boost sheets.
Future<T?> showAppSheet<T>(BuildContext context, {required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AppSheet(child: child),
  );
}

class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(top: Insets.md, bottom: Insets.sm),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, Insets.sm, 20, Insets.xl),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
