import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class RadarDimension {
  final String label;
  final double value; // 0 to 100 or normalized
  final String? displayValue;

  const RadarDimension({
    required this.label,
    required this.value,
    this.displayValue,
  });
}

/// A modern dual-layer hexagonal radar chart with concentric polygon web
/// and optional side breakdown indicators, inspired by modern cyber-analytics telemetry.
class AnalyticsRadarChart extends StatelessWidget {
  final List<RadarDimension> dimensions;
  final List<RadarDimension>? secondaryDimensions;
  final double maxValue;
  final double size;
  final Color? color;
  final Color? secondaryColor;
  final bool isDark;
  final int webLevels;
  final bool showBreakdownList;
  final String? primaryLegend;
  final String? secondaryLegend;

  const AnalyticsRadarChart({
    super.key,
    required this.dimensions,
    this.secondaryDimensions,
    this.maxValue = 100.0,
    this.size = 200.0,
    this.color,
    this.secondaryColor,
    required this.isDark,
    this.webLevels = 4,
    this.showBreakdownList = false,
    this.primaryLegend = 'Mastery',
    this.secondaryLegend = 'Target',
  });

  @override
  Widget build(BuildContext context) {
    if (dimensions.length < 3) {
      return SizedBox(
        height: size,
        child: Center(
          child: Text(
            'Requires at least 3 dimensions for radar',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            ),
          ),
        ),
      );
    }

    final effectiveColor = color ?? const Color(0xFFF59E0B); // Glowing Gold
    final effectiveSecondary = secondaryColor ?? const Color(0xFF06B6D4); // Cyber Cyan
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final radarCanvas = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _RadarPainter(
          dimensions: dimensions,
          secondaryDimensions: secondaryDimensions,
          maxValue: maxValue,
          color: effectiveColor,
          secondaryColor: effectiveSecondary,
          isDark: isDark,
          webLevels: webLevels,
        ),
      ),
    );

    if (!showBreakdownList) {
      return radarCanvas;
    }

    // With side breakdown list (inspired by bottom right of reference image)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        radarCanvas,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Legend
              if (secondaryDimensions != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: effectiveColor, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(primaryLegend ?? 'Me', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: effectiveColor)),
                      const SizedBox(width: 8),
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: effectiveSecondary, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(secondaryLegend ?? 'Target', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: effectiveSecondary)),
                    ],
                  ),
                ),
              // Category percentages
              ...dimensions.map((dim) {
                final pct = dim.value.round();
                Color pillColor = effectiveColor;
                if (pct >= 85) {
                  pillColor = const Color(0xFF10B981);
                } else if (pct < 70) {
                  pillColor = const Color(0xFFF43F5E);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dim.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: pillColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: pillColor.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: pillColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<RadarDimension> dimensions;
  final List<RadarDimension>? secondaryDimensions;
  final double maxValue;
  final Color color;
  final Color secondaryColor;
  final bool isDark;
  final int webLevels;

  _RadarPainter({
    required this.dimensions,
    this.secondaryDimensions,
    required this.maxValue,
    required this.color,
    required this.secondaryColor,
    required this.isDark,
    required this.webLevels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Reserve margin for text labels around vertices
    final radius = (math.min(size.width, size.height) / 2) - 26.0;
    if (radius <= 0) return;

    final count = dimensions.length;
    final angleStep = (2 * math.pi) / count;
    const startAngle = -math.pi / 2;

    final gridPaint = Paint()
      ..color = isDark
          ? const Color(0xFF334155).withValues(alpha: 0.7)
          : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final spokePaint = Paint()
      ..color = isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.9)
          : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Concentric Polygon Webs
    for (int level = 1; level <= webLevels; level++) {
      final levelRadius = radius * (level / webLevels);
      final webPath = Path();

      for (int i = 0; i < count; i++) {
        final angle = startAngle + (i * angleStep);
        final x = center.dx + levelRadius * math.cos(angle);
        final y = center.dy + levelRadius * math.sin(angle);
        if (i == 0) {
          webPath.moveTo(x, y);
        } else {
          webPath.lineTo(x, y);
        }
      }
      webPath.close();
      canvas.drawPath(webPath, gridPaint);
    }

    // 2. Radial Spokes & Vertex Labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < count; i++) {
      final angle = startAngle + (i * angleStep);
      final spokeEnd = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, spokeEnd, spokePaint);

      // Vertex label
      final labelRadius = radius + 14.0;
      final labelX = center.dx + labelRadius * math.cos(angle);
      final labelY = center.dy + labelRadius * math.sin(angle);

      final dim = dimensions[i];
      textPainter.text = TextSpan(
        text: dim.label,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      );
      textPainter.layout(maxWidth: 60);

      final textOffset = Offset(
        labelX - (textPainter.width / 2),
        labelY - (textPainter.height / 2),
      );
      textPainter.paint(canvas, textOffset);
    }

    // 3. Secondary Polygon (Benchmark / Target Layer, e.g. Cyber Cyan)
    if (secondaryDimensions != null && secondaryDimensions!.length == count) {
      final secPath = Path();
      final secPoints = <Offset>[];

      for (int i = 0; i < count; i++) {
        final angle = startAngle + (i * angleStep);
        final valPct = (secondaryDimensions![i].value / maxValue).clamp(0.05, 1.0);
        final r = radius * valPct;
        final pt = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
        secPoints.add(pt);
        if (i == 0) {
          secPath.moveTo(pt.dx, pt.dy);
        } else {
          secPath.lineTo(pt.dx, pt.dy);
        }
      }
      secPath.close();

      // Subtle cyan fill
      final secFill = Paint()
        ..color = secondaryColor.withValues(alpha: isDark ? 0.15 : 0.10)
        ..style = PaintingStyle.fill;
      canvas.drawPath(secPath, secFill);

      // Dashed or semi-transparent stroke
      final secStroke = Paint()
        ..color = secondaryColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(secPath, secStroke);
    }

    // 4. Primary Data Polygon (Student Profile, Glowing Gold)
    final dataPath = Path();
    final dataPoints = <Offset>[];

    for (int i = 0; i < count; i++) {
      final angle = startAngle + (i * angleStep);
      final valPct = (dimensions[i].value / maxValue).clamp(0.05, 1.0);
      final r = radius * valPct;
      final pt = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      dataPoints.add(pt);

      if (i == 0) {
        dataPath.moveTo(pt.dx, pt.dy);
      } else {
        dataPath.lineTo(pt.dx, pt.dy);
      }
    }
    dataPath.close();

    // Data polygon fill with gradient-like opacity
    final fillPaint = Paint()
      ..color = color.withValues(alpha: isDark ? 0.28 : 0.20)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, fillPaint);

    // Glowing border stroke
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(dataPath, strokePaint);

    // Vertex circular dots (white core + colored border + outer halo)
    final haloPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final dotFill = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : Colors.white
      ..style = PaintingStyle.fill;
    final dotBorder = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final pt in dataPoints) {
      canvas.drawCircle(pt, 6.0, haloPaint);
      canvas.drawCircle(pt, 3.5, dotFill);
      canvas.drawCircle(pt, 3.5, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
