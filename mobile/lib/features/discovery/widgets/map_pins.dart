import 'dart:math' show pi, sin, cos;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/widgets/avatar.dart';
import '../match.dart';

/// Map pin system for Discovery, per the "Playful Quest" pin design spec:
/// a chunky "candy drop" pin (circle + short rounded tail, thick white ring,
/// soft tinted shadow) shared by the standard and mutual-match variants, plus
/// a tail-less self marker (with a pulse ring) and cluster bubble. Rendered
/// as Flutter widgets/CustomPainter rather than static assets, using this
/// app's existing color tokens (already near-identical to the spec's
/// palette) and Fredoka (this app's established numeral/initials font, in
/// place of the spec's generic Poppins suggestion) for visual consistency
/// with the rest of SWAPPA.
///
/// Variants NOT implemented here (no corresponding app state yet): the
/// premium/boosted extra-ring ("boosted" isn't a per-candidate flag today),
/// the selected-state scale-up (no persistent tap-selection), and the
/// dimmed/filtered-out state (Discovery doesn't filter-in-place on the map).

/// Standard + mutual match pin — the "candy drop" shape.
class MatchMapPin extends StatelessWidget {
  const MatchMapPin({super.key, required this.match});
  final MatchResult match;

  static const _standardBodyRadius = 15.0;
  static const _mutualBodyRadius = 17.5;
  static const _ringWidth = 3.0;

  static double _bodyRadiusFor(bool mutual) =>
      mutual ? _mutualBodyRadius : _standardBodyRadius;
  static double _tailLengthFor(bool mutual) => _bodyRadiusFor(mutual) * 0.85;

  /// Total marker footprint — use these when placing the `Marker` so
  /// flutter_map's declared box matches this widget's actual rendered size.
  static double widthFor(bool mutual) =>
      (_bodyRadiusFor(mutual) + _ringWidth) * 2;
  static double heightFor(bool mutual) =>
      widthFor(mutual) + _tailLengthFor(mutual);

  @override
  Widget build(BuildContext context) {
    final mutual = match.mutual;
    final bodyRadius = _bodyRadiusFor(mutual);
    final fill = mutual ? AppColors.accent : AppColors.primary;
    // Dark violet on the yellow hero pin (matches AppColors.secondaryForeground,
    // the app's existing "text on accent" token); white on the standard pin.
    final contentColor = mutual ? AppColors.secondaryForeground : Colors.white;
    final width = widthFor(mutual);
    final height = heightFor(mutual);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: _CandyDropPainter(
              bodyRadius: bodyRadius,
              ringWidth: _ringWidth,
              fill: fill,
              shadowColor: fill.withValues(alpha: 0.4),
            ),
          ),
          Positioned(
            left: _ringWidth,
            top: _ringWidth,
            child: Avatar(
              initials: match.initials,
              color: fill,
              size: bodyRadius * 2,
              photoUrl: match.photoUrl,
              initialsColor: contentColor,
            ),
          ),
          if (mutual)
            const Positioned(top: -2, right: -2, child: _MutualBadge()),
        ],
      ),
    );
  }
}

/// Draws the "candy drop" silhouette: a circle with a short rounded tail,
/// a thick white ring (a centered stroke, half of which the fill covers —
/// simpler than compositing two separate ring/fill paths), and a soft
/// tinted shadow.
class _CandyDropPainter extends CustomPainter {
  const _CandyDropPainter({
    required this.bodyRadius,
    required this.ringWidth,
    required this.fill,
    required this.shadowColor,
  });

  final double bodyRadius;
  final double ringWidth;
  final Color fill;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, bodyRadius + ringWidth);
    final path = _dropPath(center, bodyRadius, size.height);

    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(
      path,
      Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth * 2,
    );
    canvas.drawPath(path, Paint()..color = fill);
  }

  Path _dropPath(Offset center, double r, double tipY) {
    const tailHalfAngle = 30 * pi / 180;
    final left = Offset(
      center.dx - r * sin(tailHalfAngle),
      center.dy + r * cos(tailHalfAngle),
    );
    final right = Offset(
      center.dx + r * sin(tailHalfAngle),
      center.dy + r * cos(tailHalfAngle),
    );
    final tip = Offset(center.dx, tipY);

    final circle = Path()..addOval(Rect.fromCircle(center: center, radius: r));
    final tail = Path()
      ..moveTo(left.dx, left.dy)
      ..quadraticBezierTo(
        center.dx - r * 0.3,
        (left.dy + tipY) / 2,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        center.dx + r * 0.3,
        (right.dy + tipY) / 2,
        right.dx,
        right.dy,
      )
      ..close();
    return Path.combine(PathOperation.union, circle, tail);
  }

  @override
  bool shouldRepaint(covariant _CandyDropPainter oldDelegate) =>
      oldDelegate.bodyRadius != bodyRadius ||
      oldDelegate.fill != fill ||
      oldDelegate.ringWidth != ringWidth;
}

/// Small violet badge with a white "swap" glyph — same icon as the
/// "Mutual Match" badge on [MatchCard], for a consistent motif.
class _MutualBadge extends StatelessWidget {
  const _MutualBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const Icon(Icons.repeat_rounded, size: 9, color: Colors.white),
    );
  }
}

/// The viewer's own marker — their stored coarse location, never a live GPS
/// fix. No tail (it isn't "pointing" at a candidate, just marking "you"),
/// grass-green fill, and a looping soft pulse ring.
class SelfMapPin extends StatefulWidget {
  const SelfMapPin({super.key});

  static const size = 44.0;

  @override
  State<SelfMapPin> createState() => _SelfMapPinState();
}

class _SelfMapPinState extends State<SelfMapPin>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dotSize = 22.0;
    return SizedBox(
      width: SelfMapPin.size,
      height: SelfMapPin.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final diameter = dotSize + (SelfMapPin.size - dotSize) * t;
              return Opacity(
                opacity: (1 - t) * 0.5,
                child: Container(
                  width: diameter,
                  height: diameter,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          Container(
            width: dotSize,
            height: dotSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cluster bubble — plain violet circle (no tail), white bold count, sized
/// in three tiers so denser clusters read as visually "heavier".
class ClusterMapPin extends StatelessWidget {
  const ClusterMapPin({super.key, required this.count});
  final int count;

  static double diameterFor(int count) =>
      count < 10 ? 36 : (count < 100 ? 44 : 52);

  @override
  Widget build(BuildContext context) {
    final diameter = diameterFor(count);
    final label = count > 99 ? '99+' : '$count';
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.fredoka(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: count < 100 ? 15 : 12,
        ),
      ),
    );
  }
}
