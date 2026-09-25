import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A custom painter that renders a dynamic halftone dot-matrix raster pattern with variable
/// dot radii according to a smooth diagonal wave, matching authentic risograph and screen-print halftones.
class HalftoneWavePainter extends CustomPainter {
  final Color color;
  final double dotSpacing;
  final double maxRadius;
  final double minRadius;
  final double angle;
  final double waveFrequency;
  final double baseOpacity;
  final bool fadeBottomLeft;

  HalftoneWavePainter({
    required this.color,
    this.dotSpacing = 7.5,
    this.maxRadius = 3.5,
    this.minRadius = 0.4,
    this.angle = -0.58,
    this.waveFrequency = 3.2,
    this.baseOpacity = 0.25,
    this.fadeBottomLeft = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    final cols = (size.width / dotSpacing).ceil() + 1;
    final rows = (size.height / dotSpacing).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      final y = r * dotSpacing;
      for (int c = 0; c < cols; c++) {
        final x = c * dotSpacing;

        final nx = x / size.width;
        final ny = y / size.height;

        // Wave projection across diagonal
        final proj = (nx * cosA + ny * sinA);
        // Halftone modulation (wave peak)
        final wave = 0.5 + 0.5 * math.sin(proj * math.pi * waveFrequency);

        // Clearance so text on the left stays ultra-clear and readable
        double clearance = 1.0;
        if (fadeBottomLeft) {
          clearance = (nx * 0.8 + (1.0 - ny) * 0.4).clamp(0.0, 1.0);
          clearance = math.pow(clearance, 1.3).toDouble();
        }

        final factor = math.pow(wave, 1.6) * clearance;
        final radius = minRadius + (maxRadius - minRadius) * factor;

        if (radius >= 0.7 && clearance > 0.08) {
          final alpha = (baseOpacity * (0.35 + 0.65 * factor)).clamp(0.0, 1.0);
          paint.color = color.withValues(alpha: alpha);
          canvas.drawCircle(Offset(x, y), radius, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant HalftoneWavePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dotSpacing != dotSpacing ||
        oldDelegate.maxRadius != maxRadius ||
        oldDelegate.minRadius != minRadius ||
        oldDelegate.angle != angle ||
        oldDelegate.waveFrequency != waveFrequency ||
        oldDelegate.baseOpacity != baseOpacity ||
        oldDelegate.fadeBottomLeft != fadeBottomLeft;
  }
}

/// A positioned background widget that decorates a schedule card with a colored halftone pattern.
class HalftoneCardDecoration extends StatelessWidget {
  final Color color;
  final double width;
  final double dotSpacing;
  final double maxRadius;
  final double baseOpacity;

  const HalftoneCardDecoration({
    super.key,
    required this.color,
    this.width = 160,
    this.dotSpacing = 7.5,
    this.maxRadius = 3.6,
    this.baseOpacity = 0.25,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: width,
      child: IgnorePointer(
        child: ClipRect(
          child: Stack(
            children: [
              // Subtle colored radial glow behind the dots
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.1,
                      colors: [
                        color.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Halftone dot matrix
              Positioned.fill(
                child: CustomPaint(
                  painter: HalftoneWavePainter(
                    color: color,
                    dotSpacing: dotSpacing,
                    maxRadius: maxRadius,
                    baseOpacity: baseOpacity,
                    fadeBottomLeft: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
