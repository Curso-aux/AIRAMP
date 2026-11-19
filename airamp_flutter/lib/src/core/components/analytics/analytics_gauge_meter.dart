import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AnalyticsGaugeMeter extends StatelessWidget {
  final double value; // 0.0 to 100.0
  final double maxValue;
  final String label;
  final String? statusText;
  final String valueSuffix;
  final double size;
  final bool isDark;
  final Color? customColor;
  final bool isReversedRisk; // true if high number means HIGH RISK (e.g. Dropout risk)

  const AnalyticsGaugeMeter({
    super.key,
    required this.value,
    this.maxValue = 100.0,
    required this.label,
    this.statusText,
    this.valueSuffix = '%',
    this.size = 150.0,
    required this.isDark,
    this.customColor,
    this.isReversedRisk = false,
  });

  Color _resolveColor(double pct) {
    if (customColor != null) return customColor!;
    if (isReversedRisk) {
      if (pct > 0.5) return AppTheme.error;
      if (pct > 0.25) return AppTheme.warning;
      return AppTheme.success;
    } else {
      if (pct >= 0.75) return AppTheme.success;
      if (pct >= 0.50) return AppTheme.warning;
      return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, maxValue);
    final pct = maxValue > 0 ? (clamped / maxValue) : 0.0;
    final activeColor = _resolveColor(pct);

    final trackColor = isDark
        ? AppTheme.darkBorder.withValues(alpha: 0.5)
        : AppTheme.lightBorder.withValues(alpha: 0.8);

    return SizedBox(
      width: size,
      height: size * 0.72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size * 0.72),
            painter: _GaugePainter(
              percentage: pct,
              activeColor: activeColor,
              trackColor: trackColor,
              strokeWidth: size * 0.09,
            ),
          ),
          Positioned(
            bottom: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${value.toStringAsFixed(0)}$valueSuffix',
                  style: TextStyle(
                    fontSize: size * 0.18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextBright : AppTheme.lightTextBright,
                    letterSpacing: -0.5,
                  ),
                ),
                if (statusText != null) ...[
                  const SizedBox(height: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText!,
                      style: TextStyle(
                        fontSize: size * 0.075,
                        fontWeight: FontWeight.w700,
                        color: activeColor,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: size * 0.072,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final Color activeColor;
  final Color trackColor;
  final double strokeWidth;

  _GaugePainter({
    required this.percentage,
    required this.activeColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.75);
    final radius = (size.width - strokeWidth) / 2;

    const startAngle = math.pi;
    const totalSweep = math.pi;

    // 1. Background Track Arc (180 degrees)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // 2. Active Progress Arc
    if (percentage > 0) {
      final activeSweep = totalSweep * percentage.clamp(0.01, 1.0);
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}
