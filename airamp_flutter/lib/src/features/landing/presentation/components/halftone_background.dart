import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class HalftoneBackground extends StatelessWidget {
  final Widget child;
  final double opacity;

  const HalftoneBackground({
    super.key,
    required this.child,
    this.opacity = 0.28,
  });

  // Soft, muted slate-cyan tint for dark mode (avoids harsh blinding white dots)
  static const ColorFilter _darkHalftoneFilter = ColorFilter.matrix([
    -0.55, 0, 0, 0, 130,
    0, -0.55, 0, 0, 145,
    0, 0, -0.55, 0, 165,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      children: [
        // Solid theme base
        Positioned.fill(
          child: Container(
            color: bgColor,
          ),
        ),

        // Halftone dot pattern layer (gentle, atmospheric)
        Positioned.fill(
          child: Opacity(
            opacity: isDark ? 0.16 : opacity,
            child: ColorFiltered(
              colorFilter: isDark
                  ? _darkHalftoneFilter
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Image.asset(
                'assets/images/classroom_halftone_bg.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) {
                  return Image.network(
                    'classroom_halftone_bg.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (c, e, s) => const SizedBox.shrink(),
                  );
                },
              ),
            ),
          ),
        ),

        // Radial backdrop vignette: clears out the hero text area for max legibility
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.35),
                radius: 0.85,
                colors: isDark
                    ? [
                        AppTheme.darkBackground.withValues(alpha: 0.65),
                        AppTheme.darkBackground.withValues(alpha: 0.20),
                        AppTheme.darkBackground.withValues(alpha: 0.70),
                      ]
                    : [
                        AppTheme.lightBackground.withValues(alpha: 0.45),
                        AppTheme.lightBackground.withValues(alpha: 0.15),
                        AppTheme.lightBackground.withValues(alpha: 0.40),
                      ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // Smooth top & bottom edge fade so it melts seamlessly into the page
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        AppTheme.darkBackground.withValues(alpha: 0.40),
                        Colors.transparent,
                        AppTheme.darkBackground.withValues(alpha: 0.60),
                      ]
                    : [
                        AppTheme.lightBackground.withValues(alpha: 0.30),
                        Colors.transparent,
                        AppTheme.lightBackground.withValues(alpha: 0.40),
                      ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),

        // Foreground content
        child,
      ],
    );
  }
}
