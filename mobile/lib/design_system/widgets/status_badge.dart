import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../tokens.dart';

/// Small pill badge for a swap/session status (active / pending / completed /
/// cancelled), colored per the design.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _styleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  (Color, Color) _styleFor(String status) {
    switch (status) {
      case 'active':
        return (AppColors.offerBg, AppColors.offerFg); // emerald
      case 'pending':
        return (const Color(0xFFFEF3C7), const Color(0xFF92400E)); // amber
      case 'cancelled':
        return (const Color(0xFFFEF2F2), const Color(0xFFF87171)); // red
      case 'completed':
      default:
        return (const Color(0xFFF5F5F4), const Color(0xFF78716C)); // stone/gray
    }
  }
}
