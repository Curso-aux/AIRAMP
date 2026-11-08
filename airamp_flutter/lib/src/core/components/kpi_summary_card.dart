import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class KpiSummaryCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? trendText;
  final bool isPositiveTrend;
  final double? progress;
  final String? badgeText;
  final List<double>? sparklineData;
  final VoidCallback? onTap;
  final bool? isDark;
  final bool compact;

  const KpiSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.trendText,
    this.isPositiveTrend = true,
    this.progress,
    this.badgeText,
    this.sparklineData,
    this.onTap,
    this.isDark,
    this.compact = false,
  });

  @override
  State<KpiSummaryCard> createState() => _KpiSummaryCardState();
}

class _KpiSummaryCardState extends State<KpiSummaryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark = widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final cardColor = effectiveIsDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = effectiveIsDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    final trendColor = widget.isPositiveTrend ? AppTheme.success : AppTheme.error;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.all(widget.compact ? 12 : 18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? (effectiveIsDark ? const Color(0xFF33455E) : const Color(0xFF94A3B8))
                  : borderColor,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: effectiveIsDark ? 0.2 : 0.04),
                blurRadius: _isHovered ? 6 : 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Header Row: Title + Icon Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: widget.compact ? 11.5 : 12.5,
                            fontWeight: FontWeight.w600,
                            color: effectiveIsDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.badgeText != null) ...[
                          SizedBox(height: widget.compact ? 2 : 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 4 : 6, vertical: widget.compact ? 1.5 : 2),
                            decoration: BoxDecoration(
                              color: effectiveIsDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: effectiveIsDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              widget.badgeText!,
                              style: TextStyle(
                                fontSize: widget.compact ? 9.5 : 10,
                                fontWeight: FontWeight.w600,
                                color: effectiveIsDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.all(widget.compact ? 5 : 8),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: effectiveIsDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(widget.compact ? 6 : 8),
                      border: Border.all(
                        color: widget.color.withValues(alpha: effectiveIsDark ? 0.22 : 0.15),
                      ),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: widget.compact ? 15 : 18),
                  ),
                ],
              ),
              SizedBox(height: widget.compact ? 6 : 12),

              // Main Metric Value
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: widget.compact ? 21 : 26,
                  fontWeight: FontWeight.w700,
                  color: effectiveIsDark ? AppTheme.darkText : AppTheme.lightText,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: widget.compact ? 4 : 6),

              // Trend Badge & Subtitle
              Row(
                children: [
                  if (widget.trendText != null) ...[
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: widget.compact ? 5 : 6, vertical: widget.compact ? 1.5 : 2),
                        decoration: BoxDecoration(
                          color: trendColor.withValues(alpha: effectiveIsDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: trendColor.withValues(alpha: effectiveIsDark ? 0.25 : 0.18),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isPositiveTrend ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                              size: widget.compact ? 10 : 12,
                              color: trendColor,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                widget.trendText!,
                                style: TextStyle(
                                  fontSize: widget.compact ? 9.5 : 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: trendColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!widget.compact || widget.trendText == null) const SizedBox(width: 6),
                  ],
                  if (!widget.compact || widget.trendText == null)
                    Expanded(
                      child: Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: widget.compact ? 10 : 11.5,
                          color: effectiveIsDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),

              // Mini Progress Bar or Sparkline Track
              if (widget.progress != null) ...[
                SizedBox(height: widget.compact ? 8 : 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(widget.compact ? 2.5 : 4),
                  child: Stack(
                    children: [
                      Container(
                        height: widget.compact ? 3.5 : 5,
                        width: double.infinity,
                        color: effectiveIsDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      ),
                      FractionallySizedBox(
                        widthFactor: widget.progress!.clamp(0.0, 1.0),
                        child: Container(
                          height: widget.compact ? 3.5 : 5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                widget.color.withValues(alpha: 0.7),
                                widget.color,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(widget.compact ? 2.5 : 4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (widget.sparklineData != null && widget.sparklineData!.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 16,
                  child: CustomPaint(
                    painter: _MiniSparklinePainter(
                      data: widget.sparklineData!,
                      color: widget.color,
                      isDark: effectiveIsDark,
                    ),
                    size: const Size(double.infinity, 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool isDark;

  const _MiniSparklinePainter({
    required this.data,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: isDark ? 0.35 : 0.2),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalized = (data[i] - minVal) / range;
      final y = size.height - (normalized * (size.height - 4)) - 2;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      if (i == data.length - 1) {
        fillPath.lineTo(x, size.height);
        fillPath.close();
      }
    }

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) => true;
}
