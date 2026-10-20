import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/admin/data/admin_repository.dart';
import '../theme/app_theme.dart';

class GlobalDashboardFilterBar extends ConsumerWidget {
  final String? selectedAcademicYear;
  final String? selectedGradeLevel;
  final String? selectedSubject;
  final String? selectedSection;
  final List<String>? customSubjects;
  final List<String>? customSections;
  final ValueChanged<String>? onAcademicYearChanged;
  final ValueChanged<String>? onGradeLevelChanged;
  final ValueChanged<String>? onSubjectChanged;
  final ValueChanged<String>? onSectionChanged;
  final VoidCallback? onReset;
  final bool compact;

  const GlobalDashboardFilterBar({
    super.key,
    this.selectedAcademicYear,
    this.selectedGradeLevel,
    this.selectedSubject,
    this.selectedSection,
    this.customSubjects,
    this.customSections,
    this.onAcademicYearChanged,
    this.onGradeLevelChanged,
    this.onSubjectChanged,
    this.onSectionChanged,
    this.onReset,
    this.compact = false,
  });

  static const List<String> defaultAcademicYears = [
    'AY 2025-2026',
    'AY 2024-2025',
    'AY 2023-2024',
    'All Years',
  ];

  static const List<String> defaultGradeLevels = [
    'All Levels',
    'Senior High (Grade 11-12)',
    'Junior High (Grade 7-10)',
    'STEM Strand',
    'ABM Strand',
    'HUMSS Strand',
    'TVL-ICT',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adminFilter = ref.watch(analyticsFilterProvider);
    final subjectsAsync = ref.watch(subjectsProvider);
    final sectionsAsync = ref.watch(sectionsProvider);

    // Resolved values with fallback to admin filter provider
    final effectiveYear = selectedAcademicYear ?? adminFilter.academicYear;
    final effectiveGrade = selectedGradeLevel ?? adminFilter.departmentGradeLevel;
    final effectiveSubject = selectedSubject ?? adminFilter.subjectName ?? 'All Subjects';
    final effectiveSection = selectedSection ?? adminFilter.section ?? 'All Sections';

    // Build subject options
    final List<String> subjectOptions = customSubjects ?? [
      'All Subjects',
      ...subjectsAsync.map((s) => (s['name'] as String?) ?? (s['title'] as String?) ?? '').where((s) => s.isNotEmpty),
    ];
    if (!subjectOptions.contains('All Subjects')) subjectOptions.insert(0, 'All Subjects');

    // Build section options
    final List<String> sectionOptions = customSections ?? [
      'All Sections',
      ...sectionsAsync.map((s) => (s['name'] as String?) ?? '').where((s) => s.isNotEmpty),
    ];
    if (!sectionOptions.contains('All Sections')) sectionOptions.insert(0, 'All Sections');

    final bool hasActiveFilter = effectiveYear != 'AY 2025-2026' ||
        effectiveGrade != 'All Levels' ||
        (effectiveSubject != 'All Subjects' && effectiveSubject.isNotEmpty) ||
        (effectiveSection != 'All Sections' && effectiveSection.isNotEmpty);

    int activeCount = 0;
    if (effectiveYear != 'AY 2025-2026') activeCount++;
    if (effectiveGrade != 'All Levels') activeCount++;
    if (effectiveSubject != 'All Subjects' && effectiveSubject.isNotEmpty) activeCount++;
    if (effectiveSection != 'All Sections' && effectiveSection.isNotEmpty) activeCount++;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasActiveFilter
              ? AppTheme.primary.withValues(alpha: isDark ? 0.6 : 0.4)
              : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          width: hasActiveFilter ? 1.5 : 1.0,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter Bar Header: Title, Active Badge, Reset
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.filter_list_rounded, size: 16, color: AppTheme.primary),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Institutional Filter Controls',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                  ),
                ),
              ),
              if (hasActiveFilter) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$activeCount active',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (hasActiveFilter)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    if (onReset != null) {
                      onReset!();
                    } else {
                      ref.read(analyticsFilterProvider.notifier).reset();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 13, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Reset Filters',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Responsive Filters Wrap / Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final isMedium = constraints.maxWidth >= 550 && constraints.maxWidth < 900;

              final academicYearDropdown = _buildDropdown(
                context: context,
                label: 'Academic Year',
                icon: Icons.calendar_today_rounded,
                value: defaultAcademicYears.contains(effectiveYear) ? effectiveYear : defaultAcademicYears.first,
                items: defaultAcademicYears,
                isDark: isDark,
                onChanged: (val) {
                  if (val != null) {
                    if (onAcademicYearChanged != null) {
                      onAcademicYearChanged!(val);
                    } else {
                      ref.read(analyticsFilterProvider.notifier).updateAcademicYear(val);
                    }
                  }
                },
              );

              final gradeLevelDropdown = _buildDropdown(
                context: context,
                label: 'Department / Grade',
                icon: Icons.school_outlined,
                value: defaultGradeLevels.contains(effectiveGrade) ? effectiveGrade : defaultGradeLevels.first,
                items: defaultGradeLevels,
                isDark: isDark,
                onChanged: (val) {
                  if (val != null) {
                    if (onGradeLevelChanged != null) {
                      onGradeLevelChanged!(val);
                    } else {
                      ref.read(analyticsFilterProvider.notifier).updateDepartmentGradeLevel(val);
                    }
                  }
                },
              );

              final subjectDropdown = _buildDropdown(
                context: context,
                label: 'Subject',
                icon: Icons.menu_book_outlined,
                value: subjectOptions.contains(effectiveSubject) ? effectiveSubject : 'All Subjects',
                items: subjectOptions,
                isDark: isDark,
                onChanged: (val) {
                  if (val != null) {
                    if (onSubjectChanged != null) {
                      onSubjectChanged!(val);
                    } else {
                      if (val == 'All Subjects') {
                        ref.read(analyticsFilterProvider.notifier).updateSubject(null, null);
                      } else {
                        ref.read(analyticsFilterProvider.notifier).updateSubject(null, val);
                      }
                    }
                  }
                },
              );

              final sectionDropdown = _buildDropdown(
                context: context,
                label: 'Class Section',
                icon: Icons.groups_outlined,
                value: sectionOptions.contains(effectiveSection) ? effectiveSection : 'All Sections',
                items: sectionOptions,
                isDark: isDark,
                onChanged: (val) {
                  if (val != null) {
                    if (onSectionChanged != null) {
                      onSectionChanged!(val);
                    } else {
                      ref.read(analyticsFilterProvider.notifier).updateSection(val == 'All Sections' ? null : val);
                    }
                  }
                },
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: academicYearDropdown),
                    const SizedBox(width: 12),
                    Expanded(child: gradeLevelDropdown),
                    const SizedBox(width: 12),
                    Expanded(child: subjectDropdown),
                    const SizedBox(width: 12),
                    Expanded(child: sectionDropdown),
                  ],
                );
              } else if (isMedium) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: academicYearDropdown),
                        const SizedBox(width: 12),
                        Expanded(child: gradeLevelDropdown),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: subjectDropdown),
                        const SizedBox(width: 12),
                        Expanded(child: sectionDropdown),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  academicYearDropdown,
                  const SizedBox(height: 8),
                  gradeLevelDropdown,
                  const SizedBox(height: 8),
                  subjectDropdown,
                  const SizedBox(height: 8),
                  sectionDropdown,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              borderRadius: BorderRadius.circular(10),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
              dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.darkText : AppTheme.lightText,
              ),
              items: items.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt,
                  child: Text(
                    opt,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
