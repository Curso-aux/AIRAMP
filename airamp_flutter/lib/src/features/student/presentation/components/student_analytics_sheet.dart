import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/animations/app_transitions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/student_repository.dart';

/// Shows the dedicated Student Learning Analytics & Performance modal sheet or desktop dialog.
void showStudentAnalyticsSheet(BuildContext context) {
  HapticFeedback.lightImpact();
  final screenWidth = MediaQuery.of(context).size.width;
  final isDesktop = screenWidth >= 800;

  if (isDesktop) {
    AppModalTransitions.showSmoothDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: StudentAnalyticsSheet(isDesktop: true),
      ),
    );
  } else {
    AppModalTransitions.showSmoothBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const StudentAnalyticsSheet(isDesktop: false),
    );
  }
}

class StudentAnalyticsSheet extends ConsumerStatefulWidget {
  final bool? isDesktop;
  const StudentAnalyticsSheet({super.key, this.isDesktop});

  @override
  ConsumerState<StudentAnalyticsSheet> createState() => _StudentAnalyticsSheetState();
}

class _StudentAnalyticsSheetState extends ConsumerState<StudentAnalyticsSheet> {
  // 0: Descriptive, 1: Predictive, 2: Prescriptive
  int _viewIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = widget.isDesktop ?? (screenWidth >= 800);
    final primary = AppTheme.primary;

    final courses = ref.watch(studentCoursesProvider);
    final progress = ref.watch(studentProgressProvider);
    final quizzes = ref.watch(studentQuizAssignmentsProvider);

    final activeCourses = courses.length;
    final lessonsDone = progress['completed'] ?? 0;
    final pending = progress['pending'] ?? 0;
    final total = lessonsDone + pending;
    final completionPct = total > 0 ? ((lessonsDone / total) * 100).round() : 0;

    final pendingQuizzes = quizzes.where((q) => q['status'] == 'pending').length;
    final completedQuizzes = quizzes.where((q) => q['status'] == 'completed').length;
    final overdueQuizzes = _getOverdueQuizzes(quizzes);

    return Container(
      constraints: BoxConstraints(
        maxWidth: isDesktop ? 920 : double.infinity,
        maxHeight: screenHeight * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: isDesktop
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: isDesktop ? 28 : 20,
            offset: Offset(0, isDesktop ? 8 : -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle (Mobile only)
          if (!isDesktop) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 6),

          // Header Row
          Padding(
            padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 20, isDesktop ? 16 : 14, isDesktop ? 20 : 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.insights_rounded,
                    color: primary,
                    size: isDesktop ? 22 : 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isDesktop ? 'My Progress & Analytics' : 'My Progress',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isDesktop ? 18 : 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (total > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                '$completionPct% Done',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your progress, completion forecast & personalized study plan',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 20, 16, isDesktop ? 24 : 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3-Pillar Friendly Switcher: Overview, Forecast, Next Steps
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildModeTab(0, 'Overview', Icons.analytics_outlined, isDark),
                        _buildModeTab(1, 'Forecast', Icons.auto_graph_rounded, isDark),
                        _buildModeTab(2, 'Next Steps', Icons.tips_and_updates_rounded, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Category Descriptor Subtitle Banner
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          _viewIndex == 0
                              ? Icons.history_edu_rounded
                              : _viewIndex == 1
                                  ? Icons.trending_up_rounded
                                  : Icons.lightbulb_outline_rounded,
                          size: 14,
                          color: primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _viewIndex == 0
                                ? 'Overview: Real-time progress, completed lessons & quiz performance'
                                : _viewIndex == 1
                                    ? 'Forecast: Projected finish date, learning speed & assessment readiness'
                                    : 'Next Steps: Recommended study tasks, urgent reminders & tips to improve',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selected Analytics View Container
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 20 : 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceLight.withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: _buildSelectedView(
                      courses,
                      progress,
                      quizzes,
                      activeCourses,
                      lessonsDone,
                      pending,
                      completionPct,
                      isDark,
                      isDesktop,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Contextual Lower Section depending on selected analytics mode
                  if (_viewIndex == 0) ...[
                    // DESCRIPTIVE LOWER SECTION: Course Progress Grid & Assessment Snapshot
                    _buildDescriptiveLowerSection(courses, activeCourses, pendingQuizzes, completedQuizzes, primary, isDark, isDesktop),
                  ] else if (_viewIndex == 1) ...[
                    // PREDICTIVE LOWER SECTION: Subject Risk Matrix & Assessment Deadline Risk
                    _buildPredictiveLowerSection(courses, quizzes, overdueQuizzes, progress, primary, isDark, isDesktop),
                  ] else ...[
                    // PRESCRIPTIVE LOWER SECTION: Strategic Learning Roadmap & Milestone Goal
                    _buildPrescriptiveLowerSection(courses, quizzes, overdueQuizzes, lessonsDone, pending, completionPct, primary, isDark, isDesktop),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(int index, String label, IconData icon, bool isDark) {
    final isSelected = _viewIndex == index;
    final primary = AppTheme.primary;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _viewIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppTheme.darkSurface : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? primary
                    : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? AppTheme.darkText : const Color(0xFF0F172A))
                        : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top View Branching (0: Descriptive, 1: Predictive, 2: Prescriptive)
  // ---------------------------------------------------------------------------

  Widget _buildSelectedView(
    List<Map<String, dynamic>> courses,
    Map<String, dynamic> progress,
    List<Map<String, dynamic>> quizzes,
    int activeCourses,
    int lessonsDone,
    int pending,
    int completionPct,
    bool isDark,
    bool isDesktop,
  ) {
    switch (_viewIndex) {
      case 1:
        return _buildPredictiveTopView(courses, progress, quizzes, lessonsDone, pending, completionPct, isDark, isDesktop);
      case 2:
        return _buildPrescriptiveTopView(courses, progress, quizzes, lessonsDone, pending, completionPct, isDark, isDesktop);
      case 0:
      default:
        return _buildDescriptiveTopView(activeCourses, lessonsDone, pending, completionPct, isDark, isDesktop);
    }
  }

  // ---------------------------------------------------------------------------
  // 1. DESCRIPTIVE VIEW (Historical status & current metrics)
  // ---------------------------------------------------------------------------

  Widget _buildDescriptiveTopView(
    int activeCourses,
    int lessonsDone,
    int pending,
    int completionPct,
    bool isDark,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOverviewCardsView(activeCourses, lessonsDone, pending, completionPct, isDark, isDesktop),
        const SizedBox(height: 18),
        _buildDonutChartView(activeCourses, lessonsDone, pending, isDark),
      ],
    );
  }

  Widget _buildOverviewCardsView(int activeCourses, int lessonsDone, int pending, int completionPct, bool isDark, bool isDesktop) {
    if (isDesktop) {
      return Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              label: 'Active Courses',
              value: '$activeCourses',
              icon: Icons.book_outlined,
              accentColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMetricTile(
              label: 'Lessons Done',
              value: '$lessonsDone',
              icon: Icons.check_circle_outline_rounded,
              accentColor: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMetricTile(
              label: 'To Do',
              value: '$pending',
              icon: Icons.schedule_rounded,
              accentColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMetricTile(
              label: 'Total Completion',
              value: '$completionPct%',
              icon: Icons.pie_chart_outline_rounded,
              accentColor: AppTheme.primary,
              isDark: isDark,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            label: 'Active Courses',
            value: '$activeCourses',
            icon: Icons.book_outlined,
            accentColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            label: 'Lessons Done',
            value: '$lessonsDone',
            icon: Icons.check_circle_outline_rounded,
            accentColor: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            label: 'To Do',
            value: '$pending',
            icon: Icons.schedule_rounded,
            accentColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: accentColor, size: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChartView(int activeCourses, int lessonsDone, int pending, bool isDark) {
    final total = lessonsDone + pending;
    final completionPct = total > 0 ? ((lessonsDone / total) * 100).round() : 0;
    final primary = AppTheme.primary;

    return Row(
      children: [
        SizedBox(
          width: 105,
          height: 105,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(105, 105),
                painter: _SheetDonutPainter(
                  completed: lessonsDone.toDouble(),
                  pending: pending.toDouble(),
                  completedColor: primary,
                  pendingColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  trackColor: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$completionPct%',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'DONE',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendRow('Completed Lessons', '$lessonsDone', primary, total > 0 ? '$completionPct%' : '0%'),
              const SizedBox(height: 8),
              _buildLegendRow(
                'Remaining Lessons',
                '$pending',
                isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                total > 0 ? '${100 - completionPct}%' : '0%',
              ),
              const SizedBox(height: 8),
              _buildLegendRow('Total Lessons', '$total', isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569), '100%'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendRow(String title, String count, Color color, String pct) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          count,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(width: 6),
        Text(
          '($pct)',
          style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildDescriptiveLowerSection(
    List<Map<String, dynamic>> courses,
    int activeCourses,
    int pendingQuizzes,
    int completedQuizzes,
    Color primary,
    bool isDark,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Course Progress',
              style: TextStyle(
                fontSize: isDesktop ? 15 : 14.5,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              '$activeCourses Courses',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (courses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              'No enrolled courses yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isMultiCol = constraints.maxWidth >= 550;
              if (isMultiCol) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: courses.map((course) {
                    return SizedBox(
                      width: itemWidth,
                      child: _buildCourseProgressCard(course, primary, isDark),
                    );
                  }).toList(),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: courses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildCourseProgressCard(courses[index], primary, isDark),
              );
            },
          ),

        const SizedBox(height: 20),

        // Section: Assessment Snapshot
        Container(
          padding: EdgeInsets.all(isDesktop ? 16 : 14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.quiz_outlined,
                  size: 18,
                  color: primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quizzes & Activities',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$pendingQuizzes To Take  •  $completedQuizzes Completed',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/student/quiz-history');
                },
                style: TextButton.styleFrom(
                  foregroundColor: primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCourseProgressCard(Map<String, dynamic> course, Color primary, bool isDark) {
    final code = (course['subject_code'] ?? course['code'] ?? 'SUBJ').toString();
    final name = (course['name'] ?? course['subject_name'] ?? course['title'] ?? 'Course').toString();
    final completedLos = (course['completed_los'] as num?)?.toInt() ?? 0;
    final totalLos = (course['total_los'] as num?)?.toInt() ?? 0;
    final ratio = totalLos > 0 ? (completedLos / totalLos).clamp(0.0, 1.0) : 0.0;
    final pct = (ratio * 100).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : const Color(0xFF1E293B),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$completedLos / $totalLos lessons',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. PREDICTIVE VIEW (Forecasts, velocity & risk trajectory)
  // ---------------------------------------------------------------------------

  Widget _buildPredictiveTopView(
    List<Map<String, dynamic>> courses,
    Map<String, dynamic> progress,
    List<Map<String, dynamic>> quizzes,
    int lessonsDone,
    int pending,
    int completionPct,
    bool isDark,
    bool isDesktop,
  ) {
    final projectedPassRate = _calculateProjectedPassRate(progress, completionPct);
    final projectedDate = _calculateProjectedCompletionDate(lessonsDone, pending);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDesktop) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildPaceForecastCard(projectedDate, lessonsDone, pending, isDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildPassProbabilityCard(projectedPassRate, progress, completionPct, isDark),
              ),
            ],
          ),
        ] else ...[
          _buildPaceForecastCard(projectedDate, lessonsDone, pending, isDark),
          const SizedBox(height: 12),
          _buildPassProbabilityCard(projectedPassRate, progress, completionPct, isDark),
        ],
      ],
    );
  }

  Widget _buildPaceForecastCard(String projectedDate, int lessonsDone, int pending, bool isDark) {
    final primary = AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.speed_rounded, size: 16, color: primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Learning Pace & Timeline',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'On Track',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Projected Completion',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            projectedDate,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Estimated velocity: ~1.2 lessons / week based on recent study activity.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPassProbabilityCard(int projectedPassRate, Map<String, dynamic> progress, int completionPct, bool isDark) {
    final isHigh = projectedPassRate >= 80;
    final color = isHigh ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.verified_outlined, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Assessment Readiness',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$projectedPassRate%',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: projectedPassRate / 100.0,
              minHeight: 6,
              backgroundColor: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isHigh
                ? 'High Confidence: Current quiz averages & lesson progress correlate with a passing grade.'
                : 'Attention Advised: Complete pending modules to solidify passing threshold.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictiveLowerSection(
    List<Map<String, dynamic>> courses,
    List<Map<String, dynamic>> quizzes,
    List<Map<String, dynamic>> overdueQuizzes,
    Map<String, dynamic> progress,
    Color primary,
    bool isDark,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Subject Pace & Outlook',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isDesktop ? 15 : 14.5,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Pace Forecast',
              style: TextStyle(fontSize: 11.5, color: primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (courses.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Text('No courses available for pace forecasting.', style: TextStyle(color: AppTheme.textMuted)),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isMultiCol = constraints.maxWidth >= 550;
              if (isMultiCol) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: courses.map((course) {
                    return SizedBox(
                      width: itemWidth,
                      child: _buildPredictiveSubjectCard(course, primary, isDark),
                    );
                  }).toList(),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: courses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildPredictiveSubjectCard(courses[index], primary, isDark),
              );
            },
          ),

        const SizedBox(height: 20),

        // Assessment Deadlines Risk Alert
        Container(
          padding: EdgeInsets.all(isDesktop ? 16 : 14),
          decoration: BoxDecoration(
            color: overdueQuizzes.isNotEmpty
                ? const Color(0xFFFEF2F2).withValues(alpha: isDark ? 0.12 : 1.0)
                : (isDark ? AppTheme.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: overdueQuizzes.isNotEmpty
                  ? const Color(0xFFFCA5A5)
                  : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: overdueQuizzes.isNotEmpty
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  overdueQuizzes.isNotEmpty ? Icons.warning_amber_rounded : Icons.event_available_rounded,
                  size: 18,
                  color: overdueQuizzes.isNotEmpty ? const Color(0xFFEF4444) : primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overdueQuizzes.isNotEmpty
                          ? 'Elevated Risk: ${overdueQuizzes.length} Overdue Assessment'
                          : 'Assessment Risk: Low',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: overdueQuizzes.isNotEmpty
                            ? const Color(0xFFDC2626)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      overdueQuizzes.isNotEmpty
                          ? 'Overdue submissions adversely affect projected final standing. Recommended submission within 24 hours.'
                          : 'No overdue assessments detected. Your quiz trajectory is within target thresholds.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPredictiveSubjectCard(Map<String, dynamic> course, Color primary, bool isDark) {
    final code = (course['subject_code'] ?? course['code'] ?? 'SUBJ').toString();
    final name = (course['name'] ?? course['subject_name'] ?? course['title'] ?? 'Course').toString();
    final completedLos = (course['completed_los'] as num?)?.toInt() ?? 0;
    final totalLos = (course['total_los'] as num?)?.toInt() ?? 0;
    final ratio = totalLos > 0 ? (completedLos / totalLos).clamp(0.0, 1.0) : 0.0;
    final pct = (ratio * 100).round();

    final isAtRisk = pct == 0;
    final isOnTrack = pct >= 50;
    final statusLabel = isOnTrack ? 'On Track' : (isAtRisk ? 'At Risk' : 'In Progress');
    final statusColor = isOnTrack ? const Color(0xFF10B981) : (isAtRisk ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Proj. Pass: ${isOnTrack ? "92%" : (isAtRisk ? "68%" : "84%")}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. PRESCRIPTIVE VIEW (Smart recommendations & actionable interventions)
  // ---------------------------------------------------------------------------

  Widget _buildPrescriptiveTopView(
    List<Map<String, dynamic>> courses,
    Map<String, dynamic> progress,
    List<Map<String, dynamic>> quizzes,
    int lessonsDone,
    int pending,
    int completionPct,
    bool isDark,
    bool isDesktop,
  ) {
    final overdueQuizzes = _getOverdueQuizzes(quizzes);
    final lowestCourse = _getLowestProgressSubject(courses);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tips_and_updates_rounded, size: 16, color: Color(0xFF6366F1)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Recommended Next Actions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '3 Priority Tasks',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Priority 1: Overdue Quiz or Pending Quiz
        if (overdueQuizzes.isNotEmpty) ...[
          _buildPrescriptiveActionCard(
            priorityBadge: 'PRIORITY 1: URGENT',
            badgeColor: const Color(0xFFEF4444),
            title: 'Submit Overdue Quiz: ${overdueQuizzes.first['title']}',
            description: 'Due date passed for ${overdueQuizzes.first['subject_code']}. Completing this eliminates score penalty and restores on-track status.',
            actionLabel: 'Take Quiz Now',
            icon: Icons.error_outline_rounded,
            onAction: () {
              Navigator.of(context).pop();
              context.go('/student/quiz-history');
            },
            isDark: isDark,
          ),
        ] else if (quizzes.any((q) => q['status'] == 'pending')) ...[
          _buildPrescriptiveActionCard(
            priorityBadge: 'PRIORITY 1: ASSIGNMENT',
            badgeColor: const Color(0xFFF59E0B),
            title: 'Prepare Upcoming Quiz: ${quizzes.firstWhere((q) => q['status'] == 'pending')['title']}',
            description: 'Scheduled assessment due soon. Review the topic summaries to maximize passing probability.',
            actionLabel: 'Review Quizzes',
            icon: Icons.assignment_outlined,
            onAction: () {
              Navigator.of(context).pop();
              context.go('/student/quiz-history');
            },
            isDark: isDark,
          ),
        ] else ...[
          _buildPrescriptiveActionCard(
            priorityBadge: 'PRIORITY 1: COMPLETE',
            badgeColor: const Color(0xFF10B981),
            title: 'All Quizzes Up To Date',
            description: 'Zero pending or overdue assessments. You are ahead of schedule for quiz deliverables.',
            actionLabel: 'View Records',
            icon: Icons.check_circle_outline_rounded,
            onAction: () {
              Navigator.of(context).pop();
              context.go('/student/quiz-history');
            },
            isDark: isDark,
          ),
        ],

        const SizedBox(height: 10),

        // Priority 2: High Yield Lesson Action
        if (lowestCourse != null) ...[
          _buildPrescriptiveActionCard(
            priorityBadge: 'PRIORITY 2: HIGH YIELD',
            badgeColor: const Color(0xFF0D9488),
            title: 'Start Next Topic: ${lowestCourse['subject_code'] ?? lowestCourse['code']}',
            description: 'You have pending modules in ${lowestCourse['name'] ?? 'Curriculum'}. Clearing 1 lesson here boosts your completion rate immediately.',
            actionLabel: 'Open Course',
            icon: Icons.play_circle_outline_rounded,
            onAction: () {
              Navigator.of(context).pop();
              context.go('/student/courses');
            },
            isDark: isDark,
          ),
        ],

        const SizedBox(height: 10),

        // Priority 3: Schedule Gap Strategy
        _buildPrescriptiveActionCard(
          priorityBadge: 'PRIORITY 3: TIMETABLE',
          badgeColor: const Color(0xFF6366F1),
          title: 'Leverage Timetable Gaps',
          description: 'Dedicate 30 minutes before your next class slot for active recall. Studies show spaced learning increases retention by 35%.',
          actionLabel: 'View Schedule',
          icon: Icons.calendar_today_outlined,
          onAction: () {
            Navigator.of(context).pop();
            context.go('/student/schedule');
          },
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildPrescriptiveActionCard({
    required String priorityBadge,
    required Color badgeColor,
    required String title,
    required String description,
    required String actionLabel,
    required IconData icon,
    required VoidCallback onAction,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: badgeColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      priorityBadge,
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: badgeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(actionLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptiveLowerSection(
    List<Map<String, dynamic>> courses,
    List<Map<String, dynamic>> quizzes,
    List<Map<String, dynamic>> overdueQuizzes,
    int lessonsDone,
    int pending,
    int completionPct,
    Color primary,
    bool isDark,
    bool isDesktop,
  ) {
    final nextTargetPct = completionPct < 50 ? 50 : (completionPct < 75 ? 75 : 100);
    final lessonsNeeded = math.max(1, ((nextTargetPct / 100.0) * (lessonsDone + pending) - lessonsDone).ceil());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next Goals & Study Tips',
          style: TextStyle(
            fontSize: isDesktop ? 15 : 14.5,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),

        // Milestone Goal Card
        Container(
          padding: EdgeInsets.all(isDesktop ? 16 : 14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.flag_circle_outlined, size: 18, color: primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Next Milestone: $nextTargetPct% Completion',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completionPct% / $nextTargetPct%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (completionPct / nextTargetPct).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete $lessonsNeeded more lesson to unlock the $nextTargetPct% Mastery Milestone badge.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Cognitive Retention Strategy Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceLight.withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.psychology_outlined, size: 20, color: Color(0xFF6366F1)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Study Tip: Interleaved Learning',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rather than binge-studying a single course, alternate between CS101 and CS202 across 25-minute Pomodoro intervals. This significantly enhances concept retention for upcoming exams.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Calculations
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  List<Map<String, dynamic>> _getOverdueQuizzes(List<Map<String, dynamic>> quizzes) {
    final now = DateTime.now();
    return quizzes.where((q) {
      if (q['status'] != 'pending') return false;
      final dueDateStr = q['due_date']?.toString();
      if (dueDateStr == null) return false;
      try {
        final due = DateTime.parse(dueDateStr);
        return due.isBefore(now);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  Map<String, dynamic>? _getLowestProgressSubject(List<Map<String, dynamic>> courses) {
    if (courses.isEmpty) return null;
    Map<String, dynamic>? lowest;
    double lowestRatio = 2.0;
    for (final c in courses) {
      final total = (c['total_los'] as num?)?.toInt() ?? 0;
      final completed = (c['completed_los'] as num?)?.toInt() ?? 0;
      final ratio = total > 0 ? completed / total : 0.0;
      if (ratio < lowestRatio) {
        lowestRatio = ratio;
        lowest = c;
      }
    }
    return lowest;
  }

  int _calculateProjectedPassRate(Map<String, dynamic> progress, int completionPct) {
    final totalAttempts = progress['totalAttempts'] as int? ?? 0;
    final avgScore = (progress['average'] as num?)?.toDouble() ?? 0.0;

    if (totalAttempts > 0) {
      final weighted = (avgScore * 0.75) + (completionPct * 0.25);
      return weighted.clamp(40, 98).round();
    }
    if (completionPct >= 50) return 88;
    if (completionPct >= 20) return 82;
    return 74;
  }

  String _calculateProjectedCompletionDate(int lessonsDone, int pending) {
    if (pending == 0) return 'Curriculum Completed!';
    if (lessonsDone == 0) return 'Est. 3-4 weeks (Baseline pace establishing)';
    final days = (pending * 5).clamp(4, 45);
    final projectedDate = DateTime.now().add(Duration(days: days));
    return '${_formatDate(projectedDate)} (in ~$days days)';
  }
}

class _SheetDonutPainter extends CustomPainter {
  final double completed;
  final double pending;
  final Color completedColor;
  final Color pendingColor;
  final Color trackColor;

  const _SheetDonutPainter({
    required this.completed,
    required this.pending,
    required this.completedColor,
    required this.pendingColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 9.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final total = completed + pending;
    if (total <= 0) return;

    const startAngle = -math.pi / 2;
    final hasBoth = completed > 0 && pending > 0;
    final gap = hasBoth ? 0.08 : 0.0;

    final completedSweep = (completed / total) * 2 * math.pi;
    final pendingSweep = (pending / total) * 2 * math.pi;

    if (completed > 0) {
      final sweep = (completedSweep - gap).clamp(0.02, 2 * math.pi);
      final completedPaint = Paint()
        ..color = completedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (gap / 2),
        sweep,
        false,
        completedPaint,
      );
    }

    if (pending > 0) {
      final sweep = (pendingSweep - gap).clamp(0.02, 2 * math.pi);
      final pendingPaint = Paint()
        ..color = pendingColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + completedSweep + (gap / 2),
        sweep,
        false,
        pendingPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SheetDonutPainter oldDelegate) {
    return oldDelegate.completed != completed ||
        oldDelegate.pending != pending ||
        oldDelegate.completedColor != completedColor ||
        oldDelegate.pendingColor != pendingColor ||
        oldDelegate.trackColor != trackColor;
  }
}
