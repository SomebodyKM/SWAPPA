import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_colors.dart';

/// The SWAPPA app mark (swap loop) rendered from the bundled SVG.
class SwappaLogo extends StatelessWidget {
  const SwappaLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/swappa-icon.svg',
      width: size,
      height: size,
    );
  }
}

/// Logo + "swappa" wordmark (Fredoka), used in app bars.
class SwappaWordmark extends StatelessWidget {
  const SwappaWordmark({super.key, this.iconSize = 32});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwappaLogo(size: iconSize),
        const SizedBox(width: 8),
        Text(
          'SWAPPA',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
