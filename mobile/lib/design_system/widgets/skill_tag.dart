import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../tokens.dart';

/// Pill tag for a skill. Two semantic variants matching the swap loop:
///  - [SkillTag.offer] (green) — "teaches …"
///  - [SkillTag.want]  (violet) — "wants …"
class SkillTag extends StatelessWidget {
  const SkillTag._({required this.label, required this.bg, required this.fg});

  factory SkillTag.offer(String skill) =>
      SkillTag._(label: 'teaches $skill', bg: AppColors.offerBg, fg: AppColors.offerFg);

  factory SkillTag.want(String skill) =>
      SkillTag._(label: 'wants $skill', bg: AppColors.wantBg, fg: AppColors.wantFg);

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}
