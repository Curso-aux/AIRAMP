import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/theme_provider.dart';
import '../../../data/admin_repository.dart';

/// Compact, responsive filter bar & collapsible popover panel for School Analytics.
/// Supports multi-dimensional combinable filters (Subject, Class Section, Date Timeframe, Student Category).
/// Automatically adapts to mobile / narrow screens via a Modal Bottom Sheet.
class AnalyticsFilterBar extends ConsumerStatefulWidget {
  const AnalyticsFilterBar({super.key});

  @override
  ConsumerState<AnalyticsFilterBar> createState() => _AnalyticsFilterBarState();
}

class _AnalyticsFilterBarState extends ConsumerState<AnalyticsFilterBar> {
  bool _isPanelOpen = false;

  static const List<Map<String, String>> _timeframeOptions = [
    {'value': 'all', 'label': 'All Time'},
    {'value': 'today', 'label': 'Today'},
    {'value': '7days', 'label': 'Past 7 Days'},
    {'value': '30days', 'label': 'Past 30 Days'},
    {'value': 'this_month', 'label': 'This Month'},
  ];

  static const List<Map<String, String>> _categoryOptions = [
    {'value': 'all', 'label': 'All Categories / Roles'},
    {'value': 'regular', 'label': 'Regular Students'},
    {'value': 'irregular', 'label': 'Irregular / Cross-Enrollees'},
    {'value': 'transferee', 'label': 'Transferees'},
    {'value': 'sped', 'label': 'SPED / Accommodations'},
    {'value': 'unassigned', 'label': 'Unassigned Section'},
  ];

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filter = ref.watch(analyticsFilterProvider);
    final subjects = ref.watch(subjectsProvider);
    final sections = ref.watch(sectionsProvider);
    final isMobile = MediaQuery.of(context).size.width < 680;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: filter.hasActiveFilters
              ? AppTheme.primary.withValues(alpha: 0.5)
              : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Compact Header Strip ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    // Main Filter Trigger Button
                    InkWell(
                      onTap: () {
                        if (isMobile) {
                          _openMobileFilterSheet(context, filter, subjects, sections, isDark);
                        } else {
                          setState(() => _isPanelOpen = !_isPanelOpen);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: filter.hasActiveFilters
                              ? AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                              : (isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: filter.hasActiveFilters
                                ? AppTheme.primary
                                : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 16,
                              color: filter.hasActiveFilters
                                  ? AppTheme.primary
                                  : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isMobile ? 'Filters' : 'Filter Analytics',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: filter.hasActiveFilters
                                    ? AppTheme.primary
                                    : (isDark ? AppTheme.darkText : AppTheme.lightText),
                              ),
                            ),
                            if (filter.hasActiveFilters) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${filter.activeFilterCount}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Icon(
                              _isPanelOpen && !isMobile
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Quick Timeframe Presets or Active Chips (Desktop only if enough width)
                    if (constraints.maxWidth > 520) ...[
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildQuickTimeframeChip('all', 'All Time', filter.timeframe, isDark),
                              const SizedBox(width: 6),
                              _buildQuickTimeframeChip('7days', '7 Days', filter.timeframe, isDark),
                              const SizedBox(width: 6),
                              _buildQuickTimeframeChip('30days', '30 Days', filter.timeframe, isDark),
                              const SizedBox(width: 6),
                              _buildQuickTimeframeChip('this_month', 'This Month', filter.timeframe, isDark),

                              if (filter.subjectName != null) ...[
                                const SizedBox(width: 8),
                                _buildActiveRemovableChip(
                                  label: 'Subject: ${filter.subjectName}',
                                  onRemove: () => ref.read(analyticsFilterProvider.notifier).updateSubject(null, null),
                                  isDark: isDark,
                                ),
                              ],
                              if (filter.section != null && filter.section != 'All Sections') ...[
                                const SizedBox(width: 8),
                                _buildActiveRemovableChip(
                                  label: 'Section: ${filter.section}',
                                  onRemove: () => ref.read(analyticsFilterProvider.notifier).updateSection(null),
                                  isDark: isDark,
                                ),
                              ],
                              if (filter.category != 'all') ...[
                                const SizedBox(width: 8),
                                _buildActiveRemovableChip(
                                  label: 'Category: ${_getCategoryLabel(filter.category)}',
                                  onRemove: () => ref.read(analyticsFilterProvider.notifier).updateCategory('all'),
                                  isDark: isDark,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),

                    // Reset All Button
                    if (filter.hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          ref.read(analyticsFilterProvider.notifier).reset();
                        },
                        icon: const Icon(Icons.restart_alt, size: 14),
                        label: const Text('Reset', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          // ── Collapsible Detailed Filter Panel (Desktop / Tablet) ──────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _isPanelOpen && !isMobile
                ? Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBackground.withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.filter_alt_outlined, size: 16, color: AppTheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Filter Dimensions (Combinable via AND Logic)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => setState(() => _isPanelOpen = false),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(Icons.close, size: 16, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Responsive 4-Column Dropdown Selectors Grid
                        LayoutBuilder(
                          builder: (context, boxConstraints) {
                            final isWide = boxConstraints.maxWidth > 750;
                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildSubjectSelector(filter, subjects, isDark)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildSectionSelector(filter, sections, isDark)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildTimeframeSelector(filter, isDark)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildCategorySelector(filter, isDark)),
                                ],
                              );
                            }

                            // 2x2 grid for mid-width
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildSubjectSelector(filter, subjects, isDark)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildSectionSelector(filter, sections, isDark)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _buildTimeframeSelector(filter, isDark)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildCategorySelector(filter, isDark)),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        // Bottom Actions Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              filter.hasActiveFilters
                                  ? 'Active criteria: ${filter.activeFilterCount} applied'
                                  : 'Showing all unfiltered school records',
                              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                            ),
                            Row(
                              children: [
                                if (filter.hasActiveFilters)
                                  OutlinedButton(
                                    onPressed: () => ref.read(analyticsFilterProvider.notifier).reset(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                      side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      minimumSize: const Size(0, 32),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Reset All', style: TextStyle(fontSize: 12)),
                                  ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => setState(() => _isPanelOpen = false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Done', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Quick Presets & Removable Chips ─────────────────────────────
  Widget _buildQuickTimeframeChip(String key, String label, String current, bool isDark) {
    final isSelected = key == current;
    return InkWell(
      onTap: () => ref.read(analyticsFilterProvider.notifier).updateTimeframe(key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.primary.withValues(alpha: 0.12))
              : (isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (isDark ? AppTheme.primary : AppTheme.primaryDark)
                : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveRemovableChip({required String label, required VoidCallback onRemove, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFBAE6FD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.accent : const Color(0xFF0369A1)),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(8),
            child: Icon(Icons.close, size: 14, color: isDark ? AppTheme.accent : const Color(0xFF0369A1)),
          ),
        ],
      ),
    );
  }

  // ── Dimensional Selectors ───────────────────────────────────────
  Widget _buildSubjectSelector(AnalyticsFilter filter, List<Map<String, dynamic>> subjects, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceLight : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: filter.subjectId != null ? AppTheme.primary : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              isExpanded: true,
              value: filter.subjectId,
              dropdownColor: isDark ? AppTheme.darkSurfaceLight : Colors.white,
              icon: Icon(Icons.arrow_drop_down, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, size: 20),
              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkText : AppTheme.lightText),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All Subjects', style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                ),
                ...subjects.map((s) {
                  final id = s['id'] as int;
                  final code = s['subject_code'] as String? ?? '';
                  final name = s['name'] as String? ?? 'Subject';
                  final label = code.isNotEmpty ? '$code · $name' : name;
                  return DropdownMenuItem<int?>(
                    value: id,
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                }),
              ],
              onChanged: (val) {
                if (val == null) {
                  ref.read(analyticsFilterProvider.notifier).updateSubject(null, null);
                } else {
                  final found = subjects.firstWhere((s) => s['id'] == val, orElse: () => {});
                  final code = found['subject_code'] as String? ?? '';
                  final name = found['name'] as String? ?? '';
                  ref.read(analyticsFilterProvider.notifier).updateSubject(val, code.isNotEmpty ? code : name);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionSelector(AnalyticsFilter filter, List<Map<String, dynamic>> sections, bool isDark) {
    final activeSection = filter.section;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Class Section', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceLight : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: (activeSection != null && activeSection != 'All Sections') ? AppTheme.primary : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: activeSection,
              dropdownColor: isDark ? AppTheme.darkSurfaceLight : Colors.white,
              icon: Icon(Icons.arrow_drop_down, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, size: 20),
              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkText : AppTheme.lightText),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Sections', style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                ),
                const DropdownMenuItem<String?>(
                  value: 'Unassigned',
                  child: Text('Unassigned Section'),
                ),
                ...sections.map((sec) {
                  final name = sec['name'] as String? ?? 'Section';
                  final grade = sec['grade'] as String? ?? '';
                  final label = grade.isNotEmpty ? '$grade - $name' : name;
                  return DropdownMenuItem<String?>(
                    value: name,
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                }),
              ],
              onChanged: (val) {
                ref.read(analyticsFilterProvider.notifier).updateSection(val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeframeSelector(AnalyticsFilter filter, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date Range', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceLight : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: filter.timeframe != 'all' ? AppTheme.primary : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: filter.timeframe,
              dropdownColor: isDark ? AppTheme.darkSurfaceLight : Colors.white,
              icon: Icon(Icons.arrow_drop_down, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, size: 20),
              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkText : AppTheme.lightText),
              items: _timeframeOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt['value']!,
                  child: Text(opt['label']!, maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref.read(analyticsFilterProvider.notifier).updateTimeframe(val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector(AnalyticsFilter filter, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Student Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceLight : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: filter.category != 'all' ? AppTheme.primary : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: filter.category,
              dropdownColor: isDark ? AppTheme.darkSurfaceLight : Colors.white,
              icon: Icon(Icons.arrow_drop_down, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, size: 20),
              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkText : AppTheme.lightText),
              items: _categoryOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt['value']!,
                  child: Text(opt['label']!, maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref.read(analyticsFilterProvider.notifier).updateCategory(val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  String _getCategoryLabel(String key) {
    final found = _categoryOptions.firstWhere((o) => o['value'] == key, orElse: () => {'label': key});
    return found['label']!;
  }

  // ── Mobile Responsive Modal Bottom Sheet ──────────────────────
  void _openMobileFilterSheet(
    BuildContext context,
    AnalyticsFilter filter,
    List<Map<String, dynamic>> subjects,
    List<Map<String, dynamic>> sections,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final curFilter = ref.watch(analyticsFilterProvider);
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Analytics Filters',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkText : AppTheme.lightText),
                        ),
                        if (curFilter.hasActiveFilters)
                          TextButton(
                            onPressed: () {
                              ref.read(analyticsFilterProvider.notifier).reset();
                            },
                            child: Text('Reset All', style: TextStyle(color: AppTheme.error, fontSize: 13)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSubjectSelector(curFilter, subjects, isDark),
                    const SizedBox(height: 16),
                    _buildSectionSelector(curFilter, sections, isDark),
                    const SizedBox(height: 16),
                    _buildTimeframeSelector(curFilter, isDark),
                    const SizedBox(height: 16),
                    _buildCategorySelector(curFilter, isDark),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Apply & Close', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
