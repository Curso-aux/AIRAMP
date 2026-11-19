import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import 'analytics_demo_engine.dart';

class AnalyticsDemoControlBar extends ConsumerStatefulWidget {
  final bool showCampusFilter;
  final bool showSectionFilter;
  final bool showSubjectFilter;
  final VoidCallback? onReset;

  const AnalyticsDemoControlBar({
    super.key,
    this.showCampusFilter = true,
    this.showSectionFilter = false,
    this.showSubjectFilter = false,
    this.onReset,
  });

  @override
  ConsumerState<AnalyticsDemoControlBar> createState() => _AnalyticsDemoControlBarState();
}

class _AnalyticsDemoControlBarState extends ConsumerState<AnalyticsDemoControlBar> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(analyticsDemoFilterProvider);
    final notifier = ref.read(analyticsDemoFilterProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textColor = isDark ? AppTheme.darkText : AppTheme.lightText;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Toggle & Scenario Indicator
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 480;
                  final isTiny = constraints.maxWidth < 360;

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF0D9488)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                isNarrow ? 'Demo Sandbox' : 'Interactive Analytics Sandbox',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isTiny) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    filter.scenario.label,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0284C7),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          notifier.reset();
                          widget.onReset?.call();
                        },
                        tooltip: 'Reset to Defaults',
                        icon: Icon(Icons.refresh_rounded, size: 16, color: textMuted),
                        visualDensity: VisualDensity.compact,
                      ),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: textMuted,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Collapsible Controls Body
          if (_isExpanded) ...[
            Divider(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // 1. Scenario Selector
                  _buildDropdown<DemoScenario>(
                    label: 'Simulation Scenario',
                    value: filter.scenario,
                    items: DemoScenario.values.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(s.label, style: const TextStyle(fontSize: 12.5)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) notifier.setScenario(val);
                    },
                    isDark: isDark,
                  ),

                  // 2. Academic Year Selector
                  _buildDropdown<String>(
                    label: 'Academic Year',
                    value: filter.academicYear,
                    items: const [
                      DropdownMenuItem(value: 'AY 2025-2026', child: Text('AY 2025-2026', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'AY 2024-2025', child: Text('AY 2024-2025', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'All Years', child: Text('All Years', style: TextStyle(fontSize: 12.5))),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.setYear(val);
                    },
                    isDark: isDark,
                  ),

                  // 3. Month Selector
                  _buildDropdown<String>(
                    label: 'Month',
                    value: filter.month,
                    items: const [
                      DropdownMenuItem(value: 'All Months', child: Text('All Months', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'January', child: Text('January', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'February', child: Text('February', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'March', child: Text('March', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'April', child: Text('April', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'May', child: Text('May', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'June', child: Text('June', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'July', child: Text('July', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'August', child: Text('August', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'September', child: Text('September', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'October', child: Text('October', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'November', child: Text('November', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'December', child: Text('December', style: TextStyle(fontSize: 12.5))),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.setMonth(val);
                    },
                    isDark: isDark,
                  ),

                  // 4. Campus Filter (if enabled)
                  if (widget.showCampusFilter)
                    _buildDropdown<String>(
                      label: 'Campus Scope',
                      value: filter.campusId,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Campuses (Fleet)', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: 'sch_main', child: Text('Main Campus', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: 'sch_north', child: Text('North Campus', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: 'sch_west', child: Text('West Branch', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: 'sch_south', child: Text('South Extension', style: TextStyle(fontSize: 12.5))),
                      ],
                      onChanged: (val) {
                        if (val != null) notifier.setCampus(val);
                      },
                      isDark: isDark,
                    ),

                  // 5. Section Filter (if enabled)
                  if (widget.showSectionFilter)
                    _buildDropdown<String>(
                      label: 'Class Section',
                      value: filter.section,
                      items: const [
                        DropdownMenuItem(value: 'All Handled Sections', child: Text('All Sections', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: '10-Einstein', child: Text('10 - Einstein', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: '10-Newton', child: Text('10 - Newton', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: '10-Curie', child: Text('10 - Curie', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: '10-Tesla', child: Text('10 - Tesla', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: '10-Darwin', child: Text('10 - Darwin', style: TextStyle(fontSize: 12.5))),
                      ],
                      onChanged: (val) {
                        if (val != null) notifier.setSection(val);
                      },
                      isDark: isDark,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
  }) {
    final surfaceColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              icon: const Icon(Icons.arrow_drop_down, size: 18),
              dropdownColor: surfaceColor,
              borderRadius: BorderRadius.circular(8),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
