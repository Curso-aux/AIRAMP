import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class DonutSegment {
  final String label;
  final double value;
  final Color color;

  const DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

class AnalyticsDonutChart extends StatelessWidget {
  final List<DonutSegment> segments;
  final String? centerText;
  final String? centerSubtext;
  final double size;
  final double strokeWidth;
  final bool isDark;
  final bool showLegend;

  const AnalyticsDonutChart({
    super.key,
    required this.segments,
    this.centerText,
    this.centerSubtext,
    this.size = 130.0,
    this.strokeWidth = 12.0,
    required this.isDark,
    this.showLegend = true,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0.0, (sum, seg) => sum + seg.value);
    final trackColor = isDark
        ? AppTheme.darkBorder.withValues(alpha: 0.35)
        : AppTheme.lightBorder.withValues(alpha: 0.55);
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final textPrimary = isDark ? AppTheme.darkTextBright : AppTheme.lightTextBright;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _MultiSegmentDonutPainter(
              segments: segments,
              total: total,
              trackColor: trackColor,
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (centerText != null)
                    Text(
                      centerText!,
                      style: TextStyle(
                        fontSize: size * 0.18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  if (centerSubtext != null)
                    Text(
                      centerSubtext!,
                      style: TextStyle(
                        fontSize: size * 0.09,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showLegend && segments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: segments.map((seg) {
              final pct = total > 0 ? ((seg.value / total) * 100).round() : 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: seg.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${seg.label} ($pct%)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: textMuted,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _MultiSegmentDonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double total;
  final Color trackColor;
  final double strokeWidth;

  _MultiSegmentDonutPainter({
    required this.segments,
    required this.total,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (total <= 0) return;

    final activeSegments = segments.where((s) => s.value > 0).toList();
    if (activeSegments.isEmpty) return;

    final hasMultiple = activeSegments.length > 1;
    final gapAngle = hasMultiple ? (0.04 * math.pi) : 0.0;
    const startAngle = -math.pi / 2;

    double currentAngle = startAngle;
    for (final seg in activeSegments) {
      final sweepAngle = (seg.value / total) * (2 * math.pi);
      final effectiveSweep = (sweepAngle - gapAngle).clamp(0.01, 2 * math.pi);

      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle + (gapAngle / 2),
        effectiveSweep,
        false,
        paint,
      );

      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _MultiSegmentDonutPainter oldDelegate) {
    return oldDelegate.total != total ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.segments != segments;
  }
}
