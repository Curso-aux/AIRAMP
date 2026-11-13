import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/application/auth_provider.dart';
import '../../features/teacher/data/teacher_repository.dart';
import '../theme/app_theme.dart';

class _TierVisuals {
  final Color bgLight;
  final Color bgDark;
  final Color borderLight;
  final Color borderDark;
  final Color textLight;
  final Color textDark;
  final String label;
  final IconData icon;

  const _TierVisuals({
    required this.bgLight,
    required this.bgDark,
    required this.borderLight,
    required this.borderDark,
    required this.textLight,
    required this.textDark,
    required this.label,
    required this.icon,
  });

  Color bg(bool isDark) => isDark ? bgDark : bgLight;
  Color border(bool isDark) => isDark ? borderDark : borderLight;
  Color text(bool isDark) => isDark ? textDark : textLight;
}

const _masteredTier = _TierVisuals(
  bgLight: Color(0xFFECFDF5),
  bgDark: Color(0x33064E3B),
  borderLight: Color(0xFFA7F3D0),
  borderDark: Color(0x66059669),
  textLight: Color(0xFF047857),
  textDark: Color(0xFF6EE7B7),
  label: 'Mastered (≥85%)',
  icon: Icons.check_circle_rounded,
);

const _proficientTier = _TierVisuals(
  bgLight: Color(0xFFEFF6FF),
  bgDark: Color(0x331E3A8A),
  borderLight: Color(0xFFBFDBFE),
  borderDark: Color(0x662563EB),
  textLight: Color(0xFF1D4ED8),
  textDark: Color(0xFF93C5FD),
  label: 'Proficient (70–84%)',
  icon: Icons.trending_up_rounded,
);

const _developingTier = _TierVisuals(
  bgLight: Color(0xFFFFFBEB),
  bgDark: Color(0x3378350F),
  borderLight: Color(0xFFFDE68A),
  borderDark: Color(0x66D97706),
  textLight: Color(0xFFB45309),
  textDark: Color(0xFFFCD34D),
  label: 'Developing (50–69%)',
  icon: Icons.info_outline_rounded,
);

const _needsHelpTier = _TierVisuals(
  bgLight: Color(0xFFFFF1F2),
  bgDark: Color(0x33881337),
  borderLight: Color(0xFFFECDD3),
  borderDark: Color(0x66E11D48),
  textLight: Color(0xFFBE123C),
  textDark: Color(0xFFFDA4AF),
  label: 'Needs Support (<50%)',
  icon: Icons.warning_amber_rounded,
);

const _unassessedTier = _TierVisuals(
  bgLight: Color(0xFFF8FAFC),
  bgDark: Color(0x2A1E293B),
  borderLight: Color(0xFFE2E8F0),
  borderDark: Color(0x40334155),
  textLight: Color(0xFF94A3B8),
  textDark: Color(0xFF64748B),
  label: 'Not Assessed',
  icon: Icons.remove_rounded,
);

_TierVisuals _resolveTierVisual(String? tier) {
  switch (tier?.toLowerCase()) {
    case 'mastered':
      return _masteredTier;
    case 'proficient':
      return _proficientTier;
    case 'developing':
      return _developingTier;
    case 'needs_help':
      return _needsHelpTier;
    default:
      return _unassessedTier;
  }
}

class LoMasteryMatrix extends ConsumerStatefulWidget {
  final String? teacherId;
  final String? initialSection;
  final String? initialStudentId;
  final int? initialSubjectId;
  final bool compact;

  const LoMasteryMatrix({
    super.key,
    this.teacherId,
    this.initialSection,
    this.initialStudentId,
    this.initialSubjectId,
    this.compact = false,
  });

  @override
  ConsumerState<LoMasteryMatrix> createState() => _LoMasteryMatrixState();
}

class _LoMasteryMatrixState extends ConsumerState<LoMasteryMatrix> {
  int? _selectedSubjectId;
  String _viewDimension = 'section'; // 'section' or 'student'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId;
  }

  @override
  void didUpdateWidget(covariant LoMasteryMatrix oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubjectId != oldWidget.initialSubjectId) {
      _selectedSubjectId = widget.initialSubjectId;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(authProvider);
    final effectiveTeacherId = widget.teacherId ?? (currentUser?.role == 'teacher' ? currentUser?.id : null);

    final params = CompetencyHeatmapParams(
      teacherId: effectiveTeacherId,
      subjectId: _selectedSubjectId,
      section: widget.initialSection,
      studentId: widget.initialStudentId,
    );

    final heatmapAsync = ref.watch(competencyHeatmapProvider(params));

    return heatmapAsync.when(
      loading: () => Container(
        height: 280,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading curriculum competency matrix...',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      error: (err, stack) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Unable to load competency heatmap: $err',
                style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.darkText : AppTheme.lightText),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(competencyHeatmapProvider(params)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) => _buildHeatmapContent(context, data, isDark, params),
    );
  }

  Widget _buildHeatmapContent(
    BuildContext context,
    Map<String, dynamic> data,
    bool isDark,
    CompetencyHeatmapParams params,
  ) {
    final subjects = (data['subjects'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final sections = (data['sections'] as List<dynamic>?)?.cast<String>() ?? [];
    final students = (data['students'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final rawMatrix = (data['matrix'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    // Filter competencies by search query
    final query = _searchQuery.trim().toLowerCase();
    final competencies = rawMatrix.where((c) {
      if (query.isEmpty) return true;
      final code = (c['code'] as String? ?? '').toLowerCase();
      final title = (c['title'] as String? ?? '').toLowerCase();
      final topic = (c['topicTitle'] as String? ?? '').toLowerCase();
      final sub = (c['subjectName'] as String? ?? '').toLowerCase();
      return code.contains(query) || title.contains(query) || topic.contains(query) || sub.contains(query);
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Controls Toolbar ──
        _buildControlsToolbar(
          context: context,
          isDark: isDark,
          isMobile: isMobile,
          subjects: subjects,
          hasStudents: students.isNotEmpty,
          onRefresh: () => ref.invalidate(competencyHeatmapProvider(params)),
        ),
        const SizedBox(height: 12),

        // ── Legend Bar ──
        _buildLegendBar(isDark),
        const SizedBox(height: 14),

        // ── Heatmap Grid or Empty State ──
        if (competencies.isEmpty)
          _buildEmptyCompetenciesState(isDark)
        else
          _buildHeatmapMatrixGrid(
            context: context,
            competencies: competencies,
            sections: sections,
            students: students,
            isDark: isDark,
            isMobile: isMobile,
          ),
      ],
    );
  }

  Widget _buildControlsToolbar({
    required BuildContext context,
    required bool isDark,
    required bool isMobile,
    required List<Map<String, dynamic>> subjects,
    required bool hasStudents,
    required VoidCallback onRefresh,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              // Dimension Switcher (By Section vs By Student)
              Container(
                height: 34,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDimensionButton(
                      label: 'Class Sections',
                      icon: Icons.domain_rounded,
                      isActive: _viewDimension == 'section',
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _viewDimension = 'section');
                      },
                    ),
                    _buildDimensionButton(
                      label: 'Individual Students',
                      icon: Icons.person_search_rounded,
                      isActive: _viewDimension == 'student',
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _viewDimension = 'student');
                      },
                    ),
                  ],
                ),
              ),

              // Subject Filter Dropdown
              if (subjects.length > 1)
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedSubjectId,
                      icon: Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppTheme.textSecondary),
                      isDense: true,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkText : AppTheme.lightText,
                      ),
                      dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Active Subjects'),
                        ),
                        ...subjects.map((s) {
                          final subId = s['id'] as int;
                          final subCode = (s['subject_code'] ?? s['code'] ?? '').toString();
                          final subName = (s['name'] ?? 'Subject').toString();
                          final display = subCode.isNotEmpty ? '$subCode - $subName' : subName;
                          return DropdownMenuItem<int?>(
                            value: subId,
                            child: Text(
                              display.length > 28 ? '${display.substring(0, 26)}...' : display,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedSubjectId = val);
                      },
                    ),
                  ),
                ),

              // Refresh Button
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Refresh Mastery Matrix',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: AppTheme.textSecondary,
                onPressed: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Instant Search Bar
          SizedBox(
            height: 34,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkText : AppTheme.lightText,
              ),
              decoration: InputDecoration(
                hintText: 'Search competency by code, title, or topic...',
                hintStyle: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: AppTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 15),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppTheme.darkSurface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primary, width: 1.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? Colors.white
                  : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive
                    ? Colors.white
                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendBar(bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildLegendPill(_masteredTier, isDark),
        _buildLegendPill(_proficientTier, isDark),
        _buildLegendPill(_developingTier, isDark),
        _buildLegendPill(_needsHelpTier, isDark),
        _buildLegendPill(_unassessedTier, isDark),
      ],
    );
  }

  Widget _buildLegendPill(_TierVisuals visuals, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: visuals.bg(isDark),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: visuals.border(isDark), width: 1),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          visuals.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapMatrixGrid({
    required BuildContext context,
    required List<Map<String, dynamic>> competencies,
    required List<String> sections,
    required List<Map<String, dynamic>> students,
    required bool isDark,
    required bool isMobile,
  }) {
    final isStudentMode = _viewDimension == 'student';
    final double competencyColWidth = isMobile ? 180.0 : 270.0;
    const double cellWidth = 98.0;
    const double summaryColWidth = 104.0;
    const double headerHeight = 44.0;
    const double rowHeight = 52.0;

    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final headerBg = isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9);
    final rowBg = isDark ? AppTheme.darkSurface : Colors.white;

    final List<String> columnHeaders = isStudentMode
        ? (students.isNotEmpty
            ? students.map((s) => s['name'] as String? ?? 'Student').toList()
            : ['No Students Enrolled'])
        : (sections.isNotEmpty ? sections : ['Cohort']);

    return Container(
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Pinned Frozen Left Column: Competency ──
          SizedBox(
            width: competencyColWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  height: headerHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  color: headerBg,
                  child: Row(
                    children: [
                      Text(
                        'COMPETENCY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${competencies.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Rows
                for (int i = 0; i < competencies.length; i++) ...[
                  Divider(height: 1, thickness: 1, color: borderColor),
                  _buildCompetencyRowTitle(
                    competency: competencies[i],
                    height: rowHeight,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),

          // ── Vertical Column Divider ──
          Container(
            width: 1,
            height: headerHeight + (competencies.length * (rowHeight + 1)),
            color: borderColor,
          ),

          // ── Scrollable Data Columns ──
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: (columnHeaders.length * cellWidth) + summaryColWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Container(
                      height: headerHeight,
                      color: headerBg,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int idx = 0; idx < columnHeaders.length; idx++)
                            SizedBox(
                              width: cellWidth,
                              height: headerHeight,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    columnHeaders[idx],
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.darkText : AppTheme.lightText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Summary Column Header
                          SizedBox(
                            width: summaryColWidth,
                            height: headerHeight,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isStudentMode ? 'Section Avg' : 'Class Avg',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Data Rows
                    for (int i = 0; i < competencies.length; i++) ...[
                      Divider(height: 1, thickness: 1, color: borderColor),
                      _buildHeatmapDataRow(
                        context: context,
                        competency: competencies[i],
                        sections: sections,
                        students: students,
                        isStudentMode: isStudentMode,
                        cellWidth: cellWidth,
                        summaryWidth: summaryColWidth,
                        rowHeight: rowHeight,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetencyRowTitle({
    required Map<String, dynamic> competency,
    required double height,
    required bool isDark,
  }) {
    final code = competency['code'] as String? ?? 'LO';
    final title = competency['title'] as String? ?? 'Competency';
    final topic = competency['topicTitle'] as String? ?? '';
    final passingScore = competency['passingScore'] as int? ?? 75;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              if (topic.isNotEmpty)
                Flexible(
                  child: Text(
                    topic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ),
              const Spacer(),
              Text(
                'Pass: $passingScore%',
                style: TextStyle(fontSize: 9.5, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapDataRow({
    required BuildContext context,
    required Map<String, dynamic> competency,
    required List<String> sections,
    required List<Map<String, dynamic>> students,
    required bool isStudentMode,
    required double cellWidth,
    required double summaryWidth,
    required double rowHeight,
    required bool isDark,
  }) {
    final sectionsMap = (competency['sections'] as Map<String, dynamic>?) ?? {};
    final studentsMap = (competency['students'] as Map<String, dynamic>?) ?? {};
    final overallMap = (competency['overall'] as Map<String, dynamic>?) ?? {};

    return SizedBox(
      height: rowHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isStudentMode) ...[
            if (students.isEmpty)
              SizedBox(
                width: cellWidth,
                height: rowHeight,
                child: Center(
                  child: Text(
                    '—',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                    ),
                  ),
                ),
              )
            else
              for (final stud in students)
                _buildStudentCell(
                  context: context,
                  competency: competency,
                  student: stud,
                  stats: studentsMap[stud['id']],
                  width: cellWidth,
                  height: rowHeight,
                  isDark: isDark,
                ),
          ] else ...[
            if (sections.isEmpty)
              _buildSectionCell(
                context: context,
                competency: competency,
                sectionName: 'Cohort',
                stats: overallMap,
                width: cellWidth,
                height: rowHeight,
                isDark: isDark,
              )
            else
              for (final sec in sections)
                _buildSectionCell(
                  context: context,
                  competency: competency,
                  sectionName: sec,
                  stats: sectionsMap[sec],
                  width: cellWidth,
                  height: rowHeight,
                  isDark: isDark,
                ),
          ],

          // Summary Column (Cohort Avg or Section Avg)
          _buildSummaryCell(
            context: context,
            competency: competency,
            stats: overallMap,
            width: summaryWidth,
            height: rowHeight,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCell({
    required BuildContext context,
    required Map<String, dynamic> competency,
    required String sectionName,
    required dynamic stats,
    required double width,
    required double height,
    required bool isDark,
  }) {
    final statMap = (stats as Map<String, dynamic>?) ?? {};
    final double? avgScore = (statMap['avgScore'] as num?)?.toDouble();
    final int attCount = (statMap['attemptsCount'] as num?)?.toInt() ?? 0;
    final String tier = statMap['tier'] as String? ?? 'unassessed';
    final visuals = _resolveTierVisual(tier);

    final tooltipMsg = avgScore != null
        ? '${competency['title']}\n$sectionName: ${avgScore.toStringAsFixed(1)}% ($attCount att.)'
        : '${competency['title']}\n$sectionName: Not yet assessed';

    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Tooltip(
          message: tooltipMsg,
          child: InkWell(
            onTap: () => _showCellDetailModal(
              context: context,
              competency: competency,
              targetLabel: sectionName,
              stats: statMap,
              isDark: isDark,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: visuals.bg(isDark),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: visuals.border(isDark), width: 1.1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (avgScore != null) ...[
                    Text(
                      '${avgScore.round()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: visuals.text(isDark),
                      ),
                    ),
                    Text(
                      '$attCount att.',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: visuals.text(isDark).withValues(alpha: 0.85),
                      ),
                    ),
                  ] else ...[
                    Text(
                      '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: visuals.text(isDark),
                      ),
                    ),
                    Text(
                      'No data',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: visuals.text(isDark).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCell({
    required BuildContext context,
    required Map<String, dynamic> competency,
    required Map<String, dynamic> student,
    required dynamic stats,
    required double width,
    required double height,
    required bool isDark,
  }) {
    final statMap = (stats as Map<String, dynamic>?) ?? {};
    final double? avgScore = (statMap['avgScore'] as num?)?.toDouble();
    final int attCount = (statMap['attemptsCount'] as num?)?.toInt() ?? 0;
    final String tier = statMap['tier'] as String? ?? 'unassessed';
    final visuals = _resolveTierVisual(tier);

    final studName = student['name'] as String? ?? 'Student';
    final tooltipMsg = avgScore != null
        ? '${competency['title']}\n$studName: ${avgScore.toStringAsFixed(1)}% ($attCount att.)'
        : '${competency['title']}\n$studName: No attempts recorded';

    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Tooltip(
          message: tooltipMsg,
          child: InkWell(
            onTap: () => _showCellDetailModal(
              context: context,
              competency: competency,
              targetLabel: studName,
              stats: statMap,
              isDark: isDark,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: visuals.bg(isDark),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: visuals.border(isDark), width: 1.1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (avgScore != null) ...[
                    Text(
                      '${avgScore.round()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: visuals.text(isDark),
                      ),
                    ),
                    Text(
                      '$attCount att.',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: visuals.text(isDark).withValues(alpha: 0.85),
                      ),
                    ),
                  ] else ...[
                    Text(
                      '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: visuals.text(isDark),
                      ),
                    ),
                    Text(
                      'No data',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: visuals.text(isDark).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCell({
    required BuildContext context,
    required Map<String, dynamic> competency,
    required dynamic stats,
    required double width,
    required double height,
    required bool isDark,
  }) {
    final statMap = (stats as Map<String, dynamic>?) ?? {};
    final double? avgScore = (statMap['avgScore'] as num?)?.toDouble();
    final int attCount = (statMap['attemptsCount'] as num?)?.toInt() ?? 0;
    final String tier = statMap['tier'] as String? ?? 'unassessed';
    final visuals = _resolveTierVisual(tier);

    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Tooltip(
          message: avgScore != null
              ? 'Overall Cohort Average: ${avgScore.toStringAsFixed(1)}% across $attCount attempts'
              : 'Cohort: No assessment attempts yet',
          child: InkWell(
            onTap: () => _showCellDetailModal(
              context: context,
              competency: competency,
              targetLabel: 'Cohort Overall Average',
              stats: statMap,
              isDark: isDark,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: visuals.bg(isDark),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: visuals.border(isDark), width: 1.2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (avgScore != null) ...[
                    Text(
                      '${avgScore.round()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: visuals.text(isDark),
                      ),
                    ),
                    Text(
                      '$attCount attempts',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w500,
                        color: visuals.text(isDark).withValues(alpha: 0.85),
                      ),
                    ),
                  ] else ...[
                    Text(
                      '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: visuals.text(isDark),
                      ),
                    ),
                    Text(
                      'Unassessed',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: visuals.text(isDark).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCellDetailModal({
    required BuildContext context,
    required Map<String, dynamic> competency,
    required String targetLabel,
    required Map<String, dynamic> stats,
    required bool isDark,
  }) {
    HapticFeedback.lightImpact();
    final code = competency['code'] as String? ?? 'LO';
    final title = competency['title'] as String? ?? 'Competency';
    final topic = competency['topicTitle'] as String? ?? '';
    final subName = competency['subjectName'] as String? ?? '';
    final double? avgScore = (stats['avgScore'] as num?)?.toDouble();
    final double? passRate = (stats['passRate'] as num?)?.toDouble();
    final int attCount = (stats['attemptsCount'] as num?)?.toInt() ?? 0;
    final int passedCount = (stats['passedCount'] as num?)?.toInt() ?? 0;
    final String tier = stats['tier'] as String? ?? 'unassessed';
    final visuals = _resolveTierVisual(tier);
    final attempts = (stats['attempts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: visuals.bg(isDark),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: visuals.border(isDark)),
              ),
              child: Icon(visuals.icon, color: visuals.text(isDark), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          code,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        targetLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkText : AppTheme.lightText,
                    ),
                  ),
                  if (topic.isNotEmpty || subName.isNotEmpty)
                    Text(
                      subName.isNotEmpty ? '$subName • $topic' : topic,
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Metric Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: visuals.bg(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: visuals.border(isDark)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('Score Mastery', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            avgScore != null ? '${avgScore.toStringAsFixed(1)}%' : '—',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: visuals.text(isDark),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Pass Rate', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            passRate != null ? '${passRate.toStringAsFixed(0)}%' : '—',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkText : AppTheme.lightText,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Recorded Attempts', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            '$passedCount / $attCount',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkText : AppTheme.lightText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Recorded Attempts List
                Text(
                  'Assessment History (${attempts.length} attempts)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                  ),
                ),
                const SizedBox(height: 8),

                if (attempts.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    child: Text(
                      'No individual attempts logged for this competency yet.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  )
                else
                  for (final att in attempts)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                            child: Text(
                              (att['student_name'] as String? ?? 'S').substring(0, 1).toUpperCase(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  att['student_name'] as String? ?? 'Student',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                                  ),
                                ),
                                Text(
                                  att['attempted_at']?.toString() ?? '',
                                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (att['is_passed'] == 1 ? AppTheme.success : AppTheme.error)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${att['percentage']}% • ${att['is_passed'] == 1 ? 'Passed' : 'Needs Review'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: att['is_passed'] == 1 ? AppTheme.success : AppTheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCompetenciesState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 36, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'No curriculum competencies match "$_searchQuery"'
                : 'No competencies or learning outcomes found for current subjects.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Quizzes and curriculum learning outcomes will populate here automatically as students attempt assessments.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
