import 'package:flutter/material.dart';

/// Compact signal-style level indicator (beginner→expert = 1→4 bars),
/// used instead of a text label so skill pills stay narrow.
class ProficiencyBars extends StatelessWidget {
  const ProficiencyBars({
    super.key,
    required this.proficiency,
    required this.color,
  });

  final String? proficiency;
  final Color color;

  int get _level => switch (proficiency) {
    'beginner' => 1,
    'intermediate' => 2,
    'advanced' => 3,
    'expert' => 4,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    if (_level == 0) return const SizedBox.shrink();
    const heights = [5.0, 7.0, 9.0, 11.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 4; i++) ...[
          Container(
            width: 3,
            height: heights[i],
            decoration: BoxDecoration(
              color: i < _level ? color : color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          if (i < 3) const SizedBox(width: 2),
        ],
      ],
    );
  }
}
