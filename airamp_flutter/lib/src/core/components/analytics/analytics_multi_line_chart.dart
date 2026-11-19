import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'analytics_trend_chart.dart';

class LineSeries {
  final String name;
  final Color color;
  final List<TrendPoint> points;
  final bool showArea;

  const LineSeries({
    required this.name,
    required this.color,
    required this.points,
    this.showArea = false,
  });
}

class AnalyticsMultiLineChart extends StatefulWidget {
  final List<LineSeries> series;
  final double? minY;
  final double? maxY;
  final double? baselineY;
  final String? baselineLabel;
  final double height;
  final bool isDark;
  final String valueSuffix;
  final bool showDots;

  const AnalyticsMultiLineChart({
    super.key,
    required this.series,
    this.minY,
    this.maxY,
    this.baselineY,
    this.baselineLabel,
    this.height = 180.0,
    required this.isDark,
    this.valueSuffix = '',
    this.showDots = true,
  });

  @override
  State<AnalyticsMultiLineChart> createState() =>
      _AnalyticsMultiLineChartState();
}

class _AnalyticsMultiLineChartState extends State<AnalyticsMultiLineChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.series.isEmpty || widget.series.every((s) => s.points.isEmpty)) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'No historical multi-series trend data available',
            style: TextStyle(
              fontSize: 12,
              color: widget.isDark
                  ? AppTheme.darkTextMuted
                  : AppTheme.lightTextMuted,
            ),
          ),
        ),
      );
    }

    // Defensive normalization: if any series has only 1 point, synthesize a companion point so trend lines render
    final List<LineSeries> effectiveSeries = widget.series.map<LineSeries>((s) {
      if (s.points.length == 1) {
        final p = s.points.first;
        return LineSeries(
          name: s.name,
          color: s.color,
          showArea: s.showArea,
          points: [
            TrendPoint(label: '${p.label} (W1)', value: p.value),
            TrendPoint(label: '${p.label} (W4)', value: p.value),
          ],
        );
      }
      return s;
    }).toList();

    // Determine max points length
    final maxLen = effectiveSeries.fold<int>(0, (prev, s) => math.max(prev, s.points.length));
    if (maxLen < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'No historical data available for selected filter',
            style: TextStyle(
              fontSize: 12,
              color: widget.isDark
                  ? AppTheme.darkTextMuted
                  : AppTheme.lightTextMuted,
            ),
          ),
        ),
      );
    }

    final textColor = widget.isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final textMuted = widget.isDark
        ? AppTheme.darkTextMuted
        : AppTheme.lightTextMuted;

    // Use labels from the series that has the most points
    final primarySeries = effectiveSeries.firstWhere(
      (s) => s.points.length == maxLen,
      orElse: () => effectiveSeries.first,
    );
    final labels = primarySeries.points.map((p) => p.label).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Legend & Baseline Header Row
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: effectiveSeries.map((s) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 3,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              if (widget.baselineY != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 14, height: 1.5, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    Text(
                      widget.baselineLabel ??
                          'Target (${widget.baselineY!.toStringAsFixed(0)}${widget.valueSuffix})',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Main Chart Canvas & Overlay Touch/Hover
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
                      painter: _MultiTrendPainter(
                        series: effectiveSeries,
                        minY: widget.minY,
                        maxY: widget.maxY,
                        baselineY: widget.baselineY,
                        isDark: widget.isDark,
                        hoveredIndex: _hoveredIndex,
                      ),
                    ),

                    // Interactive touch / hover column zones
                    Positioned.fill(
                      child: Row(
                        children: List.generate(maxLen, (i) {
                          final pointLabel = i < labels.length
                              ? labels[i]
                              : 'T-$i';
                          final tooltipItems = effectiveSeries
                              .where((s) => i < s.points.length)
                              .map((s) {
                                final val = s.points[i].value;
                                final valStr = val % 1 == 0
                                    ? val.toInt().toString()
                                    : val.toStringAsFixed(1);
                                return '${s.name}: $valStr${widget.valueSuffix}';
                              })
                              .join(' • ');

                          return Expanded(
                            child: MouseRegion(
                              onEnter: (_) => setState(() => _hoveredIndex = i),
                              onExit: (_) =>
                                  setState(() => _hoveredIndex = null),
                              cursor: SystemMouseCursors.click,
                              child: Tooltip(
                                message: '$pointLabel: $tooltipItems',
                                child: Container(color: Colors.transparent),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
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
              final maxStep = (labels.length > 8 && w < 500) ? 2 : 1;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int idx = 0; idx < labels.length; idx += maxStep)
                    Flexible(
                      child: Text(
                        labels[idx],
                        textAlign: idx == 0
                            ? TextAlign.start
                            : (idx >= labels.length - maxStep
                                  ? TextAlign.end
                                  : TextAlign.center),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: _hoveredIndex == idx
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _hoveredIndex == idx
                              ? (widget.isDark
                                    ? AppTheme.darkTextBright
                                    : AppTheme.lightTextBright)
                              : textMuted,
                        ),
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

class _MultiTrendPainter extends CustomPainter {
  final List<LineSeries> series;
  final double? minY;
  final double? maxY;
  final double? baselineY;
  final bool isDark;
  final int? hoveredIndex;

  _MultiTrendPainter({
    required this.series,
    required this.minY,
    required this.maxY,
    required this.baselineY,
    required this.isDark,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    // 1. Calculate global scale bounds across all series
    double calculatedMin = double.infinity;
    double calculatedMax = -double.infinity;

    for (final s in series) {
      for (final p in s.points) {
        if (p.value < calculatedMin) calculatedMin = p.value;
        if (p.value > calculatedMax) calculatedMax = p.value;
      }
    }

    if (calculatedMin == double.infinity) calculatedMin = 0.0;
    if (calculatedMax == -double.infinity) calculatedMax = 100.0;
    if (baselineY != null) {
      calculatedMin = math.min(calculatedMin, baselineY!);
      calculatedMax = math.max(calculatedMax, baselineY!);
    }

    final effMin =
        minY ?? (calculatedMin > 0 ? (calculatedMin * 0.90) : calculatedMin);
    final effMax = maxY ?? (calculatedMax * 1.10);
    final range = (effMax - effMin) == 0 ? 1.0 : (effMax - effMin);

    const paddingX = 16.0;
    const paddingY = 16.0;
    final usableWidth = size.width - (paddingX * 2);
    final usableHeight = size.height - (paddingY * 2) - 16;

    // 2. Draw subtle background grid lines
    final gridPaint = Paint()
      ..color = (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)
          .withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    for (int g = 0; g <= 3; g++) {
      final y = paddingY + (usableHeight * (g / 3));
      canvas.drawLine(
        Offset(paddingX, y),
        Offset(size.width - paddingX, y),
        gridPaint,
      );
    }

    // 3. Draw baseline target if provided
    if (baselineY != null) {
      final normBase = (baselineY! - effMin) / range;
      final baseY = paddingY + usableHeight - (normBase * usableHeight);
      final basePaint = Paint()
        ..color = AppTheme.warning.withValues(alpha: 0.6)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

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

    // 4. Draw vertical highlight bar if hovered
    if (hoveredIndex != null) {
      final maxLen = series.map((s) => s.points.length).reduce(math.max);
      if (maxLen > 1 && hoveredIndex! < maxLen) {
        final stepX = usableWidth / (maxLen - 1);
        final hoverX = paddingX + (hoveredIndex! * stepX);
        final hoverPaint = Paint()
          ..color = (isDark ? Colors.white : Colors.black).withValues(
            alpha: 0.08,
          )
          ..strokeWidth = 1.5;
        canvas.drawLine(
          Offset(hoverX, paddingY),
          Offset(hoverX, paddingY + usableHeight),
          hoverPaint,
        );
      }
    }

    // 5. Draw each series
    for (final s in series) {
      if (s.points.length < 2) continue;
      final stepX = usableWidth / (s.points.length - 1);
      final offsets = <Offset>[];

      for (int i = 0; i < s.points.length; i++) {
        final x = paddingX + (i * stepX);
        final normY = (s.points[i].value - effMin) / range;
        final y = paddingY + usableHeight - (normY * usableHeight);
        offsets.add(Offset(x, y.clamp(paddingY, paddingY + usableHeight)));
      }

      // Smooth cubic curve path
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

      // Draw gradient area if enabled
      if (s.showArea) {
        final fillPath = Path.from(path);
        fillPath.lineTo(offsets.last.dx, paddingY + usableHeight);
        fillPath.lineTo(offsets.first.dx, paddingY + usableHeight);
        fillPath.close();

        final areaPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              s.color.withValues(alpha: 0.22),
              s.color.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;

        canvas.drawPath(fillPath, areaPaint);
      }

      // Draw line stroke
      final linePaint = Paint()
        ..color = s.color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, linePaint);

      // Draw dots
      final dotPaint = Paint()..style = PaintingStyle.fill;
      for (int i = 0; i < offsets.length; i++) {
        final isHovered = hoveredIndex == i;
        dotPaint.color = isHovered ? Colors.white : s.color;
        canvas.drawCircle(offsets[i], isHovered ? 4.5 : 2.8, dotPaint);

        if (isHovered) {
          final borderPaint = Paint()
            ..color = s.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
          canvas.drawCircle(offsets[i], 4.5, borderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MultiTrendPainter oldDelegate) => true;
}
