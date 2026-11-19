import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class BarChartItem {
  final String label;
  final double value;
  final double? secondaryValue;
  final Color? color;
  final Color? secondaryColor;
  final String? tooltip;

  const BarChartItem({
    required this.label,
    required this.value,
    this.secondaryValue,
    this.color,
    this.secondaryColor,
    this.tooltip,
  });
}

class AnalyticsBarChart extends StatefulWidget {
  final List<BarChartItem> items;
  final double? maxValue;
  final double? baselineValue;
  final String? baselineLabel;
  final double height;
  final bool isDark;
  final String? valueSuffix;
  final bool showValues;
  final Color? primaryBarColor;
  final Color? secondaryBarColor;
  final String? legend;
  final String? secondaryLegend;

  const AnalyticsBarChart({
    super.key,
    required this.items,
    this.maxValue,
    this.baselineValue,
    this.baselineLabel,
    this.height = 160.0,
    required this.isDark,
    this.valueSuffix = '%',
    this.showValues = true,
    this.primaryBarColor,
    this.secondaryBarColor,
    this.legend,
    this.secondaryLegend,
  });

  @override
  State<AnalyticsBarChart> createState() => _AnalyticsBarChartState();
}

class _AnalyticsBarChartState extends State<AnalyticsBarChart> {
  int? _hoveredIndex;

  double _computeEffectiveMax() {
    if (widget.items.isEmpty) return 100.0;
    final maxDataVal = widget.items.map((e) {
      if (e.secondaryValue != null) {
        return math.max(e.value, e.secondaryValue!);
      }
      return e.value;
    }).reduce(math.max);

    if (widget.maxValue != null && widget.maxValue! > 0) {
      // If user specified a max value and data exceeds it, scale up
      return math.max(widget.maxValue!, maxDataVal * 1.15);
    }

    // Auto-scale intelligently
    final compareBase = math.max(maxDataVal, widget.baselineValue ?? 0.0);
    if (compareBase <= 0) return 10.0;
    if (compareBase <= 5) return 6.0;
    if (compareBase <= 10) return 12.0;
    if (compareBase <= 25) return 30.0;
    if (compareBase <= 50) return 60.0;
    if (compareBase <= 100) return 100.0;
    return (compareBase * 1.2).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'No comparative data available',
            style: TextStyle(
              fontSize: 12,
              color: widget.isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            ),
          ),
        ),
      );
    }

    final effectiveMax = _computeEffectiveMax();
    final defaultPrimary = widget.primaryBarColor ?? (widget.isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary);
    final defaultSecondary = widget.secondaryBarColor ?? (widget.isDark ? AppTheme.darkAccent : AppTheme.lightAccent);
    final trackColor = widget.isDark ? AppTheme.darkBorder.withValues(alpha: 0.35) : AppTheme.lightBorder.withValues(alpha: 0.5);
    final textColor = widget.isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final gridLineColor = widget.isDark ? AppTheme.darkBorder.withValues(alpha: 0.3) : AppTheme.lightBorder.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.legend != null || widget.baselineValue != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.legend != null)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: defaultPrimary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.legend!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (widget.secondaryLegend != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: defaultSecondary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.secondaryLegend!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (widget.baselineValue != null)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppTheme.warning,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.baselineLabel ?? 'Target: ${widget.baselineValue!.toStringAsFixed(0)}${widget.valueSuffix ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalItems = widget.items.length;
              final availableWidth = constraints.maxWidth;
              final isFewItems = totalItems <= 3;

              final barThickness = isFewItems
                  ? math.min((availableWidth / (totalItems + 1)) * 0.42, 44.0)
                  : math.min((availableWidth / totalItems) * 0.48, 32.0);

              return ClipRect(
                child: Stack(
                  children: [
                    // 1. Subtle horizontal background gridlines (25%, 50%, 75%, 100%)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 26, top: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(4, (index) {
                            return Container(
                              height: 1,
                              color: gridLineColor,
                            );
                          }),
                        ),
                      ),
                    ),

                    // 2. Baseline line at target if defined
                    if (widget.baselineValue != null && effectiveMax > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 26 + ((widget.height - 48.0) * (widget.baselineValue! / effectiveMax).clamp(0.0, 1.0)),
                        child: Container(
                          height: 1.5,
                          color: AppTheme.warning.withValues(alpha: 0.55),
                        ),
                      ),

                    // 3. Bars Row (Using Expanded on each column and on bar track to mathematically eliminate all overflows)
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(totalItems, (i) {
                          final item = widget.items[i];
                          final isHovered = _hoveredIndex == i;
                          final clampedVal = item.value.clamp(0.0, effectiveMax);
                          final pct = effectiveMax > 0 ? (clampedVal / effectiveMax).clamp(0.02, 1.0) : 0.02;

                          final activeColor = item.color ?? defaultPrimary;
                          final hasSecondary = item.secondaryValue != null;
                          final secVal = (item.secondaryValue ?? 0.0).clamp(0.0, effectiveMax);
                          final secPct = effectiveMax > 0 ? (secVal / effectiveMax).clamp(0.02, 1.0) : 0.02;
                          final secActiveColor = item.secondaryColor ?? defaultSecondary;

                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: isFewItems ? 8.0 : 3.0),
                              child: MouseRegion(
                                onEnter: (_) => setState(() => _hoveredIndex = i),
                                onExit: (_) => setState(() => _hoveredIndex = null),
                                cursor: SystemMouseCursors.click,
                                child: Tooltip(
                                  message: item.tooltip ??
                                      (hasSecondary
                                          ? '${item.label}: ${item.value.toStringAsFixed(0)} / ${item.secondaryValue!.toStringAsFixed(0)}'
                                          : '${item.label}: ${item.value.toStringAsFixed(1)}${widget.valueSuffix ?? ''}'),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Top Value Badge
                                      if (widget.showValues) ...[
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isHovered
                                                ? activeColor.withValues(alpha: 0.16)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '${item.value.toStringAsFixed(0)}${widget.valueSuffix ?? ''}',
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: isHovered ? 11.5 : 10.5,
                                                fontWeight: isHovered ? FontWeight.bold : FontWeight.w700,
                                                color: isHovered
                                                    ? (widget.isDark ? AppTheme.darkTextBright : AppTheme.lightTextBright)
                                                    : (item.color ?? textColor),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                      ],

                                      // Bar Track & Animated Bar(s) - Expanded so it CAN NEVER overflow on bottom
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: !hasSecondary
                                              ? Container(
                                                  width: barThickness,
                                                  alignment: Alignment.bottomCenter,
                                                  decoration: BoxDecoration(
                                                    color: trackColor,
                                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                                  ),
                                                  child: FractionallySizedBox(
                                                    heightFactor: pct,
                                                    alignment: Alignment.bottomCenter,
                                                    child: Container(
                                                      width: double.infinity,
                                                      decoration: BoxDecoration(
                                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                                        gradient: LinearGradient(
                                                          begin: Alignment.bottomCenter,
                                                          end: Alignment.topCenter,
                                                          colors: [
                                                            activeColor.withValues(alpha: isHovered ? 0.95 : 0.80),
                                                            activeColor,
                                                          ],
                                                        ),
                                                        boxShadow: isHovered
                                                            ? [
                                                                BoxShadow(
                                                                  color: activeColor.withValues(alpha: 0.4),
                                                                  blurRadius: 10,
                                                                  offset: const Offset(0, 2),
                                                                ),
                                                              ]
                                                            : null,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    // Primary Bar
                                                    Container(
                                                      width: barThickness * 0.48,
                                                      alignment: Alignment.bottomCenter,
                                                      decoration: BoxDecoration(
                                                        color: trackColor,
                                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                                      ),
                                                      child: FractionallySizedBox(
                                                        heightFactor: pct,
                                                        alignment: Alignment.bottomCenter,
                                                        child: Container(
                                                          width: double.infinity,
                                                          decoration: BoxDecoration(
                                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                                            gradient: LinearGradient(
                                                              begin: Alignment.bottomCenter,
                                                              end: Alignment.topCenter,
                                                              colors: [
                                                                activeColor.withValues(alpha: 0.8),
                                                                activeColor,
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    // Secondary Bar
                                                    Container(
                                                      width: barThickness * 0.48,
                                                      alignment: Alignment.bottomCenter,
                                                      decoration: BoxDecoration(
                                                        color: trackColor,
                                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                                      ),
                                                      child: FractionallySizedBox(
                                                        heightFactor: secPct,
                                                        alignment: Alignment.bottomCenter,
                                                        child: Container(
                                                          width: double.infinity,
                                                          decoration: BoxDecoration(
                                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                                            gradient: LinearGradient(
                                                              begin: Alignment.bottomCenter,
                                                              end: Alignment.topCenter,
                                                              colors: [
                                                                secActiveColor.withValues(alpha: 0.8),
                                                                secActiveColor,
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),

                                      const SizedBox(height: 5),
                                      // X-Axis Label Pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isHovered
                                              ? (widget.isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade200)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: isHovered ? FontWeight.bold : FontWeight.w600,
                                            color: isHovered
                                                ? (widget.isDark ? AppTheme.darkTextBright : AppTheme.lightTextBright)
                                                : textColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
      ],
    );
  }
}
