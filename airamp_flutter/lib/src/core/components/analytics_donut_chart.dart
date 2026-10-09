import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Reusable painter for modern, sleek donut breakdown charts
/// used across Student, Teacher, and Admin analytics.
class AnalyticsDonutPainter extends CustomPainter {
  final double valueA;
  final double valueB;
  final Color colorA;
  final Color colorB;
  final Color trackColor;
  final double strokeWidth;

  const AnalyticsDonutPainter({
    required this.valueA,
    required this.valueB,
    required this.colorA,
    required this.colorB,
    required this.trackColor,
    this.strokeWidth = 11.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // 1. Background Track Ring
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final total = valueA + valueB;
    if (total <= 0) return;

    const startAngle = -math.pi / 2;
    final hasBoth = valueA > 0 && valueB > 0;
    final gap = hasBoth ? 0.08 : 0.0;

    final sweepA = (valueA / total) * 2 * math.pi;
    final sweepB = (valueB / total) * 2 * math.pi;

    if (valueA > 0) {
      final sweep = (sweepA - gap).clamp(0.02, 2 * math.pi);
      final paintA = Paint()
        ..color = colorA
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (gap / 2),
        sweep,
        false,
        paintA,
      );
    }

    if (valueB > 0) {
      final sweep = (sweepB - gap).clamp(0.02, 2 * math.pi);
      final paintB = Paint()
        ..color = colorB
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + sweepA + (gap / 2),
        sweep,
        false,
        paintB,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AnalyticsDonutPainter oldDelegate) {
    return oldDelegate.valueA != valueA ||
        oldDelegate.valueB != valueB ||
        oldDelegate.colorA != colorA ||
        oldDelegate.colorB != colorB ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
