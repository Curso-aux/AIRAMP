import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ConcentricStat {
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  const ConcentricStat({
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });
}

/// A modern dual-ring concentric donut chart paired with a bold 2x2 stat
/// quad-grid, directly reflecting the visual architecture of advanced telemetry dashboards.
class AnalyticsConcentricDonut extends StatelessWidget {
  final double outerValue; // 0.0 to 100.0
  final double innerValue; // 0.0 to 100.0
  final Color outerColor;
  final Color innerColor;
  final String centerValue;
  final String centerLabel;
  final List<ConcentricStat> stats;
  final double size;
  final bool isDark;

  const AnalyticsConcentricDonut({
    super.key,
    required this.outerValue,
    required this.innerValue,
    this.outerColor = const Color(0xFF06B6D4), // Cyan
    this.innerColor = const Color(0xFFF59E0B), // Gold
    required this.centerValue,
    required this.centerLabel,
    required this.stats,
    this.size = 140.0,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final trackColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final textBright = isDark ? AppTheme.darkTextBright : AppTheme.lightTextBright;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // On phone screens (< 480px), use proportional sizing:
        // For narrow phones (totalWidth < 380), size donut to 110-115px
        // For medium/desktop, use widget.size or 140px.
        final effectiveDonutSize = totalWidth < 380
            ? 110.0
            : (totalWidth < 480 ? 120.0 : size);
        final isCompact = totalWidth < 440;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Concentric Dual Rings
            SizedBox(
              width: effectiveDonutSize,
              height: effectiveDonutSize,
              child: CustomPaint(
                painter: _ConcentricDonutPainter(
                  outerPct: (outerValue / 100.0).clamp(0.0, 1.0),
                  innerPct: (innerValue / 100.0).clamp(0.0, 1.0),
                  outerColor: outerColor,
                  innerColor: innerColor,
                  trackColor: trackColor,
                  isDark: isDark,
                  isCompact: isCompact,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        centerValue,
                        style: TextStyle(
                          fontSize: effectiveDonutSize * 0.19,
                          fontWeight: FontWeight.bold,
                          color: textBright,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        centerLabel,
                        style: TextStyle(
                          fontSize: effectiveDonutSize * 0.08,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: isCompact ? 10 : 16),

            // 2. Bold 2x2 Stat Quad-Grid (Directly inspired by reference image)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Row (Stat 0, Stat 1)
                  Row(
                    children: [
                      if (stats.isNotEmpty)
                        Expanded(child: _buildStatTile(stats[0], textMuted, isCompact)),
                      if (stats.length > 1) ...[
                        SizedBox(width: isCompact ? 6 : 10),
                        Expanded(child: _buildStatTile(stats[1], textMuted, isCompact)),
                      ],
                    ],
                  ),
                  SizedBox(height: isCompact ? 6 : 10),
                  // Bottom Row (Stat 2, Stat 3)
                  Row(
                    children: [
                      if (stats.length > 2)
                        Expanded(child: _buildStatTile(stats[2], textMuted, isCompact)),
                      if (stats.length > 3) ...[
                        SizedBox(width: isCompact ? 6 : 10),
                        Expanded(child: _buildStatTile(stats[3], textMuted, isCompact)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatTile(ConcentricStat stat, Color textMuted, bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 10,
        vertical: isCompact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: stat.color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: stat.color.withValues(alpha: isDark ? 0.25 : 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              stat.value,
              maxLines: 1,
              style: TextStyle(
                fontSize: isCompact ? 15 : 18,
                fontWeight: FontWeight.bold,
                color: stat.color,
                letterSpacing: -0.4,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            maxLines: 1,
            style: TextStyle(
              fontSize: isCompact ? 9 : 10,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (stat.subtitle != null && !isCompact) ...[
            const SizedBox(height: 1),
            Text(
              stat.subtitle!,
              maxLines: 1,
              style: TextStyle(
                fontSize: 8.5,
                color: textMuted.withValues(alpha: 0.75),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConcentricDonutPainter extends CustomPainter {
  final double outerPct;
  final double innerPct;
  final Color outerColor;
  final Color innerColor;
  final Color trackColor;
  final bool isDark;
  final bool isCompact;

  _ConcentricDonutPainter({
    required this.outerPct,
    required this.innerPct,
    required this.outerColor,
    required this.innerColor,
    required this.trackColor,
    required this.isDark,
    this.isCompact = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width / 2) - (isCompact ? 6 : 8);
    final innerRadius = outerRadius - (isCompact ? 10 : 13);

    final outerStroke = isCompact ? 6.5 : 9.0;
    final innerStroke = isCompact ? 5.0 : 7.5;
    const startAngle = -math.pi / 2;

    // Outer Background Track
    final outerTrackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStroke;
    canvas.drawCircle(center, outerRadius, outerTrackPaint);

    // Inner Background Track
    final innerTrackPaint = Paint()
      ..color = trackColor.withValues(alpha: isDark ? 0.6 : 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerStroke;
    canvas.drawCircle(center, innerRadius, innerTrackPaint);

    // Outer Arc
    if (outerPct > 0) {
      final outerPaint = Paint()
        ..color = outerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStroke
        ..strokeCap = StrokeCap.round;
      final sweep = (outerPct * 2 * math.pi).clamp(0.05, 2 * math.pi);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        sweep,
        false,
        outerPaint,
      );
    }

    // Inner Arc
    if (innerPct > 0) {
      final innerPaint = Paint()
        ..color = innerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerStroke
        ..strokeCap = StrokeCap.round;
      final sweep = (innerPct * 2 * math.pi).clamp(0.05, 2 * math.pi);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        sweep,
        false,
        innerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConcentricDonutPainter oldDelegate) {
    return oldDelegate.outerPct != outerPct ||
        oldDelegate.innerPct != innerPct ||
        oldDelegate.outerColor != outerColor ||
        oldDelegate.innerColor != innerColor;
  }
}
