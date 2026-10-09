import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// A rich, living academic background featuring a cinematic classroom backdrop
/// layered with an authentic dynamic halftone dot matrix that drifts, ripples,
/// and responds to user interaction in real time.
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
    // Continuous 24-second smooth looping animation in production
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
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
        children: [
          // 1. Solid theme base
          Positioned.fill(
            child: Container(
              color: bgColor,
            ),
          ),

          // 2. Cinematic classroom photo with subtle Ken-Burns breathing drift
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final driftX = math.sin(t * 2 * math.pi) * 8.0;
                final driftY = math.cos(t * 2 * math.pi * 0.7) * 5.0;
                final scale = 1.04 + math.sin(t * 2 * math.pi * 0.5) * 0.015;

                return Transform.translate(
                  offset: Offset(driftX, driftY),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: isDark ? 0.16 : widget.opacity,
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
                );
              },
            ),
          ),

          // 3. Dynamic procedural halftone dot matrix layer (moving & rippling dots)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_controller, _mouseNotifier]),
              builder: (context, _) {
                return CustomPaint(
                  painter: DynamicHalftoneDotsPainter(
                    progress: _controller.value,
                    mousePos: _mouseNotifier.value,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // 4. Floating atmospheric ambient particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FloatingHalftoneMotesPainter(
                    progress: _controller.value,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // 5. Radial backdrop vignette: clears out hero text area for crystal-clear legibility
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

          // 6. Smooth top & bottom edge fade so it melts seamlessly into the page
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

          // 7. Foreground content (does not rebuild when dots animate)
          widget.child,
        ],
      ),
    );
  }
}

/// A high-performance painter that renders a dynamic, streaming halftone dot lattice
/// with organic sinusoidal size undulations, radial text protection, and mouse magnetism.
class DynamicHalftoneDotsPainter extends CustomPainter {
  final double progress;
  final Offset? mousePos;
  final bool isDark;

  static const double _spacing = 26.0;
  static const double _rowHeight = 22.5; // _spacing * 0.866 (Hexagonal lattice)

  DynamicHalftoneDotsPainter({
    required this.progress,
    required this.mousePos,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final accentDotPaint = Paint()..style = PaintingStyle.fill;

    // Palette selection: high saturation in Light Mode, soothing soft tones in Dark Mode
    if (isDark) {
      dotPaint.color = const Color(0xFF38BDF8).withValues(alpha: 0.15); // Sky cyan
      accentDotPaint.color = const Color(0xFF10B981).withValues(alpha: 0.22); // Mint emerald
    } else {
      dotPaint.color = const Color(0xFF0D9488).withValues(alpha: 0.12); // Saturated institutional teal
      accentDotPaint.color = const Color(0xFF2563EB).withValues(alpha: 0.16); // Saturated royal blue
    }

    // Continuous seamless wrapping offsets
    final double dx = (progress * _spacing * 2.0) % _spacing;
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

        // Skip offscreen dots
        if (x < -10 || x > size.width + 10 || y < -10 || y > size.height + 10) {
          continue;
        }

        // 1. Radial distance from center text area (keep center subtle, outer edges punchy)
        final double distToCenter = math.sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
        final double centerNorm = (distToCenter / maxDist).clamp(0.0, 1.3);

        // Halftone density: smaller dots in center (0.8px), larger dots on periphery (2.6px)
        final double baseRadius = 0.8 + (centerNorm * 1.6);

        // 2. Harmonic organic wave ripple across the lattice
        final double wave1 = math.sin((x * 0.007) + (y * 0.007) - phase);
        final double wave2 = math.cos((x * 0.011) - (y * 0.006) + (phase * 0.7));
        final double waveFactor = (wave1 + wave2) * 0.5; // -1.0 to 1.0

        double radius = (baseRadius + (waveFactor * 0.9)).clamp(0.5, 3.8);

        // 3. Interactive mouse cursor magnetic ripple
        bool isNearCursor = false;
        if (mousePos != null) {
          final double mDist = (Offset(x, y) - mousePos!).distance;
          if (mDist < 160) {
            final double influence = 1.0 - (mDist / 160.0);
            radius += influence * 2.6;
            isNearCursor = true;
          }
        }

        // Draw the dot using accent paint if in peak wave crest or near cursor
        if (isNearCursor || waveFactor > 0.6) {
          canvas.drawCircle(Offset(x, y), radius, accentDotPaint);
        } else {
          canvas.drawCircle(Offset(x, y), radius, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant DynamicHalftoneDotsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.mousePos != mousePos ||
        oldDelegate.isDark != isDark;
  }
}

/// Renders 14 ambient floating halftone orbs drifting smoothly in the background.
class _FloatingHalftoneMotesPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  static const List<Map<String, double>> _motes = [
    {'x': 0.08, 'y': 0.22, 'r': 6.5, 'speed': 1.0, 'amp': 18.0},
    {'x': 0.18, 'y': 0.68, 'r': 9.0, 'speed': 1.4, 'amp': 24.0},
    {'x': 0.28, 'y': 0.15, 'r': 5.0, 'speed': 0.9, 'amp': 14.0},
    {'x': 0.84, 'y': 0.25, 'r': 8.0, 'speed': 1.2, 'amp': 22.0},
    {'x': 0.92, 'y': 0.58, 'r': 11.0, 'speed': 1.5, 'amp': 28.0},
    {'x': 0.76, 'y': 0.78, 'r': 7.0, 'speed': 1.1, 'amp': 16.0},
    {'x': 0.12, 'y': 0.45, 'r': 10.0, 'speed': 1.3, 'amp': 20.0},
    {'x': 0.88, 'y': 0.12, 'r': 5.5, 'speed': 0.8, 'amp': 12.0},
    {'x': 0.04, 'y': 0.82, 'r': 8.5, 'speed': 1.4, 'amp': 25.0},
    {'x': 0.95, 'y': 0.38, 'r': 6.0, 'speed': 1.0, 'amp': 15.0},
    {'x': 0.22, 'y': 0.35, 'r': 7.5, 'speed': 1.1, 'amp': 17.0},
    {'x': 0.81, 'y': 0.48, 'r': 9.5, 'speed': 1.3, 'amp': 21.0},
    {'x': 0.15, 'y': 0.90, 'r': 6.0, 'speed': 0.9, 'amp': 13.0},
    {'x': 0.86, 'y': 0.88, 'r': 7.0, 'speed': 1.2, 'amp': 19.0},
  ];

  _FloatingHalftoneMotesPainter({
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final motePaint = Paint()..style = PaintingStyle.fill;
    final Color baseColor = isDark
        ? const Color(0xFF38BDF8) // Sky cyan
        : const Color(0xFF0D9488); // Saturated institutional teal

    for (final m in _motes) {
      final double speed = m['speed']!;
      final double amp = m['amp']!;
      final double r = m['r']!;

      final double t = (progress * speed) % 1.0;
      final double angle = t * 2.0 * math.pi;

      final double px = (m['x']! * size.width) + math.sin(angle) * amp;
      final double py = (m['y']! * size.height) + math.cos(angle * 0.8) * (amp * 0.7);

      final double pulse = 0.85 + (math.sin(angle) * 0.25);
      final double currentR = r * pulse;

      // Outer soft halo
      motePaint.color = baseColor.withValues(alpha: isDark ? 0.05 : 0.04);
      canvas.drawCircle(Offset(px, py), currentR * 1.6, motePaint);

      // Core dot
      motePaint.color = baseColor.withValues(alpha: isDark ? 0.14 : 0.10);
      canvas.drawCircle(Offset(px, py), currentR, motePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingHalftoneMotesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
