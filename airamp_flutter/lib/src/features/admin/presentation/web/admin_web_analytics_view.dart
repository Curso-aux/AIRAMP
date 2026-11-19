import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/components/analytics_donut_chart.dart';
import '../../../../core/components/analytics/analytics_components.dart';
import '../../data/admin_repository.dart';
import 'components/analytics_filter_bar.dart';
import '../../../../core/components/kpi_summary_card.dart';
import '../../../../core/components/lo_mastery_matrix.dart';
import '../../../../core/components/user_avatar_widget.dart';
import '../controllers/semester_renewal_controller.dart';
import '../widgets/academic_term_reset_modal.dart';
import '../../../auth/application/auth_provider.dart';

class AdminWebAnalyticsView extends ConsumerWidget {
  const AdminWebAnalyticsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = ref.watch(adminAnalyticsProvider);
    final filter = ref.watch(analyticsFilterProvider);
    final demoAnalytics = ref.watch(campusAdminDemoAnalyticsProvider);

    final totalUsers = analytics['totalUsers'] as int? ?? 0;
    final totalStudents = analytics['totalStudents'] as int? ?? 0;
    final totalTeachers = analytics['totalTeachers'] as int? ?? 0;
    final totalEnrollments = analytics['totalEnrollments'] as int? ?? 0;
    final totalSubjects = analytics['totalSubjects'] as int? ?? 0;
    final totalLos = analytics['totalLos'] as int? ?? 0;
    final totalAttempts = analytics['totalAttempts'] as int? ?? 0;
    final passedAttempts = analytics['passedAttempts'] as int? ?? 0;
    final passRate = analytics['passRate'] as int? ?? 0;
    final avgScore = analytics['avgScore'] as int? ?? 0;
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
          await ref.read(adminAnalyticsProvider.notifier).loadAnalytics(syncCloud: true);
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
                    onPressed: () async {
                      await ref.read(adminAnalyticsProvider.notifier).loadAnalytics(syncCloud: true);
                    },
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

                  final actionButtons = refreshBtn;

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleSection,
                        const SizedBox(height: 12),
                        actionButtons,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 16),
                      actionButtons,
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Dedicated Semester-End Record Archiving & System Renewal Card (Milestone 2)
              _buildSemesterRenewalCard(context, ref, isDark),
              const SizedBox(height: 20),

              // Interactive Client Demo Sandbox Control Bar
              const AnalyticsDemoControlBar(
                showCampusFilter: false,
                showSectionFilter: true,
              ),

              // Unified Responsive Multi-Dimensional Analytics Filter Bar
              const AnalyticsFilterBar(),
              const SizedBox(height: 20),

              // Empty State when filter yields nothing
              if (!hasData && filter.hasActiveFilters)
                _buildEmptyFilterState(context, ref, filter, isDark)
              else ...[
                // Executive KPI Cards (Responsive 4-Tier / 2x2 Grid)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 650;

                    final displayStudents = totalStudents > 0 ? totalStudents : demoAnalytics.totalStudents;
                    final displayTeachers = totalTeachers > 0 ? totalTeachers : demoAnalytics.totalTeachers;
                    final displayUsers = totalUsers > 0 ? totalUsers : (displayStudents + displayTeachers + 2);
                    final displayEnrollments = totalEnrollments > 0 ? totalEnrollments : demoAnalytics.totalEnrollments;
                    final displayAvgScore = avgScore > 0 ? avgScore : demoAnalytics.averageScore;
                    final displayPassRate = passRate > 0 ? passRate : demoAnalytics.overallPassRate;
                    final displayAttempts = totalAttempts > 0 ? totalAttempts : 482;
                    final displayPassedAttempts = passedAttempts > 0 ? passedAttempts : (displayAttempts * displayPassRate ~/ 100);

                    final card1Subtitle = filter.hasActiveFilters
                        ? '$displayStudents Students matching'
                        : '$displayStudents Students · $displayTeachers Faculty';

                    final card2Subtitle = filter.subjectName != null
                        ? 'Enrolled in ${filter.subjectName}'
                        : (filter.section != null && filter.section != 'All Sections')
                            ? 'Enrollments in ${filter.section}'
                            : 'Across $totalSubjects active courses';

                    final card3Subtitle = filter.subjectName != null
                        ? '$totalLos competency units'
                        : '$totalLos topics assessed';

                    final tfLabel = filter.timeframe == 'today'
                        ? 'Today'
                        : filter.timeframe == '7days'
                            ? 'Past 7d'
                            : filter.timeframe == '30days'
                                ? 'Past 30d'
                                : filter.timeframe == 'this_month'
                                    ? 'This Month'
                                    : 'All Time';

                    final card4Subtitle = displayAttempts > 0
                        ? '$displayPassedAttempts of $displayAttempts passed ($displayAvgScore% avg)'
                        : '0 exams recorded ($tfLabel)';

                    final totalSectionsCount = (analytics['totalSections'] as int?) ?? (sectionDistribution.isNotEmpty ? sectionDistribution.length : 6);
                    final sectionBadge = '$totalSectionsCount ${totalSectionsCount == 1 ? 'Section' : 'Sections'}';
                    final courseBadge = '$totalSubjects ${totalSubjects == 1 ? 'Course' : 'Courses'}';
                    final unitBadge = '$totalLos ${totalLos == 1 ? 'Unit' : 'Units'}';

                    final card1 = KpiSummaryCard(
                      title: 'Total Users Registered',
                      value: '$displayUsers',
                      subtitle: card1Subtitle,
                      icon: Icons.people_alt_outlined,
                      color: AppTheme.primary,
                      trendText: '$displayStudents active',
                      isPositiveTrend: true,
                      badgeText: sectionBadge,
                      progress: (displayStudents / displayUsers).clamp(0.0, 1.0),
                      isDark: isDark,
                      compact: isMobile,
                    );
                    final card2 = KpiSummaryCard(
                      title: 'Active Course Enrollments',
                      value: '$displayEnrollments',
                      subtitle: card2Subtitle,
                      icon: Icons.menu_book_outlined,
                      color: AppTheme.accent,
                      trendText: '$displayEnrollments enrolled',
                      isPositiveTrend: true,
                      badgeText: courseBadge,
                      progress: 0.85,
                      isDark: isDark,
                      compact: isMobile,
                    );
                    final card3 = KpiSummaryCard(
                      title: 'Student Learning Progress',
                      value: '$displayAvgScore%',
                      subtitle: card3Subtitle,
                      icon: Icons.fact_check_outlined,
                      color: AppTheme.warning,
                      trendText: displayAvgScore >= 75 ? 'On Track' : 'Needs Review',
                      isPositiveTrend: displayAvgScore >= 75,
                      badgeText: unitBadge,
                      progress: (displayAvgScore / 100.0).clamp(0.0, 1.0),
                      isDark: isDark,
                      compact: isMobile,
                    );
                    final card4 = KpiSummaryCard(
                      title: 'Assessment Pass Rate',
                      value: '$displayPassRate%',
                      subtitle: card4Subtitle,
                      icon: Icons.verified_outlined,
                      color: AppTheme.success,
                      trendText: displayPassRate >= 75 ? 'Target Met' : 'Below Target',
                      isPositiveTrend: displayPassRate >= 75,
                      badgeText: 'Target: 75%',
                      progress: (displayPassRate / 100.0).clamp(0.0, 1.0),
                      isDark: isDark,
                      compact: isMobile,
                    );

                    // Desktop Wide View: 4 Columns in a single row
                    if (constraints.maxWidth >= 950) {
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
                    } else if (constraints.maxWidth >= 650) {
                      // Tablet Mid View: 2x2 Grid with standard cards
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: card1),
                              const SizedBox(width: 14),
                              Expanded(child: card2),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: card3),
                              const SizedBox(width: 14),
                              Expanded(child: card4),
                            ],
                          ),
                        ],
                      );
                    }

                    // Mobile View: 2x2 Compact Grid (cleanly fits on small phone screens)
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: card1),
                            const SizedBox(width: 10),
                            Expanded(child: card2),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: card3),
                            const SizedBox(width: 10),
                            Expanded(child: card4),
                          ],
                        ),
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

                // Interactive Learning Outcome (LO) Mastery Heatmap Matrix
                const LoMasteryMatrix(),
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
                            child: _buildSubjectEnrollmentsCard(subjectEnrollments, totalEnrollments, context, isDark),
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
                        _buildSubjectEnrollmentsCard(subjectEnrollments, totalEnrollments, context, isDark),
                        const SizedBox(height: 20),
                        _buildSectionDistributionCard(sectionDistribution, context, isDark),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Comprehensive 4-Tier Institutional Analytics Framework
                _buildInstitutionalFourTierCard(
                  totalStudents: totalStudents,
                  totalTeachers: totalTeachers,
                  totalSubjects: totalSubjects,
                  totalAttempts: totalAttempts,
                  passRate: passRate,
                  avgScore: avgScore,
                  subjectEnrollments: subjectEnrollments,
                  sectionDistribution: sectionDistribution,
                  demoAnalytics: demoAnalytics,
                  context: context,
                  isDark: isDark,
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

  // ── Institutional Four-Tier Analytics Framework Card ───────────────
  Widget _buildInstitutionalFourTierCard({
    required int totalStudents,
    required int totalTeachers,
    required int totalSubjects,
    required int totalAttempts,
    required int passRate,
    required int avgScore,
    required List<Map<String, dynamic>> subjectEnrollments,
    required List<Map<String, dynamic>> sectionDistribution,
    required CampusAdminDemoAnalytics demoAnalytics,
    required BuildContext context,
    required bool isDark,
  }) {
    final studentTeacherRatio = totalTeachers > 0
        ? (totalStudents / totalTeachers).toStringAsFixed(1)
        : 'N/A';
    final benchmarkMet = demoAnalytics.overallPassRate >= 75;
    final projectedNatReadiness = (demoAnalytics.averageScore * 0.92 + (benchmarkMet ? 6 : 0)).clamp(0, 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title & Framework Subtitle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.auto_graph_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'School Performance Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkText : AppTheme.lightText,
                      ),
                    ),
                    Text(
                      'Attendance, quiz scores, future estimates, and helpful next steps for your school.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Responsive 4-Tier Grid: 2x2 on Desktop/Tablet, 1-col on Mobile
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 850;

              final tier1Card = _buildCampusTierTile(
                tierBadge: 'Enrollment & Quizzes',
                tierBadgeColor: AppTheme.primary,
                friendlyTitle: 'Students, Teachers & Total Quizzes Taken',
                icon: Icons.history_edu_rounded,
                isDark: isDark,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildTierMetricChip('Enrolled Students', '$totalStudents', isDark),
                        _buildTierMetricChip('Active Faculty', '$totalTeachers', isDark),
                        _buildTierMetricChip('Courses', '$totalSubjects', isDark),
                        _buildTierMetricChip('Exams Taken', '$totalAttempts', isDark),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnalyticsBarChart(
                      items: subjectEnrollments.isNotEmpty
                          ? subjectEnrollments.take(5).map((s) {
                              final name = (s['code'] as String? ?? s['name'] as String? ?? 'Course').trim();
                              final count = (s['enrolled_count'] as num?)?.toDouble() ?? 0.0;
                              return BarChartItem(
                                label: name.length > 8 ? name.substring(0, 8) : name,
                                value: count,
                                color: AppTheme.primary,
                                tooltip: '${s['name']}: ${count.round()} students enrolled',
                              );
                            }).toList()
                          : const [
                              BarChartItem(label: 'STEM-01', value: 24.0, color: Color(0xFF0284C7)),
                              BarChartItem(label: 'HUMSS-02', value: 18.0, color: Color(0xFF0284C7)),
                              BarChartItem(label: 'ABM-01', value: 15.0, color: Color(0xFF0284C7)),
                              BarChartItem(label: 'TVL-03', value: 12.0, color: Color(0xFF0284C7)),
                              BarChartItem(label: 'GAS-01', value: 8.0, color: Color(0xFF0284C7)),
                            ],
                      maxValue: totalStudents.toDouble() > 0 ? totalStudents.toDouble() : 30.0,
                      valueSuffix: ' students',
                      height: 190,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Monthly Quizzes Taken by Students',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkText : AppTheme.lightText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnalyticsMultiLineChart(
                      series: demoAnalytics.monthlyAttemptSeries,
                      height: 155,
                      isDark: isDark,
                    ),
                  ],
                ),
              );

              final tier2Card = _buildCampusTierTile(
                tierBadge: 'Section Breakdown',
                tierBadgeColor: AppTheme.accent,
                friendlyTitle: 'Class Section Scores & Student Counts',
                icon: Icons.troubleshoot_rounded,
                isDark: isDark,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildTierMetricChip('Average Class Size', '${studentTeacherRatio.split(':').first.trim()} Students / Teacher', isDark),
                        _buildTierMetricChip('Sections Tracked', '${demoAnalytics.sectionComparisonBars.length}', isDark),
                        _buildTierMetricChip('Passing Target', '75% Pass', isDark),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnalyticsBarChart(
                      items: demoAnalytics.sectionComparisonBars,
                      legend: 'Average Score',
                      secondaryLegend: 'Pass Rate',
                      valueSuffix: '%',
                      height: 200,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${demoAnalytics.sectionComparisonBars.length} of ${demoAnalytics.sectionComparisonBars.length} sections are actively taking weekly quizzes on schedule.',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? AppTheme.darkText : AppTheme.lightText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              final tier3Card = _buildCampusTierTile(
                tierBadge: 'Academic Forecast',
                tierBadgeColor: AppTheme.warning,
                friendlyTitle: 'Estimated Passing Rates & Exam Readiness',
                icon: Icons.trending_up_rounded,
                isDark: isDark,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildTierMetricChip('Estimated Exam Readiness', '$projectedNatReadiness%', isDark),
                        _buildTierMetricChip('Student Risk Level', benchmarkMet ? 'Low' : 'Needs Review', isDark),
                        _buildTierMetricChip('Learning Speed', avgScore >= 80 ? 'Fast' : 'Steady', isDark),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        AnalyticsGaugeMeter(
                          value: (projectedNatReadiness > 0 ? projectedNatReadiness : 80).toDouble(),
                          label: 'Exam Ready',
                          statusText: benchmarkMet ? 'Target Met' : 'Needs Help',
                          size: 155,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: AnalyticsTrendChart(
                            points: [
                              const TrendPoint(label: 'Prelims', value: 74.0),
                              TrendPoint(label: 'Midterms', value: avgScore > 0 ? avgScore.toDouble() : 78.0),
                              TrendPoint(label: 'Projected', value: (projectedNatReadiness > 0 ? projectedNatReadiness : 82).toDouble()),
                            ],
                            height: 190,
                            baselineY: 75.0,
                            baselineLabel: 'Target 75%',
                            isDark: isDark,
                            lineColor: benchmarkMet ? AppTheme.success : AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final tier4Card = _buildCampusTierTile(
                tierBadge: 'School Action Plan',
                tierBadgeColor: AppTheme.success,
                friendlyTitle: 'Recommended Next Steps for Principal',
                icon: Icons.lightbulb_outline_rounded,
                isDark: isDark,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Helpful next actions based on your school\'s quiz results:',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    PrescriptiveActionCard(
                      title: benchmarkMet ? 'Share Top-Performing Study Guides' : 'Help Sections Needing Extra Practice',
                      description: benchmarkMet
                          ? 'Send enrichment worksheets and review guides to class sections.'
                          : 'Schedule remedial review for sections below 75% pass mark and give teachers extra consultation time.',
                      badgeText: benchmarkMet ? 'Excellence' : 'Intervention',
                      actionLabel: 'Send Action to Teachers',
                      priority: benchmarkMet ? PrescriptionPriority.recommended : PrescriptionPriority.warning,
                      isDark: isDark,
                      onAction: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(benchmarkMet
                                ? 'Enrichment guides sent to class sections.'
                                : 'Review worksheets sent to class sections.'),
                            backgroundColor: benchmarkMet ? AppTheme.success : AppTheme.warning,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      benchmarkMet
                          ? '1. Share lesson plans from top-performing sections with all teachers.\n2. Distribute advanced practice worksheets for high-scoring students.\n3. Review quiz questions quarterly to keep tests fair and clear.'
                          : '1. Set up extra review sessions for sections scoring below 75%.\n2. Distribute remedial review worksheets to help students prepare for upcoming quizzes.\n3. Give teachers extra consultation hours to tutor students who need help.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.darkText : AppTheme.lightText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Overall Student Grade Breakdown',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkText : AppTheme.lightText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnalyticsBarChart(
                      items: demoAnalytics.gradeDistributionBars,
                      height: 140,
                      valueSuffix: '%',
                      isDark: isDark,
                    ),
                  ],
                ),
              );

              if (isWide) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: tier1Card),
                        const SizedBox(width: 16),
                        Expanded(child: tier2Card),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: tier3Card),
                        const SizedBox(width: 16),
                        Expanded(child: tier4Card),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  tier1Card,
                  const SizedBox(height: 16),
                  tier2Card,
                  const SizedBox(height: 16),
                  tier3Card,
                  const SizedBox(height: 16),
                  tier4Card,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCampusTierTile({
    required String tierBadge,
    required Color tierBadgeColor,
    required String friendlyTitle,
    required IconData icon,
    required bool isDark,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tierBadgeColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tierBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tierBadgeColor,
                  ),
                ),
              ),
              const Spacer(),
              Icon(icon, size: 18, color: tierBadgeColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            friendlyTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
            ),
          ),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }

  Widget _buildTierMetricChip(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? AppTheme.darkBorderLight : AppTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
            ),
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
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isNarrow = headerConstraints.maxWidth < 480;
              final badgeWidget = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (benchmarkPassed ? AppTheme.success : AppTheme.warning).withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  benchmarkPassed ? 'Standard Met (75%+)' : 'Needs Review',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: benchmarkPassed ? AppTheme.success : AppTheme.warning,
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.pie_chart_outline_rounded, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Exam Results & Performance Overview',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkText : AppTheme.lightText,
                            ),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: badgeWidget,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Icon(Icons.pie_chart_outline_rounded, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Exam Results & Performance Overview',
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
                  badgeWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Donut Chart & Side Legend Breakdown
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 480;

              final chartWidget = SizedBox(
                width: 165,
                height: 165,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(165, 165),
                      painter: AnalyticsDonutPainter(
                        valueA: passedAttempts.toDouble(),
                        valueB: needsReview.toDouble(),
                        colorA: AppTheme.success,
                        colorB: AppTheme.warning,
                        trackColor: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                        strokeWidth: 20.0,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$passRate%',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkText : AppTheme.lightText,
                          ),
                        ),
                        Text(
                          'Pass Rate',
                          style: TextStyle(
                            fontSize: 11,
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
                    label: 'Passed Exams',
                    value: '$passedAttempts ($passRate%)',
                    color: AppTheme.success,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildMasteryMetricRow(
                    label: 'Needs Additional Review',
                    value: '$needsReview (${totalAttempts > 0 ? (100 - passRate) : 0}%)',
                    color: AppTheme.warning,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildMasteryMetricRow(
                    label: 'Overall Average Score',
                    value: '$avgScore%',
                    color: AppTheme.accent,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildMasteryMetricRow(
                    label: 'Total Assessments Completed',
                    value: '$totalAttempts ${totalAttempts == 1 ? 'Exam' : 'Exams'}',
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
                        ? 'The overall student pass rate complies with the academic accreditation standard of 75%.'
                        : 'Students need additional support to meet the academic accreditation standard of 75%.',
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
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isNarrow = headerConstraints.maxWidth < 460;
              final dirBtn = TextButton.icon(
                onPressed: () => context.go('/admin/students'),
                icon: Icon(Icons.arrow_forward, size: 13, color: AppTheme.primary),
                label: Text(
                  'Student Directory',
                  style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.assignment_ind_outlined, color: AppTheme.accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Student Enrollment & Class Assignments',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkText : AppTheme.lightText,
                            ),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: dirBtn,
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.assignment_ind_outlined, color: AppTheme.accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Student Enrollment & Class Assignments',
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
                  dirBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Section Assignment Progress Bar
          Row(
            children: [
              Expanded(
                child: Text(
                  'Section Assignment Status',
                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$assignedStudents of $totalStudents Assigned ($placementRate%)',
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
                    onTap: () => context.go('/admin/students?filter=unassigned'),
                    child: Text(
                      'Assign Section',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.warning, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Sleek Horizontal Lollipop Distribution Chart
          AnalyticsLollipopChart(
            items: [
              LollipopItem(
                label: 'Regular Track Cohort',
                subtitle: 'Full-load curriculum',
                value: (totalStudents > 0 ? (regular / totalStudents * 100) : 100).toDouble().clamp(0, 100),
                color: AppTheme.primary,
                badgeText: '$regular Students',
              ),
              LollipopItem(
                label: 'Section Placement',
                subtitle: 'Assigned to class sections',
                value: placementRate.toDouble().clamp(0, 100),
                color: AppTheme.accent,
                badgeText: '$assignedStudents / $totalStudents',
              ),
              LollipopItem(
                label: 'Special Track & Transferees',
                subtitle: 'SPED & Transferee accommodations',
                value: (totalStudents > 0 ? ((irregular + transferee + sped) / totalStudents * 100) : 0).toDouble().clamp(0, 100),
                color: const Color(0xFFF59E0B),
                badgeText: '${irregular + transferee + sped} Learners',
              ),
            ],
            maxValue: 100.0,
            baselineValue: 75.0,
            baselineLabel: '75% Target',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // ── Course Academic & Enrollment Registry ───────────────────────────
  Widget _buildSubjectEnrollmentsCard(List<Map<String, dynamic>> list, int totalEnrollments, BuildContext context, bool isDark) {
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
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isNarrow = headerConstraints.maxWidth < 450;
              final manageBtn = TextButton(
                onPressed: () => context.go('/admin/subjects'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Manage', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    Icon(Icons.chevron_right, size: 16, color: AppTheme.primary),
                  ],
                ),
              );

              return Row(
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
                            maxLines: isNarrow ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  manageBtn,
                ],
              );
            },
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

                return InkWell(
                  onTap: () {
                    final subId = sub['id'];
                    if (subId != null) {
                      context.go('/admin/subjects/$subId');
                    } else {
                      context.go('/admin/subjects');
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: LayoutBuilder(
                      builder: (context, rowConstraints) {
                        final isNarrow = rowConstraints.maxWidth < 420;
                        final codeBadge = Container(
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
                        );

                        final nameText = Text(
                          sub['name'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkText : AppTheme.lightText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );

                        final statsText = Text(
                          '$count students (${(percent * 100).toStringAsFixed(0)}%)'
                          '${subAttempts > 0 ? ' · $subPassRate% Pass' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        );

                        final progressBar = ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent.clamp(0.04, 1.0),
                            backgroundColor: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                            minHeight: 6,
                          ),
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  codeBadge,
                                  const SizedBox(width: 8),
                                  Expanded(child: nameText),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                ],
                              ),
                              const SizedBox(height: 4),
                              statsText,
                              const SizedBox(height: 6),
                              progressBar,
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      codeBadge,
                                      const SizedBox(width: 8),
                                      Expanded(child: nameText),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                statsText,
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                              ],
                            ),
                            const SizedBox(height: 6),
                            progressBar,
                          ],
                        );
                      },
                    ),
                  ),
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
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isNarrow = headerConstraints.maxWidth < 450;
              final manageSectionsBtn = TextButton(
                onPressed: () => context.go('/admin/sections'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Manage Sections', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    Icon(Icons.chevron_right, size: 16, color: AppTheme.primary),
                  ],
                ),
              );

              return Row(
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
                            maxLines: isNarrow ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  manageSectionsBtn,
                ],
              );
            },
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
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 420;
                final itemWidth = isNarrow ? (constraints.maxWidth - 10) / 2 : 140.0;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: list.map((sec) {
                    final sectionName = sec['section'] as String? ?? 'Unassigned';
                    final count = sec['count'] as int? ?? 0;
                    final isUnassigned = sectionName.toLowerCase() == 'unassigned';

                    return InkWell(
                      onTap: () {
                        if (isUnassigned) {
                          context.go('/admin/students?filter=unassigned');
                        } else {
                          context.go('/admin/students?section=${Uri.encodeComponent(sectionName)}');
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: itemWidth,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$count Students',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isUnassigned && count > 0 ? AppTheme.warning : AppTheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.chevron_right, size: 13, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
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
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isNarrow = headerConstraints.maxWidth < 450;
              final viewAllBtn = TextButton(
                onPressed: () => context.go('/admin/scores'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View All Scores', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    Icon(Icons.arrow_forward, size: 14, color: AppTheme.primary),
                  ],
                ),
              );

              return Row(
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
                            maxLines: isNarrow ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  viewAllBtn,
                ],
              );
            },
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
                    Stack(
                      children: [
                        UserAvatarWidget(
                          imageSource: (a['student_profile_image'] ?? a['profile_image'] ?? a['profileImage']) as String?,
                          fallbackInitial: student.isNotEmpty ? student[0].toUpperCase() : 'S',
                          size: 32,
                          backgroundColor: (isPassed ? AppTheme.success : AppTheme.error).withValues(alpha: isDark ? 0.18 : 0.12),
                          textColor: isPassed ? AppTheme.success : AppTheme.error,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              color: isPassed ? AppTheme.success : AppTheme.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppTheme.darkSurface : Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              isPassed ? Icons.check : Icons.close,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
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

  // ── Semester-End Archiving & System Renewal Card (Milestone 2) ────────
  Widget _buildSemesterRenewalCard(BuildContext context, WidgetRef ref, bool isDark) {
    final renewalState = ref.watch(semesterRenewalControllerProvider);
    final currentUser = ref.watch(authProvider);
    final activeSchoolId = ref.watch(activeAdminCampusProvider) ?? currentUser?.schoolId ?? 'sch_main';
    final schools = ref.watch(schoolsListProvider);
    final currentSchool = schools.firstWhere(
      (s) => s['id'] == activeSchoolId,
      orElse: () => <String, dynamic>{
        'name': 'AIRAMP Demonstration High School',
        'code': 'ADM-01',
      },
    );
    final schoolName = currentSchool['name']?.toString() ?? 'AIRAMP Demonstration High School';
    final schoolCode = currentSchool['code']?.toString() ?? 'ADM-01';

    final termDataAsync = ref.watch(campusAcademicTermProvider(activeSchoolId));
    final termData = termDataAsync.value ?? {
      'academic_year': 'AY 2025-2026',
      'current_semester': '1st Semester',
    };
    final activeAy = termData['academic_year'] ?? 'AY 2025-2026';
    final activeSem = termData['current_semester'] ?? '1st Semester';

    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final primaryTextColor = isDark ? AppTheme.darkTextBright : AppTheme.lightText;
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final isVerified = renewalState.isArchiveVerified && (renewalState.verificationResult?.isValid == true);

    return Container(
      key: const Key('semester_renewal_card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 980;

          final headerAndStatus = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Context Pills: Active Campus Scope + Active Academic Period
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance_outlined, size: 13, color: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary),
                        const SizedBox(width: 5),
                        Text(
                          '$schoolName ($schoolCode)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkPrimary.withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? AppTheme.darkPrimary : Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 13, color: isDark ? AppTheme.darkPrimary : Colors.blue.shade700),
                        const SizedBox(width: 5),
                        Text(
                          'Active Term: $activeSem · $activeAy',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkPrimary : Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isVerified
                          ? (isDark ? AppTheme.darkSuccess.withValues(alpha: 0.15) : const Color(0xFFDCFCE7))
                          : (isDark ? AppTheme.darkWarning.withValues(alpha: 0.15) : const Color(0xFFFEF3C7)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isVerified ? Icons.verified_user_rounded : Icons.pending_actions_rounded,
                      color: isVerified
                          ? (isDark ? AppTheme.darkSuccess : Colors.green.shade700)
                          : (isDark ? AppTheme.darkWarning : Colors.amber.shade800),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Semester-End Record Archiving & System Renewal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Safely archive institutional student transcripts and purge transient academic data for the new term.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Prerequisites & Guardrail Checklist Helper
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isVerified
                            ? '✓ Requirements Met: Academic ledger compiled and cryptographically verified. Ready to execute semester rollover.'
                            : 'Prerequisites to Unlock: 1. Generate & download permanent student ledger archive (.xlsx / .zip)  ➔  2. Validate SHA-256 integrity.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isVerified
                              ? (isDark ? AppTheme.darkSuccess : Colors.green.shade800)
                              : secondaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Status Badge
              Container(
                key: const Key('archive_status_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isVerified
                      ? (isDark ? AppTheme.darkSuccess.withValues(alpha: 0.15) : const Color(0xFFDCFCE7))
                      : (isDark ? AppTheme.darkWarning.withValues(alpha: 0.15) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isVerified
                        ? (isDark ? AppTheme.darkSuccess : Colors.green.shade400)
                        : (isDark ? AppTheme.darkWarning : Colors.amber.shade400),
                  ),
                ),
                child: Row(
                  mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    Icon(
                      isVerified ? Icons.check_circle_rounded : Icons.lock_clock_rounded,
                      size: 14,
                      color: isVerified
                          ? (isDark ? AppTheme.darkSuccess : Colors.green.shade700)
                          : (isDark ? AppTheme.darkWarning : Colors.amber.shade800),
                    ),
                    const SizedBox(width: 6),
                    if (isNarrow)
                      Expanded(
                        child: Text(
                          isVerified
                              ? 'Archive Verified (${renewalState.verificationResult?.studentCount ?? 0} Students) — Reset Trigger Unlocked'
                              : 'Archive Pending — Reset Trigger Safeguarded & Locked',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isVerified
                                ? (isDark ? AppTheme.darkSuccess : Colors.green.shade800)
                                : (isDark ? AppTheme.darkWarning : Colors.amber.shade900),
                          ),
                        ),
                      )
                    else
                      Text(
                        isVerified
                            ? 'Archive Verified (${renewalState.verificationResult?.studentCount ?? 0} Students) — Reset Trigger Unlocked'
                            : 'Archive Pending — Reset Trigger Safeguarded & Locked',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isVerified
                              ? (isDark ? AppTheme.darkSuccess : Colors.green.shade800)
                              : (isDark ? AppTheme.darkWarning : Colors.amber.shade900),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );

          // Buttons
          final actionButtons = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Action 1: Generate & Download Archive
              ElevatedButton.icon(
                key: const Key('btn_generate_archive'),
                onPressed: renewalState.isArchiveGenerating
                    ? null
                    : () async {
                        final result = await ref
                            .read(semesterRenewalControllerProvider.notifier)
                            .generateAndDownloadArchive(
                              schoolId: activeSchoolId,
                              academicYear: activeAy,
                              semester: activeSem,
                            );
                        if (context.mounted) {
                          if (result != null && result.isValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Excel & ZIP Archive verified successfully (${result.studentCount} students). Download dispatched.',
                                ),
                                backgroundColor: AppTheme.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result?.errorMessage ?? 'Failed to generate archive.',
                                ),
                                backgroundColor: AppTheme.danger,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                icon: renewalState.isArchiveGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.folder_zip_outlined, size: 16),
                label: Text(
                  renewalState.isArchiveGenerating
                      ? 'Compiling Archive...'
                      : 'Generate & Download Archive',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(0, 40),
                ),
              ),

              // Action 2: End of Semester Reset (Guarded)
              Tooltip(
                message: renewalState.isResetUnlocked
                    ? 'Execute guarded multi-step academic semester reset'
                    : 'Archive generation and verification is required to unlock semester reset',
                child: ElevatedButton.icon(
                  key: const Key('btn_end_of_semester_reset'),
                  onPressed: renewalState.isResetUnlocked
                      ? () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => AcademicTermResetModal(
                              schoolId: activeSchoolId,
                              adminId: currentUser?.id,
                            ),
                          );
                        }
                      : null,
                  icon: Icon(
                    renewalState.isResetUnlocked
                        ? Icons.restart_alt_rounded
                        : Icons.lock_outline_rounded,
                    size: 16,
                  ),
                  label: Text(
                    renewalState.isResetUnlocked
                        ? 'End of Semester Reset'
                        : 'End of Semester Reset (Locked)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade300,
                    disabledForegroundColor: isDark ? AppTheme.darkTextMuted : Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerAndStatus,
                const SizedBox(height: 16),
                actionButtons,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: headerAndStatus),
              const SizedBox(width: 20),
              actionButtons,
            ],
          );
        },
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
