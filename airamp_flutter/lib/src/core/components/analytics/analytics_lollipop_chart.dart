import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class LollipopItem {
  final String label;
  final String? subtitle;
  final double value; // 0.0 to 100.0
  final Color color;
  final String? badgeText;

  const LollipopItem({
    required this.label,
    this.subtitle,
    required this.value,
    required this.color,
    this.badgeText,
  });
}

/// A modern horizontal capsule bar chart with glowing circular knob endpoints
/// directly inspired by modern telemetry and cyberpunk analytics aesthetics.
class AnalyticsLollipopChart extends StatelessWidget {
  final List<LollipopItem> items;
  final double maxValue;
  final double? baselineValue;
  final String? baselineLabel;
  final bool isDark;

  const AnalyticsLollipopChart({
    super.key,
    required this.items,
    this.maxValue = 100.0,
    this.baselineValue = 75.0,
    this.baselineLabel = 'Target 75%',
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No subject competencies recorded yet',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            ),
          ),
        ),
      );
    }

    final trackColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppTheme.darkTextBright : AppTheme.lightTextBright;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (baselineValue != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 12,
                  height: 2,
                  color: AppTheme.warning,
                ),
                const SizedBox(width: 5),
                Text(
                  baselineLabel ?? 'Benchmark: ${baselineValue!.round()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  ),
                ),
              ],
            ),
          ),
        ...items.map((item) {
          final clamped = item.value.clamp(0.0, maxValue);
          final pct = maxValue > 0 ? (clamped / maxValue) : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.badgeText != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.badgeText!,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: item.color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      '${item.value.round()}%',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: item.color,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle!,
                    style: TextStyle(
                      fontSize: 10,
                      color: textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                SizedBox(
                  height: 14,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final totalW = constraints.maxWidth;
                      final barW = (totalW * pct).clamp(12.0, totalW);
                      final baselineX = baselineValue != null
                          ? (totalW * (baselineValue! / maxValue)).clamp(0.0, totalW)
                          : null;

                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          // 1. Background Track
                          Container(
                            height: 6,
                            width: totalW,
                            decoration: BoxDecoration(
                              color: trackColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),

                          // 2. Baseline Benchmark Marker (Dashed Tick)
                          if (baselineX != null)
                            Positioned(
                              left: baselineX - 1,
                              top: -2,
                              child: Container(
                                width: 2,
                                height: 10,
                                color: AppTheme.warning.withValues(alpha: 0.7),
                              ),
                            ),

                          // 3. Colored Progress Capsule
                          Container(
                            height: 6,
                            width: barW,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  item.color.withValues(alpha: 0.7),
                                  item.color,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),

                          // 4. Glowing End Knob / Lollipop Pin
                          Positioned(
                            left: barW - 7,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                border: Border.all(color: item.color, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: item.color.withValues(alpha: 0.45),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
