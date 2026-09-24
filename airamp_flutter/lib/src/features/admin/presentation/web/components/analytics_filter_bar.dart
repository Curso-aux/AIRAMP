import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
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
    final filter = ref.watch(analyticsFilterProvider);
    final subjects = ref.watch(subjectsProvider);
    final sections = ref.watch(sectionsProvider);
    final isMobile = MediaQuery.of(context).size.width < 680;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: filter.hasActiveFilters ? AppTheme.primary.withValues(alpha: 0.35) : AppTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                          _openMobileFilterSheet(context, filter, subjects, sections);
                        } else {
                          setState(() => _isPanelOpen = !_isPanelOpen);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: filter.hasActiveFilters
                              ? AppTheme.primary.withValues(alpha: 0.12)
                              : AppTheme.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: filter.hasActiveFilters ? AppTheme.primary : AppTheme.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 16,
                              color: filter.hasActiveFilters ? AppTheme.primary : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isMobile ? 'Filters' : 'Filter Analytics',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: filter.hasActiveFilters ? AppTheme.primary : AppTheme.text,
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
                              color: AppTheme.textSecondary,
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
                              _buildQuickTimeframeChip('all', 'All Time', filter.timeframe),
                              const SizedBox(width: 6),
                              _buildQuickTimeframeChip('7days', '7 Days', filter.timeframe),
                              const SizedBox(width: 6),
                              _buildQuickTimeframeChip('30days', '30 Days', filter.timeframe),
                              const SizedBox(width: 6),
                              _buildQuickTimeframeChip('this_month', 'This Month', filter.timeframe),

                              if (filter.subjectName != null) ...[
                                const SizedBox(width: 8),
                                _buildActiveRemovableChip(
                                  label: 'Subject: ${filter.subjectName}',
                                  onRemove: () => ref.read(analyticsFilterProvider.notifier).updateSubject(null, null),
                                ),
                              ],
                              if (filter.section != null && filter.section != 'All Sections') ...[
                                const SizedBox(width: 8),
                                _buildActiveRemovableChip(
                                  label: 'Section: ${filter.section}',
                                  onRemove: () => ref.read(analyticsFilterProvider.notifier).updateSection(null),
                                ),
                              ],
                              if (filter.category != 'all') ...[
                                const SizedBox(width: 8),
                                _buildActiveRemovableChip(
                                  label: 'Category: ${_getCategoryLabel(filter.category)}',
                                  onRemove: () => ref.read(analyticsFilterProvider.notifier).updateCategory('all'),
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
                      color: AppTheme.background.withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      border: Border(top: BorderSide(color: AppTheme.border)),
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
                                    color: AppTheme.textSecondary,
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
                                child: Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
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
                                  Expanded(child: _buildSubjectSelector(filter, subjects)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildSectionSelector(filter, sections)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildTimeframeSelector(filter)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildCategorySelector(filter)),
                                ],
                              );
                            }

                            // 2x2 grid for mid-width
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildSubjectSelector(filter, subjects)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildSectionSelector(filter, sections)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _buildTimeframeSelector(filter)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildCategorySelector(filter)),
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
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            Row(
                              children: [
                                if (filter.hasActiveFilters)
                                  OutlinedButton(
                                    onPressed: () => ref.read(analyticsFilterProvider.notifier).reset(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.textSecondary,
                                      side: BorderSide(color: AppTheme.border),
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
  Widget _buildQuickTimeframeChip(String key, String label, String current) {
    final isSelected = key == current;
    return InkWell(
      onTap: () => ref.read(analyticsFilterProvider.notifier).updateTimeframe(key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveRemovableChip({required String label, required VoidCallback onRemove}) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 4, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accent),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: Icon(Icons.close, size: 14, color: AppTheme.accent),
          ),
        ],
      ),
    );
  }

  // ── Dimensional Selectors ───────────────────────────────────────
  Widget _buildSubjectSelector(AnalyticsFilter filter, List<Map<String, dynamic>> subjects) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: filter.subjectId != null ? AppTheme.primary : AppTheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              isExpanded: true,
              value: filter.subjectId,
              dropdownColor: AppTheme.surface,
              icon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 20),
              style: TextStyle(fontSize: 12, color: AppTheme.text),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All Subjects', style: TextStyle(color: AppTheme.textSecondary)),
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

  Widget _buildSectionSelector(AnalyticsFilter filter, List<Map<String, dynamic>> sections) {
    final activeSection = filter.section;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Class Section', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: (activeSection != null && activeSection != 'All Sections') ? AppTheme.primary : AppTheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: activeSection,
              dropdownColor: AppTheme.surface,
              icon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 20),
              style: TextStyle(fontSize: 12, color: AppTheme.text),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Sections', style: TextStyle(color: AppTheme.textSecondary)),
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

  Widget _buildTimeframeSelector(AnalyticsFilter filter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date Range', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: filter.timeframe != 'all' ? AppTheme.primary : AppTheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: filter.timeframe,
              dropdownColor: AppTheme.surface,
              icon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 20),
              style: TextStyle(fontSize: 12, color: AppTheme.text),
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

  Widget _buildCategorySelector(AnalyticsFilter filter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Student Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: filter.category != 'all' ? AppTheme.primary : AppTheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: filter.category,
              dropdownColor: AppTheme.surface,
              icon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 20),
              style: TextStyle(fontSize: 12, color: AppTheme.text),
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
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                          color: AppTheme.border,
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
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
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
                    _buildSubjectSelector(curFilter, subjects),
                    const SizedBox(height: 16),
                    _buildSectionSelector(curFilter, sections),
                    const SizedBox(height: 16),
                    _buildTimeframeSelector(curFilter),
                    const SizedBox(height: 16),
                    _buildCategorySelector(curFilter),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
