import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../tokens.dart';

/// Pill tag for a skill. Two semantic variants matching the swap loop:
///  - [SkillTag.offer] (green) — "teaches …"
///  - [SkillTag.want]  (violet) — "wants …"
class SkillTag extends StatelessWidget {
  const SkillTag._({required this.label, required this.bg, required this.fg});

  /// [bare] drops the "teaches "/"wants " prefix — for use under a section
  /// header (e.g. a "Teach:" label) that already establishes the category.
  factory SkillTag.offer(String skill, {bool bare = false}) => SkillTag._(
    label: bare ? skill : 'teaches $skill',
    bg: AppColors.offerBg,
    fg: AppColors.offerFg,
  );

  factory SkillTag.want(String skill, {bool bare = false}) => SkillTag._(
    label: bare ? skill : 'wants $skill',
    bg: AppColors.wantBg,
    fg: AppColors.wantFg,
  );

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
