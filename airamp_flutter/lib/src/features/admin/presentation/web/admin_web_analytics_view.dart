import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/components/analytics_donut_chart.dart';
import '../../data/admin_repository.dart';
import 'components/analytics_filter_bar.dart';

class AdminWebAnalyticsView extends ConsumerWidget {
  const AdminWebAnalyticsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = ref.watch(adminAnalyticsProvider);
    final filter = ref.watch(analyticsFilterProvider);

    final totalUsers = analytics['totalUsers'] as int? ?? 0;
    final totalStudents = analytics['totalStudents'] as int? ?? 0;
    final totalTeachers = analytics['totalTeachers'] as int? ?? 0;
    final totalAdmins = analytics['totalAdmins'] as int? ?? 0;
    final totalEnrollments = analytics['totalEnrollments'] as int? ?? 0;
    final totalSubjects = analytics['totalSubjects'] as int? ?? 0;
    final totalLos = analytics['totalLos'] as int? ?? 0;
    final totalAttempts = analytics['totalAttempts'] as int? ?? 0;
    final passedAttempts = analytics['passedAttempts'] as int? ?? 0;
    final passRate = analytics['passRate'] as int? ?? 0;
    final avgScore = analytics['avgScore'] as int? ?? 0;
    final studentTeacherRatio = analytics['studentTeacherRatio'] as String? ?? (totalTeachers > 0 ? (totalStudents / totalTeachers).toStringAsFixed(1) : '0');
    final unassignedStudents = analytics['unassignedStudents'] as int? ?? 0;
    final demographics = (analytics['demographics'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {};
    final bool hasData = analytics['hasData'] as bool? ?? (totalUsers > 0 || totalAttempts > 0);

    final subjectEnrollments = (analytics['subjectEnrollments'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final sectionDistribution = (analytics['sectionDistribution'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final recentAttempts = (analytics['recentAttempts'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 720;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome & Refresh Banner
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isNarrow = headerConstraints.maxWidth < 650;

                  final titleSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School Analytics & Operations',
                        style: TextStyle(
                          fontSize: isNarrow ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkText : AppTheme.lightText,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live institutional metrics, student enrollments, and academic performance',
                        style: TextStyle(
                          fontSize: isNarrow ? 12.5 : 14,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  );

                  final refreshBtn = OutlinedButton.icon(
                    onPressed: () => ref.read(adminAnalyticsProvider.notifier).loadAnalytics(),
                    icon: Icon(Icons.refresh, size: 16, color: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary),
                    label: Text(
                      'Refresh Data',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkText : AppTheme.lightText,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                      side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(0, 40),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleSection,
                        const SizedBox(height: 12),
                        refreshBtn,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 16),
                      refreshBtn,
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Responsive, Theme-Aware Filter Bar (non-const for live theme reactivity)
              const AnalyticsFilterBar(),
              const SizedBox(height: 24),

              // Empty State when filter yields nothing
              if (!hasData && filter.hasActiveFilters)
                _buildEmptyFilterState(context, ref, filter, isDark)
              else ...[
                // Executive KPI Cards (Institutional 4-Column Layout)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final card1Subtitle = filter.hasActiveFilters
                        ? '$totalStudents Students matching filters'
                        : '$totalStudents Students · $totalTeachers Faculty · $totalAdmins Admins (Ratio ~$studentTeacherRatio:1)';

                    final card2Subtitle = filter.subjectName != null
                        ? 'Enrolled in ${filter.subjectName}'
                        : (filter.section != null && filter.section != 'All Sections')
                            ? 'Enrollments in ${filter.section}'
                            : 'Across $totalSubjects accredited courses offered';

                    final card3Subtitle = filter.subjectName != null
                        ? '$totalLos LO modules for this course'
                        : '$totalLos learning outcome modules';

                    final tfLabel = filter.timeframe == 'today'
                        ? 'Today'
                        : filter.timeframe == '7days'
                            ? 'Past 7 Days'
                            : filter.timeframe == '30days'
                                ? 'Past 30 Days'
                                : filter.timeframe == 'this_month'
                                    ? 'This Month'
                                    : 'All Time';

                    final card4Subtitle = totalAttempts > 0
                        ? '$passedAttempts passed of $totalAttempts exams ($tfLabel · Avg: $avgScore%)'
                        : '0 exams recorded for active filters ($tfLabel)';

                    final card1 = _buildKpiCard(
                      title: 'Total Users Registered',
                      value: '$totalUsers',
                      subtitle: card1Subtitle,
                      icon: Icons.people_outline,
                      color: AppTheme.primary,
                      isDark: isDark,
                    );
                    final card2 = _buildKpiCard(
                      title: 'Active Course Enrollments',
                      value: '$totalEnrollments',
                      subtitle: card2Subtitle,
                      icon: Icons.school_outlined,
                      color: AppTheme.accent,
                      isDark: isDark,
                    );
                    final card3 = _buildKpiCard(
                      title: 'Curriculum & Content',
                      value: '$totalSubjects Courses',
                      subtitle: card3Subtitle,
                      icon: Icons.menu_book_outlined,
                      color: AppTheme.warning,
                      isDark: isDark,
                    );
                    final card4 = _buildKpiCard(
                      title: 'Assessment Pass Rate',
                      value: '$passRate%',
                      subtitle: card4Subtitle,
                      icon: Icons.military_tech_outlined,
                      color: AppTheme.success,
                      isDark: isDark,
                    );

                    if (constraints.maxWidth >= 900) {
                      return Row(
                        children: [
                          Expanded(child: card1),
                          const SizedBox(width: 16),
                          Expanded(child: card2),
                          const SizedBox(width: 16),
                          Expanded(child: card3),
                          const SizedBox(width: 16),
                          Expanded(child: card4),
                        ],
                      );
                    } else if (constraints.maxWidth >= 550) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: card1),
                              const SizedBox(width: 16),
                              Expanded(child: card2),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: card3),
                              const SizedBox(width: 16),
                              Expanded(child: card4),
                            ],
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        card1,
                        const SizedBox(height: 14),
                        card2,
                        const SizedBox(height: 14),
                        card3,
                        const SizedBox(height: 14),
                        card4,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Visual Analytics Section: Assessment Mastery Donut & Student Demographics
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1050;
                    final donutCard = _buildMasteryDonutCard(
                      totalAttempts: totalAttempts,
                      passedAttempts: passedAttempts,
                      passRate: passRate,
                      avgScore: avgScore,
                      isDark: isDark,
                    );
                    final demographicsCard = _buildDemographicsAndPlacementCard(
                      totalStudents: totalStudents,
                      unassignedStudents: unassignedStudents,
                      demographics: demographics,
                      context: context,
                      isDark: isDark,
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: donutCard),
                          const SizedBox(width: 20),
                          Expanded(flex: 5, child: demographicsCard),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        donutCard,
                        const SizedBox(height: 20),
                        demographicsCard,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Course Academic Performance & Section Breakdown
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1050;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildSubjectEnrollmentsCard(subjectEnrollments, totalEnrollments, isDark),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: _buildSectionDistributionCard(sectionDistribution, context, isDark),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        _buildSubjectEnrollmentsCard(subjectEnrollments, totalEnrollments, isDark),
                        const SizedBox(height: 20),
                        _buildSectionDistributionCard(sectionDistribution, context, isDark),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Recent Student Assessments Ledger
                _buildRecentActivitySection(recentAttempts, context, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Executive KPI Card ──────────────────────────────────────────────
  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.16 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Institutional Assessment Mastery Donut Card ───────────────────
  Widget _buildMasteryDonutCard({
    required int totalAttempts,
    required int passedAttempts,
    required int passRate,
    required int avgScore,
    required bool isDark,
  }) {
    final needsReview = totalAttempts - passedAttempts;
    final benchmarkPassed = passRate >= 75;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Academic Mastery & Pass Distribution',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (benchmarkPassed ? AppTheme.success : AppTheme.warning).withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  benchmarkPassed ? 'Standard Met (≥75%)' : 'Needs Intervention',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: benchmarkPassed ? AppTheme.success : AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Donut Chart & Side Legend Breakdown
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 480;

              final chartWidget = SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(130, 130),
                      painter: AnalyticsDonutPainter(
                        valueA: passedAttempts.toDouble(),
                        valueB: needsReview.toDouble(),
                        colorA: AppTheme.success,
                        colorB: AppTheme.warning,
                        trackColor: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                        strokeWidth: 16.0,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$passRate%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkText : AppTheme.lightText,
                          ),
                        ),
                        Text(
                          'Pass Rate',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final metricsWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMasteryMetricRow(
                    label: 'Passed Examinations',
                    value: '$passedAttempts ($passRate%)',
                    color: AppTheme.success,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildMasteryMetricRow(
                    label: 'Remediation / Review Needed',
                    value: '$needsReview (${totalAttempts > 0 ? (100 - passRate) : 0}%)',
                    color: AppTheme.warning,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildMasteryMetricRow(
                    label: 'Overall Average Grade',
                    value: '$avgScore%',
                    color: AppTheme.accent,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildMasteryMetricRow(
                    label: 'Total Quiz Attempts',
                    value: '$totalAttempts Submissions',
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    isDark: isDark,
                  ),
                ],
              );

              if (isSmall) {
                return Column(
                  children: [
                    Center(child: chartWidget),
                    const SizedBox(height: 16),
                    metricsWidget,
                  ],
                );
              }

              return Row(
                children: [
                  chartWidget,
                  const SizedBox(width: 24),
                  Expanded(child: metricsWidget),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Accreditation status summary strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
            child: Row(
              children: [
                Icon(
                  benchmarkPassed ? Icons.check_circle_outline : Icons.info_outline,
                  size: 16,
                  color: benchmarkPassed ? AppTheme.success : AppTheme.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    benchmarkPassed
                        ? 'Institutional pass rate complies with the academic accreditation standard of 75%.'
                        : 'Review course curriculum outcomes below to target subjects requiring remediation.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryMetricRow({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkText : AppTheme.lightText,
          ),
        ),
      ],
    );
  }

  // ── Demographics & Section Allocation Status Card ─────────────────
  Widget _buildDemographicsAndPlacementCard({
    required int totalStudents,
    required int unassignedStudents,
    required Map<String, dynamic> demographics,
    required BuildContext context,
    required bool isDark,
  }) {
    final assignedStudents = (totalStudents - unassignedStudents).clamp(0, totalStudents);
    final placementRate = totalStudents > 0 ? ((assignedStudents / totalStudents) * 100).round() : 100;

    final regular = demographics['regular'] as int? ?? (totalStudents - unassignedStudents);
    final irregular = demographics['irregular'] as int? ?? 0;
    final transferee = demographics['transferee'] as int? ?? 0;
    final sped = demographics['sped'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                    Icon(Icons.assignment_ind_outlined, color: AppTheme.accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Student Body & Enrollment Demographics',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkText : AppTheme.lightText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => context.go('/admin/students'),
                child: Text('Directory', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Section Placement Progress Bar
          Row(
            children: [
              Expanded(
                child: Text(
                  'Section Placement Rate',
                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$assignedStudents / $totalStudents Assigned ($placementRate%)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkText : AppTheme.lightText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (placementRate / 100).clamp(0.0, 1.0),
              backgroundColor: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(placementRate >= 90 ? AppTheme.success : AppTheme.warning),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),

          // Unassigned Warning Banner (if any)
          if (unassignedStudents > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$unassignedStudents students need section assignment',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.warning),
                    ),
                  ),
                  InkWell(
                    onTap: () => context.go('/admin/students'),
                    child: Text(
                      'Assign Now',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.warning, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Demographics Breakdown Grid
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 460) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildDemographicTile('Regular', '$regular', Icons.person_outline, isDark)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildDemographicTile('Irregular', '$irregular', Icons.swap_horiz, isDark)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildDemographicTile('Transferee', '$transferee', Icons.move_to_inbox_outlined, isDark)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildDemographicTile('SPED / Accom.', '$sped', Icons.accessibility_new, isDark)),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildDemographicTile('Regular', '$regular', Icons.person_outline, isDark)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDemographicTile('Irregular', '$irregular', Icons.swap_horiz, isDark)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDemographicTile('Transferee', '$transferee', Icons.move_to_inbox_outlined, isDark)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDemographicTile('SPED / Accom.', '$sped', Icons.accessibility_new, isDark)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDemographicTile(String label, String count, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkText : AppTheme.lightText),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Course Academic & Enrollment Registry ───────────────────────────
  Widget _buildSubjectEnrollmentsCard(List<Map<String, dynamic>> list, int totalEnrollments, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                    Icon(Icons.bar_chart_rounded, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Subject Enrollment Popularity',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkText : AppTheme.lightText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$totalEnrollments total enrollments',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No courses added yet.', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final sub = list[index];
                final count = sub['enrollments'] as int? ?? 0;
                final subPassRate = sub['passRate'] as int? ?? 0;
                final subAttempts = sub['attempts'] as int? ?? 0;
                final double percent = totalEnrollments > 0 ? (count / totalEnrollments) : 0.0;

                // Enterprise progress color: Emerald for ≥75%, Amber for 50-74%, Coral for <50%
                final Color progressColor = subAttempts == 0
                    ? AppTheme.primary
                    : subPassRate >= 75
                        ? AppTheme.success
                        : (subPassRate >= 50 ? AppTheme.warning : AppTheme.error);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                                ),
                                child: Text(
                                  sub['code'] as String? ?? 'CRS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  sub['name'] as String? ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$count students (${(percent * 100).toStringAsFixed(0)}%)'
                          '${subAttempts > 0 ? ' · $subPassRate% Pass' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent.clamp(0.04, 1.0),
                        backgroundColor: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Class Sections & Distribution ──────────────────────────────────
  Widget _buildSectionDistributionCard(List<Map<String, dynamic>> list, BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                    Icon(Icons.groups_outlined, color: AppTheme.accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Student Sections & Distribution',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkText : AppTheme.lightText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.go('/admin/students'),
                child: Row(
                  children: [
                    Text('Manage', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    Icon(Icons.chevron_right, size: 16, color: AppTheme.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No students registered yet.', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: list.map((sec) {
                final sectionName = sec['section'] as String? ?? 'Unassigned';
                final count = sec['count'] as int? ?? 0;
                final isUnassigned = sectionName.toLowerCase() == 'unassigned';

                return Container(
                  width: 140,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isUnassigned && count > 0
                          ? AppTheme.warning.withValues(alpha: 0.5)
                          : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sectionName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isUnassigned && count > 0 ? AppTheme.warning : (isDark ? AppTheme.darkText : AppTheme.lightText),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count Students',
                        style: TextStyle(
                          fontSize: 12,
                          color: isUnassigned && count > 0 ? AppTheme.warning : AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Recent Student Examination Activity Ledger ─────────────────────
  Widget _buildRecentActivitySection(List<Map<String, dynamic>> attempts, BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                    Icon(Icons.history_edu_outlined, color: AppTheme.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recent Student Assessments',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkText : AppTheme.lightText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => context.go('/admin/scores'),
                child: Row(
                  children: [
                    Text('View All Scores', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    Icon(Icons.arrow_forward, size: 14, color: AppTheme.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (attempts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No quiz submissions recorded yet.', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: attempts.length,
              separatorBuilder: (_, _) => Divider(height: 16, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              itemBuilder: (context, index) {
                final a = attempts[index];
                final isPassed = a['is_passed'] == 1 || a['is_passed'] == true;
                final score = a['score'] ?? 0;
                final total = a['total_questions'] ?? 0;
                final student = a['student_name'] as String? ?? 'Student';
                final section = a['student_section'] as String? ?? '';
                final subject = a['subject_name'] as String? ?? '';
                final lo = a['lo_title'] as String? ?? '';

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: (isPassed ? AppTheme.success : AppTheme.error).withValues(alpha: isDark ? 0.18 : 0.12),
                      child: Icon(
                        isPassed ? Icons.check : Icons.close,
                        size: 14,
                        color: isPassed ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$student ${section.isNotEmpty ? '($section)' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkText : AppTheme.lightText,
                            ),
                          ),
                          Text(
                            '$subject · $lo',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isPassed ? AppTheme.success : AppTheme.error).withValues(alpha: isDark ? 0.18 : 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$score/$total (${isPassed ? 'Passed' : 'Failed'})',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isPassed ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Empty Filter State ──────────────────────────────────────────────
  Widget _buildEmptyFilterState(BuildContext context, WidgetRef ref, AnalyticsFilter filter, bool isDark) {
    final List<String> activeBadges = [];
    if (filter.subjectName != null) activeBadges.add('Subject: ${filter.subjectName}');
    if (filter.section != null && filter.section != 'All Sections') activeBadges.add('Section: ${filter.section}');
    if (filter.timeframe != 'all') {
      final tfMap = {'today': 'Today', '7days': 'Past 7 Days', '30days': 'Past 30 Days', 'this_month': 'This Month'};
      activeBadges.add('Timeframe: ${tfMap[filter.timeframe] ?? filter.timeframe}');
    }
    if (filter.category != 'all') {
      final catMap = {'regular': 'Regular', 'irregular': 'Irregular', 'transferee': 'Transferee', 'sped': 'SPED', 'unassigned': 'Unassigned'};
      activeBadges.add('Category: ${catMap[filter.category] ?? filter.category}');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: isDark ? 0.16 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.filter_alt_off_rounded, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 18),
          Text(
            'No Analytics Found for Filter Criteria',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              'No registered students, course enrollments, or quiz submissions match your combined filter dimensions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: activeBadges.map((badge) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => ref.read(analyticsFilterProvider.notifier).reset(),
            icon: const Icon(Icons.restart_alt, size: 16),
            label: const Text('Reset All Filters'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
