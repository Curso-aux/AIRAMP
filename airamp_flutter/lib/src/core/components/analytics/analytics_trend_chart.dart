import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TrendPoint {
  final String label;
  final double value;

  const TrendPoint({required this.label, required this.value});
}

class AnalyticsTrendChart extends StatefulWidget {
  final List<TrendPoint> points;
  final double? minY;
  final double? maxY;
  final double? baselineY;
  final String? baselineLabel;
  final double height;
  final Color? lineColor;
  final bool isDark;
  final String valueSuffix;
  final bool showArea;
  final bool showDots;

  const AnalyticsTrendChart({
    super.key,
    required this.points,
    this.minY,
    this.maxY,
    this.baselineY,
    this.baselineLabel,
    this.height = 140.0,
    this.lineColor,
    required this.isDark,
    this.valueSuffix = '%',
    this.showArea = true,
    this.showDots = true,
  });

  @override
  State<AnalyticsTrendChart> createState() => _AnalyticsTrendChartState();
}

class _AnalyticsTrendChartState extends State<AnalyticsTrendChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'No historical trend data',
            style: TextStyle(
              fontSize: 12,
              color: widget.isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            ),
          ),
        ),
      );
    }

    final effectiveColor = widget.lineColor ?? (widget.isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary);
    final textMuted = widget.isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.baselineY != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 14, height: 1.5, color: AppTheme.warning),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.baselineLabel ?? 'Target (${widget.baselineY!.toStringAsFixed(0)}${widget.valueSuffix})',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.warning),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, widget.height);
              return ClipRect(
                child: Stack(
                children: [
                  CustomPaint(
                    size: size,
                    painter: _TrendPainter(
                      points: widget.points,
                      minY: widget.minY,
                      maxY: widget.maxY,
                      baselineY: widget.baselineY,
                      lineColor: effectiveColor,
                      isDark: widget.isDark,
                      showArea: widget.showArea,
                      hoveredIndex: _hoveredIndex,
                    ),
                  ),
                  if (widget.showDots && widget.points.length > 1)
                    ...List.generate(widget.points.length, (i) {
                      final p = widget.points[i];
                      final minVal = widget.minY ?? widget.points.map((e) => e.value).reduce(math.min);
                      final maxVal = widget.maxY ?? widget.points.map((e) => e.value).reduce(math.max);
                      final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);
                      
                      const paddingX = 16.0;
                      const paddingY = 16.0;
                      final usableWidth = size.width - (paddingX * 2);
                      final usableHeight = size.height - (paddingY * 2) - 20;

                      final stepX = usableWidth / (widget.points.length - 1);
                      final x = paddingX + (i * stepX);
                      final normY = (p.value - minVal) / range;
                      final y = paddingY + usableHeight - (normY * usableHeight);

                      final isHovered = _hoveredIndex == i;

                      return Positioned(
                        left: x - 14,
                        top: y - 14,
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = i),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          cursor: SystemMouseCursors.click,
                          child: Tooltip(
                            message: '${p.label}: ${p.value.toStringAsFixed(1)}${widget.valueSuffix}',
                            child: Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              color: Colors.transparent,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: isHovered ? 12 : 7,
                                height: isHovered ? 12 : 7,
                                decoration: BoxDecoration(
                                  color: isHovered ? Colors.white : effectiveColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: effectiveColor,
                                    width: isHovered ? 3.0 : 1.5,
                                  ),
                                  boxShadow: isHovered
                                      ? [
                                          BoxShadow(
                                            color: effectiveColor.withValues(alpha: 0.5),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
              );
            },
          ),
        ),
        // X-Axis Labels Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final showMiddle = w >= 150 && widget.points.length > 2;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      widget.points.first.label,
                      style: TextStyle(fontSize: 10, color: textMuted),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (showMiddle)
                    Flexible(
                      child: Text(
                        widget.points[(widget.points.length / 2).floor()].label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: textMuted),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  Flexible(
                    child: Text(
                      widget.points.last.label,
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 10, color: textMuted),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> points;
  final double? minY;
  final double? maxY;
  final double? baselineY;
  final Color lineColor;
  final bool isDark;
  final bool showArea;
  final int? hoveredIndex;

  _TrendPainter({
    required this.points,
    required this.minY,
    required this.maxY,
    required this.baselineY,
    required this.lineColor,
    required this.isDark,
    required this.showArea,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minVal = minY ?? points.map((e) => e.value).reduce(math.min);
    final maxVal = maxY ?? points.map((e) => e.value).reduce(math.max);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    const paddingX = 16.0;
    const paddingY = 16.0;
    final usableWidth = size.width - (paddingX * 2);
    final usableHeight = size.height - (paddingY * 2) - 20;

    final stepX = usableWidth / (points.length - 1);

    // Compute pixel offsets
    final offsets = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = paddingX + (i * stepX);
      final normY = (points[i].value - minVal) / range;
      final y = paddingY + usableHeight - (normY * usableHeight);
      offsets.add(Offset(x, y));
    }

    // 1. Draw Baseline Target Line if present
    if (baselineY != null) {
      final normBase = (baselineY! - minVal) / range;
      final baseY = paddingY + usableHeight - (normBase * usableHeight);
      final basePaint = Paint()
        ..color = AppTheme.warning.withValues(alpha: 0.5)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      // Draw dashed line
      const dashWidth = 5.0;
      const dashSpace = 4.0;
      double startX = paddingX;
      while (startX < size.width - paddingX) {
        canvas.drawLine(
          Offset(startX, baseY),
          Offset(math.min(startX + dashWidth, size.width - paddingX), baseY),
          basePaint,
        );
        startX += dashWidth + dashSpace;
      }
    }

    // 2. Build Smooth Curve Path
    final path = Path();
    path.moveTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    // 3. Draw Gradient Fill Under Curve
    if (showArea) {
      final fillPath = Path.from(path);
      fillPath.lineTo(offsets.last.dx, paddingY + usableHeight);
      fillPath.lineTo(offsets.first.dx, paddingY + usableHeight);
      fillPath.close();

      final areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.28),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, areaPaint);
    }

    // 4. Draw Main Line Stroke
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => true;
}
