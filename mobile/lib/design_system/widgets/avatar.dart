import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Circular avatar — shows [photoUrl] when set (falling back to initials on
/// load failure), otherwise a solid brand-ish background with initials.
/// Optionally shows a colored ring for status (online / mutual match).
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 48,
    this.ringColor,
    this.photoUrl,
    this.initialsColor = Colors.white,
  });

  final String initials;
  final Color color;
  final double size;
  final Color? ringColor;
  final String? photoUrl;
  final Color initialsColor;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: ClipOval(
        child: photoUrl != null
            ? Image.network(
                photoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initialsText(),
              )
            : _initialsText(),
      ),
    );
    if (ringColor == null) return circle;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor!, width: 2),
      ),
      child: circle,
    );
  }

  Widget _initialsText() => Text(
    initials,
    style: GoogleFonts.fredoka(
      fontSize: size * 0.36,
      fontWeight: FontWeight.w600,
      color: initialsColor,
    ),
  );
}

/// Deterministic accent color for an avatar based on a seed (name/id), drawn
/// from the design's chart palette.
Color avatarColorFor(String seed) {
  const palette = [
    Color(0xFF16A34A), // green
    Color(0xFF7C3AED), // violet
    Color(0xFFEAB308), // amber
    Color(0xFF2563EB), // blue
    Color(0xFFEC4899), // pink
    Color(0xFF0D9488), // teal
  ];
  var hash = 0;
  for (final code in seed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}
