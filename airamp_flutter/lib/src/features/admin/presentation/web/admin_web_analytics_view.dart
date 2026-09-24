import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../data/admin_repository.dart';
import 'components/analytics_filter_bar.dart';

class AdminWebAnalyticsView extends ConsumerWidget {
  const AdminWebAnalyticsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome & Refresh Banner
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'School Analytics & Operations',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Live institutional metrics, student enrollments, and academic performance',
                          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(adminAnalyticsProvider.notifier).loadAnalytics(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surface,
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Compact Popover / Collapsible Filter Bar
              const AnalyticsFilterBar(),
              const SizedBox(height: 24),

              // Empty State when filter yields nothing
              if (!hasData && filter.hasActiveFilters)
                _buildEmptyFilterState(context, ref, filter)
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final card1Subtitle = filter.hasActiveFilters
                        ? '$totalStudents Students matching filters'
                        : '$totalStudents Students · $totalTeachers Teachers · $totalAdmins Admins';

                    final card2Subtitle = filter.subjectName != null
                        ? 'Enrolled in ${filter.subjectName}'
                        : (filter.section != null && filter.section != 'All Sections')
                            ? 'Enrollments in ${filter.section}'
                            : 'Across $totalSubjects subjects offered';

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
                        ? '$passedAttempts passed of $totalAttempts attempts ($tfLabel · Avg: $avgScore%)'
                        : '0 attempts for active filters ($tfLabel)';

                    final card1 = _buildKpiCard(
                      title: 'Total Users Registered',
                      value: '$totalUsers',
                      subtitle: card1Subtitle,
                      icon: Icons.people_alt_outlined,
                      color: AppTheme.primary,
                    );
                    final card2 = _buildKpiCard(
                      title: 'Active Course Enrollments',
                      value: '$totalEnrollments',
                      subtitle: card2Subtitle,
                      icon: Icons.school_outlined,
                      color: AppTheme.accent,
                    );
                    final card3 = _buildKpiCard(
                      title: 'Curriculum & Content',
                      value: '$totalSubjects Courses',
                      subtitle: card3Subtitle,
                      icon: Icons.auto_stories_outlined,
                      color: AppTheme.warning,
                    );
                    final card4 = _buildKpiCard(
                      title: 'Assessment Pass Rate',
                      value: '$passRate%',
                      subtitle: card4Subtitle,
                      icon: Icons.military_tech_outlined,
                      color: AppTheme.success,
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

                // Two-Column Section: Subject Enrollments & Section Breakdown
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildSubjectEnrollmentsCard(subjectEnrollments, totalEnrollments),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: _buildSectionDistributionCard(sectionDistribution, context),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        _buildSubjectEnrollmentsCard(subjectEnrollments, totalEnrollments),
                        const SizedBox(height: 20),
                        _buildSectionDistributionCard(sectionDistribution, context),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Recent Assessment Activity & Quick Links
                _buildRecentActivitySection(recentAttempts, context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState(BuildContext context, WidgetRef ref, AnalyticsFilter filter) {
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.filter_alt_off_rounded, size: 48, color: AppTheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'No Analytics Found for Filter Criteria',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              'No registered students, course enrollments, or quiz submissions match your combined filter dimensions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
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
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(badge, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.read(analyticsFilterProvider.notifier).reset(),
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Reset All Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectEnrollmentsCard(List<Map<String, dynamic>> list, int totalEnrollments) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
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
                    Icon(Icons.bar_chart, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Subject Enrollment Popularity',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
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
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No subjects added yet.', style: TextStyle(color: AppTheme.textMuted)),
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
                final double percent = totalEnrollments > 0 ? (count / totalEnrollments) : 0.0;

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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sub['code'] as String? ?? '',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  sub['name'] as String? ?? '',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$count student${count == 1 ? '' : 's'} (${(percent * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: percent.clamp(0.05, 1.0),
                        backgroundColor: AppTheme.background,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          index % 2 == 0 ? AppTheme.primary : AppTheme.accent,
                        ),
                        minHeight: 8,
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

  Widget _buildSectionDistributionCard(List<Map<String, dynamic>> list, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
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
                    Icon(Icons.groups, color: AppTheme.accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Student Sections & Distribution',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
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
                    Text('Manage', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
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
                child: Text('No students registered yet.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: list.map((sec) {
                final sectionName = sec['section'] as String? ?? 'Unassigned';
                final count = sec['count'] as int? ?? 0;

                return Container(
                  width: 140,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sectionName,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$count Students',
                        style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
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

  Widget _buildRecentActivitySection(List<Map<String, dynamic>> attempts, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
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
                    Icon(Icons.history, color: AppTheme.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recent Student Assessments',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
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
                    Text('View All Scores', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
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
                child: Text('No quiz submissions recorded yet.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: attempts.length,
              separatorBuilder: (_, _) => const Divider(height: 16),
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
                      radius: 16,
                      backgroundColor: isPassed ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.error.withValues(alpha: 0.15),
                      child: Icon(
                        isPassed ? Icons.check : Icons.close,
                        size: 16,
                        color: isPassed ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$student ($section)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                          ),
                          Text(
                            '$subject · $lo',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPassed ? AppTheme.success.withValues(alpha: 0.12) : AppTheme.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$score/$total (${isPassed ? 'Passed' : 'Failed'})',
                        style: TextStyle(
                          fontSize: 12,
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
}
