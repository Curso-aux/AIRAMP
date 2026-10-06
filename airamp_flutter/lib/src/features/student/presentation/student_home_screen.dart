import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../admin/data/admin_repository.dart';
import '../../teacher/data/teacher_schedule_repository.dart';
import '../data/student_repository.dart';
import 'components/student_schedule_widget.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  bool _isAnalyticsHidden = false;
  // 0: Cards, 1: Pie / Donut, 2: Progress Gauge
  int _analyticsViewIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsPreferences();
  }

  Future<void> _loadAnalyticsPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isAnalyticsHidden = prefs.getBool('student_analytics_hidden') ?? false;
          _analyticsViewIndex = prefs.getInt('student_analytics_view_index') ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAnalyticsPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('student_analytics_hidden', _isAnalyticsHidden);
      await prefs.setInt('student_analytics_view_index', _analyticsViewIndex);
    } catch (_) {}
  }

  void _showNotificationsSheet(List<Map<String, dynamic>> announcements) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Announcements & Notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.text),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppTheme.border),
            Expanded(
              child: announcements.isEmpty
                  ? Center(
                      child: Text('No announcements at this time.', style: TextStyle(color: AppTheme.textMuted)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: announcements.length,
                      itemBuilder: (context, i) {
                        final a = announcements[i];
                        final priority = a['priority']?.toString() ?? 'medium';
                        final isHigh = priority.toLowerCase() == 'high';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isHigh ? AppTheme.warning : AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (_) {
                                  final sec = a['section']?.toString();
                                  final hasSpecificSec = sec != null &&
                                      sec.isNotEmpty &&
                                      sec != 'All Sections' &&
                                      sec != 'All Handled Sections';
                                  return Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isHigh
                                              ? AppTheme.warning.withValues(alpha: 0.2)
                                              : AppTheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          priority.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isHigh ? AppTheme.warning : AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                      if (hasSpecificSec) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surface,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: AppTheme.border),
                                          ),
                                          child: Text(
                                            'Section: $sec',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      Text(
                                        a['created_at'] != null ? a['created_at'].toString().split('T').first : '',
                                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                a['title']?.toString() ?? '',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 15),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                a['message']?.toString() ?? '',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                              ),
                              if (a['author_name'] != null && a['author_name'].toString().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 12, color: AppTheme.textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Posted by ${a['author_name']}',
                                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final currentUser = ref.watch(authProvider);
    final courses = ref.watch(studentCoursesProvider);
    final progress = ref.watch(studentProgressProvider);
    final allAnnouncements = ref.watch(announcementsProvider);

    if (currentUser == null) return const SizedBox.shrink();

    final activeCourses = courses.length;
    final lessonsDone = progress['completed'] ?? 0;
    final pending = progress['pending'] ?? 0;
    final assignedQuizzes = ref.watch(studentQuizAssignmentsProvider);
    final pendingQuizzes = assignedQuizzes.where((q) => q['status'] == 'pending').toList();

    // Filter announcements for students (considering audience and section)
    final studentSection = currentUser.section?.trim().toLowerCase();
    final studentAnnouncements = allAnnouncements.where((a) {
      final aud = (a['target_audience'] as String? ?? 'all').toLowerCase();
      if (aud != 'all' && aud != 'students') return false;

      final aSec = (a['section'] as String?)?.trim();
      if (aSec == null ||
          aSec.isEmpty ||
          aSec == 'All Sections' ||
          aSec == 'All Handled Sections') {
        return true;
      }
      if (studentSection != null && studentSection.isNotEmpty) {
        return aSec.toLowerCase() == studentSection;
      }
      return false;
    }).toList();

    // Determine Continue Learning subject
    Map<String, dynamic>? activeCourse;
    if (courses.isNotEmpty) {
      activeCourse = courses.firstWhere(
        (c) => ((c['completed_los'] as int? ?? 0) < (c['total_los'] as int? ?? 1)),
        orElse: () => courses.first,
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1050;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
          onRefresh: () async {
            if (currentUser.section != null && currentUser.section!.isNotEmpty) {
              ref.invalidate(sectionSchedulesProvider(currentUser.section!.trim()));
            }
            ref.invalidate(allClassSchedulesProvider);
            ref.invalidate(scheduledSectionsProvider);
            await Future.wait([
              ref.read(studentCoursesProvider.notifier).reload(),
              ref.read(studentProgressProvider.notifier).loadProgress(),
              ref.read(studentQuizAssignmentsProvider.notifier).reload(),
            ]);
            ref.invalidate(announcementsProvider);
          },
          color: AppTheme.primary,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 20,
              vertical: isDesktop ? 20 : 10,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                              ),
                              Text(
                                currentUser.fullName,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _buildScheduleHeaderButton(context, currentUser.section),
                            const SizedBox(width: 8),
                            _buildBellButton(studentAnnouncements),
                            const SizedBox(width: 8),
                            _buildProfileAvatarButton(context, currentUser),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Responsive Body: 2 Columns on Desktop, 1 Column on Mobile
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column (flex: 7): Stats, Continue Learning, Class Schedule
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildAnalyticsSection(activeCourses, lessonsDone, pending),
                                const SizedBox(height: 24),
                                _buildContinueLearningSection(context, activeCourse),
                                const SizedBox(height: 24),
                                StudentScheduleWidget(sectionName: currentUser.section),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Right Column (flex: 5): Quizzes, Announcements
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildQuizzesSection(context, pendingQuizzes),
                                const SizedBox(height: 24),
                                _buildAnnouncementsSection(studentAnnouncements),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAnalyticsSection(activeCourses, lessonsDone, pending),
                          const SizedBox(height: 20),
                          StudentScheduleWidget(sectionName: currentUser.section),
                          const SizedBox(height: 16),
                          _buildQuizzesSection(context, pendingQuizzes),
                          const SizedBox(height: 32),
                          _buildAnnouncementsSection(studentAnnouncements),
                          const SizedBox(height: 32),
                          _buildContinueLearningSection(context, activeCourse),
                        ],
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
);
  }

  Widget _buildAnalyticsSection(int activeCourses, int lessonsDone, int pending) {
    final totalLessons = lessonsDone + pending;
    final completionPct = totalLessons > 0 ? ((lessonsDone / totalLessons) * 100).round() : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isAnalyticsHidden) {
      return _buildCollapsedStrip(activeCourses, lessonsDone, pending, completionPct);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Title, View Toggles & Hide Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.insights_rounded,
                    color: AppTheme.primary,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Learning Overview',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                      if (totalLessons > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$completionPct% Done',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // View Mode Switcher: Cards, Pie / Donut, Progress Gauge
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildViewModeButton(0, Icons.grid_view_rounded, 'Cards View'),
                      _buildViewModeButton(1, Icons.pie_chart_rounded, 'Pie / Donut View'),
                      _buildViewModeButton(2, Icons.trending_up_rounded, 'Progress Mastery'),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Collapse / Hide Toggle Button
                Tooltip(
                  message: 'Hide Analytics',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _isAnalyticsHidden = true;
                      });
                      _saveAnalyticsPreferences();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.visibility_off_outlined,
                        size: 18,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.border.withValues(alpha: 0.6)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildCurrentAnalyticsView(activeCourses, lessonsDone, pending),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedStrip(int activeCourses, int lessonsDone, int pending, int completionPct) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        setState(() {
          _isAnalyticsHidden = false;
        });
        _saveAnalyticsPreferences();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceLight.withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.insights_rounded, size: 14, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$activeCourses Courses  •  $lessonsDone Done  •  $pending Pending  ($completionPct% Complete)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Show',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeButton(int index, IconData icon, String tooltip) {
    final isSelected = _analyticsViewIndex == index;
    final primary = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            _analyticsViewIndex = index;
          });
          _saveAnalyticsPreferences();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 15,
            color: isSelected ? Colors.black : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentAnalyticsView(int activeCourses, int lessonsDone, int pending) {
    switch (_analyticsViewIndex) {
      case 1:
        return _buildPieChartView(activeCourses, lessonsDone, pending);
      case 2:
        return _buildProgressGaugeView(activeCourses, lessonsDone, pending);
      case 0:
      default:
        return _buildCardsView(activeCourses, lessonsDone, pending);
    }
  }

  Widget _buildCardsView(int activeCourses, int lessonsDone, int pending) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Active Courses', Icons.book_outlined, activeCourses.toString(), AppTheme.primary)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Lessons Done', Icons.check_circle_outline_rounded, lessonsDone.toString(), AppTheme.success)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Pending', Icons.schedule_rounded, pending.toString(), AppTheme.warning)),
      ],
    );
  }

  Widget _buildPieChartView(int activeCourses, int lessonsDone, int pending) {
    final total = lessonsDone + pending;
    final completionPct = total > 0 ? ((lessonsDone / total) * 100).round() : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Donut Chart Graphic
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(120, 120),
                painter: DonutChartPainter(
                  completed: lessonsDone.toDouble(),
                  pending: pending.toDouble(),
                  courses: activeCourses.toDouble(),
                  isDark: isDark,
                  completedColor: AppTheme.success,
                  pendingColor: AppTheme.warning,
                  coursesColor: AppTheme.primary,
                  trackColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$completionPct%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    total > 0 ? 'COMPLETE' : 'NO DATA',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),

        // Legend Breakdown List
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChartLegendItem(
                label: 'Lessons Done',
                value: '$lessonsDone',
                color: AppTheme.success,
                subtext: total > 0 ? '${((lessonsDone / total) * 100).round()}% of coursework' : 'None yet',
              ),
              const SizedBox(height: 8),
              _buildChartLegendItem(
                label: 'Pending Lessons',
                value: '$pending',
                color: AppTheme.warning,
                subtext: total > 0 ? '${((pending / total) * 100).round()}% remaining' : 'Up to date',
              ),
              const SizedBox(height: 8),
              _buildChartLegendItem(
                label: 'Enrolled Courses',
                value: '$activeCourses',
                color: AppTheme.primary,
                subtext: 'Active curriculum',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartLegendItem({
    required String label,
    required String value,
    required Color color,
    required String subtext,
  }) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressGaugeView(int activeCourses, int lessonsDone, int pending) {
    final total = lessonsDone + pending;
    final double progressRatio = total > 0 ? (lessonsDone / total).clamp(0.0, 1.0) : 0.0;
    final int completionPct = (progressRatio * 100).round();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String statusText;
    final Color statusColor;
    final IconData statusIcon;

    if (total == 0 && activeCourses == 0) {
      statusText = 'Enroll in a course to begin your learning journey!';
      statusColor = AppTheme.textMuted;
      statusIcon = Icons.school_outlined;
    } else if (total == 0) {
      statusText = 'Ready to begin your lessons!';
      statusColor = AppTheme.primary;
      statusIcon = Icons.flag_outlined;
    } else if (completionPct == 100) {
      statusText = 'All caught up! Outstanding work!';
      statusColor = AppTheme.success;
      statusIcon = Icons.celebration_rounded;
    } else if (completionPct >= 50) {
      statusText = 'Great momentum! Over halfway through.';
      statusColor = AppTheme.primary;
      statusIcon = Icons.rocket_launch_rounded;
    } else {
      statusText = '$pending pending lessons remaining.';
      statusColor = AppTheme.warning;
      statusIcon = Icons.trending_up_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Curriculum Mastery',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$lessonsDone of $total lessons completed',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: (completionPct >= 100 ? AppTheme.success : AppTheme.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$completionPct%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: completionPct >= 100 ? AppTheme.success : AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Gradient Linear Progress Track
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                height: 9,
                width: double.infinity,
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
              FractionallySizedBox(
                widthFactor: progressRatio > 0 ? progressRatio : 0.001,
                child: Container(
                  height: 9,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary,
                        AppTheme.success,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Status Banner & Quick Metrics
        Row(
          children: [
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildMiniMetricChip('Courses: $activeCourses', AppTheme.primary),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniMetricChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildQuizzesSection(BuildContext context, List<Map<String, dynamic>> pendingQuizzes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.quiz_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Assigned Quizzes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
              ],
            ),
            if (pendingQuizzes.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${pendingQuizzes.length} Due',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.warning),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (pendingQuizzes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.task_alt, color: AppTheme.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All caught up! No pending quizzes assigned right now.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else if (pendingQuizzes.length >= 3)
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: pendingQuizzes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildQuizCard(pendingQuizzes[index]),
            ),
          )
        else
          ...pendingQuizzes.map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildQuizCard(q),
              )),
      ],
    );
  }

  Widget _buildAnnouncementsSection(List<Map<String, dynamic>> studentAnnouncements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.campaign, color: AppTheme.warning, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Announcements',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
              ],
            ),
            if (studentAnnouncements.isNotEmpty)
              GestureDetector(
                onTap: () => _showNotificationsSheet(studentAnnouncements),
                child: Text(
                  'View All (${studentAnnouncements.length})',
                  style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (studentAnnouncements.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text('No announcements at this time.', style: TextStyle(color: AppTheme.textMuted)),
          )
        else
          _buildAnnouncementCard(
            title: studentAnnouncements.first['title']?.toString() ?? '',
            body: studentAnnouncements.first['message']?.toString() ?? '',
            priority: studentAnnouncements.first['priority']?.toString() ?? 'medium',
            section: studentAnnouncements.first['section']?.toString(),
            authorName: studentAnnouncements.first['author_name']?.toString(),
          ),
      ],
    );
  }

  Widget _buildContinueLearningSection(BuildContext context, Map<String, dynamic>? activeCourse) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.play_circle_outline, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Continue Learning',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (activeCourse != null)
          _buildContinueLearningCard(
            id: activeCourse['id'] as int,
            subject: activeCourse['name']?.toString() ?? '',
            code: activeCourse['subject_code']?.toString() ?? '',
            progressPct: (activeCourse['progress'] as int?) ?? 0,
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                Icon(Icons.school_outlined, size: 36, color: AppTheme.textMuted),
                const SizedBox(height: 8),
                Text(
                  'Enroll in a course to begin learning',
                  style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go('/student/courses'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Browse Courses', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard(String title, IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleHeaderButton(BuildContext context, String? section) {
    return Tooltip(
      message: 'View Class Timetable & Teacher Schedules',
      child: GestureDetector(
        onTap: () => showStudentTimetableModal(context, initialSection: section),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
          ),
          child: Center(
            child: Icon(Icons.calendar_month_outlined, color: AppTheme.primary, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildBellButton(List<Map<String, dynamic>> announcements) {
    return GestureDetector(
      onTap: () => _showNotificationsSheet(announcements),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.notifications_none, color: AppTheme.text, size: 22),
            if (announcements.isNotEmpty)
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatarButton(BuildContext context, User currentUser) {
    return _StudentHeaderAvatarButton(
      currentUser: currentUser,
      onTap: () => context.go('/student/profile'),
    );
  }

  Widget _buildAnnouncementCard({
    required String title,
    required String body,
    required String priority,
    String? section,
    String? authorName,
  }) {
    final isHigh = priority.toLowerCase() == 'high';
    final hasSpecificSec = section != null && section.isNotEmpty && section != 'All Sections' && section != 'All Handled Sections';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isHigh ? AppTheme.warning : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isHigh ? AppTheme.warning.withValues(alpha: 0.2) : AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isHigh ? AppTheme.warning : AppTheme.primary,
                  ),
                ),
              ),
              if (hasSpecificSec) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    'Section: $section',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (authorName != null && authorName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 12, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  'By $authorName',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContinueLearningCard({
    required int id,
    required String subject,
    required String code,
    required int progressPct,
  }) {
    return InkWell(
      onTap: () => context.push('/student/course/$id'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.book, color: AppTheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(code, style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    subject,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text('$progressPct% completed', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard(Map<String, dynamic> q) {
    final title = q['title']?.toString() ?? 'Quiz';
    final subjectCode = q['subject_code']?.toString() ?? '';
    final teacherName = q['teacher_name']?.toString() ?? '';
    final qCount = q['question_count'] ?? 0;
    final timeLimit = q['time_limit_minutes'] ?? 0;
    final dueDate = q['due_date']?.toString();
    final quizId = q['quiz_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (subjectCode.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subjectCode,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (dueDate != null && dueDate.isNotEmpty)
                _buildDueDateBadge(dueDate),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.help_outline, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text('$qCount questions', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(width: 14),
              Icon(Icons.timer_outlined, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                timeLimit > 0 ? '${timeLimit}m limit' : 'Untimed',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              if (teacherName.isNotEmpty) ...[
                const SizedBox(width: 14),
                Icon(Icons.person_outline, size: 13, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    teacherName,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (quizId != null) {
                  await context.push('/quiz/$quizId');
                  if (context.mounted) {
                    ref.read(studentQuizAssignmentsProvider.notifier).reload();
                    ref.read(studentProgressProvider.notifier).loadProgress();
                    ref.read(studentCoursesProvider.notifier).reload();
                  }
                }
              },
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Start Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateBadge(String rawDate) {
    DateTime? dt = DateTime.tryParse(rawDate);
    if (dt == null) {
      final sanitized = rawDate.replaceAll('T', ' ');
      dt = DateTime.tryParse(sanitized);
    }

    String label;
    Color badgeColor;

    if (dt == null) {
      label = rawDate.length > 10 ? rawDate.substring(0, 10) : rawDate;
      badgeColor = AppTheme.error;
    } else {
      final now = DateTime.now();
      final diff = dt.difference(now);

      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthStr = months[dt.month - 1];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final timeStr = '$hour:$minute $period';

      if (diff.isNegative) {
        label = 'Overdue ($monthStr ${dt.day})';
        badgeColor = AppTheme.error;
      } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        label = 'Due Today • $timeStr';
        badgeColor = AppTheme.warning;
      } else if (diff.inHours < 48 && dt.day == now.add(const Duration(days: 1)).day) {
        label = 'Due Tomorrow • $timeStr';
        badgeColor = AppTheme.warning;
      } else if (diff.inDays < 7) {
        label = 'Due in ${diff.inDays}d • $timeStr';
        badgeColor = AppTheme.primary;
      } else {
        label = 'Due $monthStr ${dt.day} • $timeStr';
        badgeColor = AppTheme.textSecondary;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 11, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
          ),
        ],
      ),
    );
  }
}

/// A modern, tactile, interactive student profile avatar button for the dashboard header.
///
/// Features:
/// - Outer interactive accent ring line with subtle depth and glow.
/// - Clean separation gap to prevent obstructing the user's avatar/initial.
/// - Side clickable indicator badge (subtle chevron indicator) signaling interaction without blocking the center.
/// - Haptic press and hover scaling feedback.
class _StudentHeaderAvatarButton extends StatefulWidget {
  final User currentUser;
  final VoidCallback onTap;

  const _StudentHeaderAvatarButton({
    required this.currentUser,
    required this.onTap,
  });

  @override
  State<_StudentHeaderAvatarButton> createState() =>
      _StudentHeaderAvatarButtonState();
}

class _StudentHeaderAvatarButtonState
    extends State<_StudentHeaderAvatarButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.currentUser.profileImage != null &&
        widget.currentUser.profileImage!.isNotEmpty;
    final initial = widget.currentUser.fullName.isNotEmpty
        ? widget.currentUser.fullName[0].toUpperCase()
        : '?';

    return Tooltip(
      message: 'My Profile & Account Settings',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.92 : (_isHovered ? 1.05 : 1.0),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Outer interactive accent ring line with glow
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primary,
                        AppTheme.primary.withValues(alpha: 0.45),
                        AppTheme.primaryDark,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: _isHovered ? 0.45 : 0.25),
                        blurRadius: _isHovered ? 10 : 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.background,
                    ),
                    child: ClipOval(
                      child: hasImage
                          ? Image.network(
                              widget.currentUser.profileImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildFallbackInitial(initial),
                            )
                          : _buildFallbackInitial(initial),
                    ),
                  ),
                ),

                // Sleek clickable line indicator on the side / bottom-right
                Positioned(
                  right: -2,
                  bottom: -1,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.background,
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 11,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackInitial(String initial) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary,
            AppTheme.primaryDark,
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for rendering a modern, sleek donut chart breakdown
/// for the student analytics overview.
class DonutChartPainter extends CustomPainter {
  final double completed;
  final double pending;
  final double courses;
  final bool isDark;
  final Color completedColor;
  final Color pendingColor;
  final Color coursesColor;
  final Color trackColor;

  const DonutChartPainter({
    required this.completed,
    required this.pending,
    required this.courses,
    required this.isDark,
    required this.completedColor,
    required this.pendingColor,
    required this.coursesColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 11.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // 1. Background Track Ring
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

    // 2. Completed Lessons Slice (Success)
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

    // 3. Pending Lessons Slice (Warning)
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
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.completed != completed ||
        oldDelegate.pending != pending ||
        oldDelegate.courses != courses ||
        oldDelegate.isDark != isDark ||
        oldDelegate.completedColor != completedColor ||
        oldDelegate.pendingColor != pendingColor ||
        oldDelegate.trackColor != trackColor;
  }
}



