import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// An authentic, living academic background featuring a stable, stationary
/// classroom photograph layered with an animated monochrome halftone dot screen
/// where the halftone dots/pixels visibly ripple, glide, and breathe in real time.
class HalftoneBackground extends StatefulWidget {
  final Widget child;
  final double opacity;
  static bool enableAnimation = true;

  const HalftoneBackground({
    super.key,
    required this.child,
    this.opacity = 0.28,
  });

  @override
  State<HalftoneBackground> createState() => _HalftoneBackgroundState();
}

class _HalftoneBackgroundState extends State<HalftoneBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final ValueNotifier<Offset?> _mouseNotifier = ValueNotifier<Offset?>(null);

  // Soft, muted slate-cyan tint for dark mode (avoids harsh blinding white dots)
  static const ColorFilter _darkHalftoneFilter = ColorFilter.matrix([
    -0.55, 0, 0, 0, 130,
    0, -0.55, 0, 0, 145,
    0, 0, -0.55, 0, 165,
    0, 0, 0, 1, 0,
  ]);

  @override
  void initState() {
    super.initState();
    // Continuous 16-second smooth looping halftone wave animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );

    final bool isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (HalftoneBackground.enableAnimation && !isTest) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _mouseNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return MouseRegion(
      onHover: (event) => _mouseNotifier.value = event.localPosition,
      onExit: (_) => _mouseNotifier.value = null,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 1. Solid theme background base
          Positioned.fill(
            child: Container(
              color: bgColor,
            ),
          ),

          // 2. Stationary classroom photo (anchored, firmly centered)
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.18 : widget.opacity,
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

          // 3. Animated monochrome halftone screen layer (dots/pixels rippling & gliding)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_controller, _mouseNotifier]),
              builder: (context, _) {
                return CustomPaint(
                  painter: AnimatedHalftoneScreenPainter(
                    progress: _controller.value,
                    mousePos: _mouseNotifier.value,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // 4. Radial backdrop vignette: clears out hero text area for max legibility
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

          // 5. Smooth top & bottom edge fade so it melts seamlessly into the page
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          AppTheme.darkBackground.withValues(alpha: 0.15),
                          Colors.transparent,
                          AppTheme.darkBackground.withValues(alpha: 0.60),
                        ]
                      : [
                          AppTheme.lightBackground.withValues(alpha: 0.05),
                          Colors.transparent,
                          AppTheme.lightBackground.withValues(alpha: 0.40),
                        ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // 6. Foreground content (scrollable layout, cards, buttons)
          widget.child,
        ],
      ),
    );
  }
}

/// Renders an authentic monochrome halftone dot screen where dots/pixels
/// continuously undulate in harmonic size waves, glide across the lattice,
/// and react to mouse hovering without introducing foreign colored circles.
class AnimatedHalftoneScreenPainter extends CustomPainter {
  final double progress;
  final Offset? mousePos;
  final bool isDark;

  static const double _spacing = 15.0;
  static const double _rowHeight = 13.0; // _spacing * sqrt(3) / 2 ≈ 12.99 (fine hexagonal print lattice)

  AnimatedHalftoneScreenPainter({
    required this.progress,
    required this.mousePos,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final dotPaint = Paint()..style = PaintingStyle.fill;
    // Pure monochrome: black ink dots in light mode, soft white dots in dark mode
    final dotColor = isDark ? Colors.white : Colors.black;

    // Seamless continuous drift of the halftone dot lattice
    final double dx = (progress * _spacing * 1.5) % _spacing;
    final double dy = (progress * _rowHeight * 1.5) % _rowHeight;

    final int cols = (size.width / _spacing).ceil() + 2;
    final int rows = (size.height / _rowHeight).ceil() + 2;

    final double centerX = size.width * 0.5;
    final double centerY = size.height * 0.35;
    final double maxDist = math.max(centerX, centerY);

    final double phase = progress * 2.0 * math.pi;

    for (int r = -1; r < rows; r++) {
      final double y = (r * _rowHeight) - dy;
      final double rowOffset = (r % 2 != 0) ? (_spacing * 0.5) : 0.0;

      for (int c = -1; c < cols; c++) {
        final double x = (c * _spacing) + rowOffset - dx;

        if (x < -6 || x > size.width + 6 || y < -6 || y > size.height + 6) {
          continue;
        }

        // 1. Distance from center hero text area (softer in center, prominent on edges)
        final double distToCenter = math.sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
        final double centerFactor = (distToCenter / maxDist).clamp(0.0, 1.2);
        // Vignette weight: subtle in center (0.3) to strong at edges (1.05)
        final double densityWeight = 0.30 + (centerFactor * 0.75);

        // 2. Dynamic harmonic wave traveling across the halftone grid
        final double wave1 = math.sin((x * 0.009) + (y * 0.009) - phase);
        final double wave2 = math.cos((x * 0.013) - (y * 0.006) + (phase * 0.75));
        final double wave = (wave1 + wave2) * 0.5; // -1.0 to 1.0

        // 3. Fine, small dot radius undulating in subtle waves (from 0.4px to 1.85px)
        final double baseRadius = 0.85 * densityWeight;
        double radius = (baseRadius + (wave * 0.55 * densityWeight)).clamp(0.35, 1.85);

        // 4. Dot opacity matching authentic fine-grain print ink
        double baseAlpha = isDark
            ? (0.05 + (wave + 1.0) * 0.055) * densityWeight
            : (0.07 + (wave + 1.0) * 0.065) * densityWeight;

        // 5. Delicate interactive mouse ripple
        if (mousePos != null) {
          final double mDist = (Offset(x, y) - mousePos!).distance;
          if (mDist < 140) {
            final double influence = 1.0 - (mDist / 140.0);
            radius += influence * 0.9;
            baseAlpha += influence * (isDark ? 0.08 : 0.10);
          }
        }

        dotPaint.color = dotColor.withValues(alpha: baseAlpha.clamp(0.02, isDark ? 0.22 : 0.25));
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant AnimatedHalftoneScreenPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.mousePos != mousePos ||
        oldDelegate.isDark != isDark;
  }
}
