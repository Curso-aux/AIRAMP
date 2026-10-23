import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/student_repository.dart';

/// Shows the dedicated Student Learning Analytics & Performance modal bottom sheet.
void showStudentAnalyticsSheet(BuildContext context) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const StudentAnalyticsSheet(),
  );
}

class StudentAnalyticsSheet extends ConsumerStatefulWidget {
  const StudentAnalyticsSheet({super.key});

  @override
  ConsumerState<StudentAnalyticsSheet> createState() => _StudentAnalyticsSheetState();
}

class _StudentAnalyticsSheetState extends ConsumerState<StudentAnalyticsSheet> {
  // 0: KPI Summary Cards, 1: Donut Chart Breakdown, 2: Curriculum Mastery Gauge
  int _viewIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
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

          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
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
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'My Progress',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.2,
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
                        'Your courses, completed lessons & study goals',
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // View Mode Segmented Switcher
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
                        _buildModeTab(0, 'Overview', Icons.grid_view_rounded, isDark),
                        _buildModeTab(1, 'Breakdown', Icons.pie_chart_rounded, isDark),
                        _buildModeTab(2, 'Mastery', Icons.trending_up_rounded, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Selected Analytics View Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceLight.withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: _buildSelectedView(activeCourses, lessonsDone, pending, isDark),
                  ),
                  const SizedBox(height: 24),

                  // Section: Course by Course Breakdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Course Progress',
                        style: TextStyle(
                          fontSize: 14.5,
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
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: courses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final course = courses[index];
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
                      },
                    ),

                  const SizedBox(height: 20),

                  // Section: Assessment Snapshot
                  Container(
                    padding: const EdgeInsets.all(14),
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
          padding: const EdgeInsets.symmetric(vertical: 7),
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
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? primary
                    : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? AppTheme.darkText : const Color(0xFF0F172A))
                      : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedView(int activeCourses, int lessonsDone, int pending, bool isDark) {
    switch (_viewIndex) {
      case 1:
        return _buildDonutChartView(activeCourses, lessonsDone, pending, isDark);
      case 2:
        return _buildProgressGaugeView(activeCourses, lessonsDone, pending, isDark);
      case 0:
      default:
        return _buildOverviewCardsView(activeCourses, lessonsDone, pending, isDark);
    }
  }

  Widget _buildOverviewCardsView(int activeCourses, int lessonsDone, int pending, bool isDark) {
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

  Widget _buildProgressGaugeView(int activeCourses, int lessonsDone, int pending, bool isDark) {
    final total = lessonsDone + pending;
    final ratio = total > 0 ? (lessonsDone / total).clamp(0.0, 1.0) : 0.0;
    final pct = (ratio * 100).round();
    final primary = AppTheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overall Course Progress',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(primary),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$lessonsDone of $total lessons finished',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
            Text(
              '$pending remaining',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
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
