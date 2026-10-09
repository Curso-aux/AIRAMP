import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/components/analytics_donut_chart.dart';
import '../../auth/application/auth_provider.dart';
import '../data/admin_repository.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isAnalyticsHidden = false;
  int _analyticsViewIndex = 0; // 0: Cards View, 1: Donut Breakdown, 2: Academic Benchmark

  @override
  void initState() {
    super.initState();
    _loadAnalyticsPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
    });
  }

  Future<void> _loadAnalyticsPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isAnalyticsHidden = prefs.getBool('admin_analytics_hidden') ?? false;
          _analyticsViewIndex = prefs.getInt('admin_analytics_view_index') ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAnalyticsPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('admin_analytics_hidden', _isAnalyticsHidden);
      await prefs.setInt('admin_analytics_view_index', _analyticsViewIndex);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final currentUser = ref.watch(authProvider);
    final announcements = ref.watch(announcementsProvider);
    final subjects = ref.watch(subjectsProvider);
    final sections = ref.watch(sectionsProvider);
    final analytics = ref.watch(adminAnalyticsProvider);

    final subjectsCount = subjects.length;
    final sectionsCount = sections.length;
    final totalStudents = analytics['totalStudents'] as int? ?? 0;
    final totalTeachers = analytics['totalTeachers'] as int? ?? 0;
    final totalAttempts = analytics['totalAttempts'] as int? ?? 0;
    final passedAttempts = analytics['passedAttempts'] as int? ?? 0;
    final passRate = analytics['passRate'] as int? ?? 0;
    final avgScore = analytics['avgScore'] as int? ?? 0;
    
    final initial = currentUser?.fullName.isNotEmpty == true 
        ? currentUser!.fullName[0].toUpperCase() 
        : 'T';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Dashboard', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                      Text(
                        currentUser?.fullName ?? 'Teacher John Reyes',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      initial,
                      style: const TextStyle(fontSize: 24, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Institutional Analytics Section (Multi-View: Cards, Donut, Benchmark)
              _buildAnalyticsSection(
                context,
                totalStudents: totalStudents,
                totalTeachers: totalTeachers,
                totalSubjects: subjectsCount,
                sectionsCount: sectionsCount,
                totalAttempts: totalAttempts,
                passedAttempts: passedAttempts,
                passRate: passRate,
                avgScore: avgScore,
              ),
              const SizedBox(height: 28),

              // Announcements Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.campaign, color: AppTheme.warning, size: 20),
                      const SizedBox(width: 8),
                      Text('Announcements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _showPostAnnouncementSheet(context, ref),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.add, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (announcements.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    'No announcements yet. Post one for your students.',
                    style: TextStyle(color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                  ),
                )
              else
                ...announcements.map((a) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: a['priority'] == 'Important' ? AppTheme.error : AppTheme.border,
                      width: a['priority'] == 'Important' ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              a['title'],
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold, 
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (a['priority'] == 'Important')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.errorSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Important',
                                style: TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 20),
                            color: Theme.of(context).colorScheme.surface,
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showPostAnnouncementSheet(context, ref, initialAnnouncement: a);
                              } else if (value == 'delete') {
                                ref.read(announcementsProvider.notifier).deleteAnnouncement(a['id']);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit', style: TextStyle(color: AppTheme.text)),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete', style: TextStyle(color: AppTheme.error)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a['message'],
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.people_outline, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                          const SizedBox(width: 4),
                          Text(
                            a['target_audience'],
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      )
                    ],
                  ),
                )),

              const SizedBox(height: 32),

              // Subjects Overview Section
              Text('Subjects Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Center(
                  child: Text(
                    'No subjects available',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsSection(
    BuildContext context, {
    required int totalStudents,
    required int totalTeachers,
    required int totalSubjects,
    required int sectionsCount,
    required int totalAttempts,
    required int passedAttempts,
    required int passRate,
    required int avgScore,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isAnalyticsHidden) {
      return _buildCollapsedStrip(
        context,
        totalStudents: totalStudents,
        totalTeachers: totalTeachers,
        totalSubjects: totalSubjects,
        passRate: passRate,
      );
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
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Institutional Overview',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: (passRate >= 75 ? AppTheme.success : AppTheme.primary).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          totalAttempts > 0 ? '$passRate% Pass Rate' : '$totalStudents Students',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: passRate >= 75 ? AppTheme.success : AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // View Mode Switcher: Cards, Donut, Benchmark
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
                      _buildAnalyticsViewModeBtn(0, Icons.grid_view_rounded, 'Cards View'),
                      _buildAnalyticsViewModeBtn(1, Icons.pie_chart_rounded, 'Donut Breakdown'),
                      _buildAnalyticsViewModeBtn(2, Icons.trending_up_rounded, 'Campus Benchmark'),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Collapse / Hide Button
                Tooltip(
                  message: 'Hide Analytics',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      HapticFeedback.lightImpact();
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
            child: _buildCurrentAdminAnalyticsView(
              context,
              totalStudents: totalStudents,
              totalTeachers: totalTeachers,
              totalSubjects: totalSubjects,
              sectionsCount: sectionsCount,
              totalAttempts: totalAttempts,
              passedAttempts: passedAttempts,
              passRate: passRate,
              avgScore: avgScore,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedStrip(
    BuildContext context, {
    required int totalStudents,
    required int totalTeachers,
    required int totalSubjects,
    required int passRate,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _isAnalyticsHidden = false;
        });
        _saveAnalyticsPreferences();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceLight.withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.insights_rounded, size: 15, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$totalStudents Students  •  $totalTeachers Faculty  •  $totalSubjects Subjects  •  $passRate% Pass Rate',
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

  Widget _buildAnalyticsViewModeBtn(int index, IconData icon, String tooltip) {
    final isSelected = _analyticsViewIndex == index;
    final primary = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          HapticFeedback.lightImpact();
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

  Widget _buildCurrentAdminAnalyticsView(
    BuildContext context, {
    required int totalStudents,
    required int totalTeachers,
    required int totalSubjects,
    required int sectionsCount,
    required int totalAttempts,
    required int passedAttempts,
    required int passRate,
    required int avgScore,
  }) {
    switch (_analyticsViewIndex) {
      case 1:
        return _buildAdminDonutView(
          context,
          totalStudents: totalStudents,
          totalTeachers: totalTeachers,
          totalAttempts: totalAttempts,
          passedAttempts: passedAttempts,
          passRate: passRate,
          avgScore: avgScore,
        );
      case 2:
        return _buildAdminGaugeView(
          context,
          totalStudents: totalStudents,
          totalTeachers: totalTeachers,
          totalAttempts: totalAttempts,
          passedAttempts: passedAttempts,
          passRate: passRate,
          avgScore: avgScore,
        );
      case 0:
      default:
        return _buildAdminCardsView(
          context,
          totalStudents: totalStudents,
          totalTeachers: totalTeachers,
          totalSubjects: totalSubjects,
          sectionsCount: sectionsCount,
          passRate: passRate,
          avgScore: avgScore,
        );
    }
  }

  Widget _buildAdminCardsView(
    BuildContext context, {
    required int totalStudents,
    required int totalTeachers,
    required int totalSubjects,
    required int sectionsCount,
    required int passRate,
    required int avgScore,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(context, 'Students', Icons.people_outline, totalStudents.toString(), color: AppTheme.primary)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(context, 'Faculty', Icons.badge_outlined, totalTeachers.toString(), color: const Color(0xFF0D9488))),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(context, 'Subjects', Icons.menu_book, totalSubjects.toString(), color: AppTheme.accent)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(context, 'Sections', Icons.layers, sectionsCount.toString(), color: AppTheme.textSecondary)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(context, 'Pass Rate', Icons.verified_outlined, '$passRate%', color: passRate >= 75 ? AppTheme.success : AppTheme.warning)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(context, 'Avg Score', Icons.trending_up, '$avgScore%', color: AppTheme.accent)),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminDonutView(
    BuildContext context, {
    required int totalStudents,
    required int totalTeachers,
    required int totalAttempts,
    required int passedAttempts,
    required int passRate,
    required int avgScore,
  }) {
    final needsReview = (totalAttempts - passedAttempts).clamp(0, totalAttempts);
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
                painter: AnalyticsDonutPainter(
                  valueA: passedAttempts.toDouble(),
                  valueB: needsReview.toDouble(),
                  colorA: AppTheme.success,
                  colorB: AppTheme.warning,
                  trackColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$passRate%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    totalAttempts > 0 ? 'PASS RATE' : 'CAMPUS',
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
              _buildAdminChartLegendItem(
                label: 'Passed Quizzes',
                value: '$passedAttempts',
                color: AppTheme.success,
                subtext: totalAttempts > 0 ? '$passRate% institutional pass rate' : 'No quiz attempts yet',
              ),
              const SizedBox(height: 8),
              _buildAdminChartLegendItem(
                label: 'Needs Attention',
                value: '$needsReview',
                color: AppTheme.warning,
                subtext: totalAttempts > 0 ? '${100 - passRate}% attempts below pass mark' : 'Clear',
              ),
              const SizedBox(height: 8),
              _buildAdminChartLegendItem(
                label: 'Registered Students',
                value: '$totalStudents',
                color: AppTheme.primary,
                subtext: 'Active learners in system',
              ),
              const SizedBox(height: 8),
              _buildAdminChartLegendItem(
                label: 'Faculty & Teachers',
                value: '$totalTeachers',
                color: const Color(0xFF0D9488),
                subtext: 'Instructional staff',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdminChartLegendItem({
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

  Widget _buildAdminGaugeView(
    BuildContext context, {
    required int totalStudents,
    required int totalTeachers,
    required int totalAttempts,
    required int passedAttempts,
    required int passRate,
    required int avgScore,
  }) {
    final double passRatio = (passRate / 100.0).clamp(0.0, 1.0);
    final double avgRatio = (avgScore / 100.0).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String statusText;
    final Color statusColor;
    final IconData statusIcon;

    if (totalAttempts == 0) {
      statusText = 'New academic period — assessments in progress.';
      statusColor = AppTheme.textMuted;
      statusIcon = Icons.info_outline;
    } else if (passRate >= 80) {
      statusText = 'Exceptional institutional health! Target benchmark met.';
      statusColor = AppTheme.success;
      statusIcon = Icons.verified_user_rounded;
    } else if (passRate >= 70) {
      statusText = 'On track. Institutional metrics meeting expectations.';
      statusColor = AppTheme.primary;
      statusIcon = Icons.check_circle_outline_rounded;
    } else {
      statusText = 'Curriculum monitoring recommended on recent quiz results.';
      statusColor = AppTheme.warning;
      statusIcon = Icons.warning_amber_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Institutional Pass Rate Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Institutional Pass Rate',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (passRate >= 75 ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$passRate%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: passRate >= 75 ? AppTheme.success : AppTheme.warning,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(height: 8, width: double.infinity, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              FractionallySizedBox(
                widthFactor: passRatio > 0 ? passRatio : 0.001,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.success]),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. School-wide Average Score Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'School-wide Average Score',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$avgScore%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(height: 8, width: double.infinity, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              FractionallySizedBox(
                widthFactor: avgRatio > 0 ? avgRatio : 0.001,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.accent, AppTheme.primary]),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Status Banner & Quick Chips
        Row(
          children: [
            Icon(statusIcon, size: 15, color: statusColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: statusColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildAdminMiniChip('Learners: $totalStudents', AppTheme.primary),
            const SizedBox(width: 4),
            _buildAdminMiniChip('Faculty: $totalTeachers', const Color(0xFF0D9488)),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminMiniChip(String text, Color color) {
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

  Widget _buildStatCard(BuildContext context, String title, IconData icon, String count, {Color? color}) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: effectiveColor, size: 22),
          const SizedBox(height: 10),
          Text(count, style: TextStyle(color: AppTheme.text, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showPostAnnouncementSheet(BuildContext context, WidgetRef ref, {Map<String, dynamic>? initialAnnouncement}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PostAnnouncementSheet(
        initialAnnouncement: initialAnnouncement,
        onPost: (announcement) {
          if (initialAnnouncement != null) {
            ref.read(announcementsProvider.notifier).updateAnnouncement(initialAnnouncement['id'], announcement);
          } else {
            ref.read(announcementsProvider.notifier).addAnnouncement(announcement);
          }
        },
      ),
    );
  }
}

class _PostAnnouncementSheet extends StatefulWidget {
  final Map<String, dynamic>? initialAnnouncement;
  final void Function(Map<String, dynamic> announcement) onPost;

  const _PostAnnouncementSheet({this.initialAnnouncement, required this.onPost});

  @override
  State<_PostAnnouncementSheet> createState() => _PostAnnouncementSheetState();
}

class _PostAnnouncementSheetState extends State<_PostAnnouncementSheet> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _priority = 'Normal';
  String _targetAudience = 'All My Students';

  @override
  void initState() {
    super.initState();
    if (widget.initialAnnouncement != null) {
      _titleController.text = widget.initialAnnouncement!['title'];
      _messageController.text = widget.initialAnnouncement!['message'];
      _priority = widget.initialAnnouncement!['priority'];
      _targetAudience = widget.initialAnnouncement!['target_audience'];
    }
  }

  final List<String> _priorities = ['Normal', 'Important'];
  final List<Map<String, dynamic>> _audiences = [
    {'label': 'All My Students', 'icon': Icons.people_outline},
    {'label': 'By Grade Level', 'icon': Icons.public},
    {'label': 'By Section', 'icon': Icons.menu_book},
    {'label': 'Specific Students', 'icon': Icons.person_outline},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialAnnouncement != null ? 'Edit Announcement' : 'Post Announcement',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 24),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title Field
            TextField(
              controller: _titleController,
              maxLength: 80,
              style: TextStyle(color: AppTheme.text),
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: 12),

            // Message Field
            TextField(
              controller: _messageController,
              maxLength: 1000,
              style: TextStyle(color: AppTheme.text),
              decoration: const InputDecoration(hintText: 'Message...'),
              maxLines: 4,
            ),
            const SizedBox(height: 20),

            // Priority
            Text('Priority', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ..._priorities.map((p) => _buildSelectableOption(
              label: p,
              isSelected: _priority == p,
              onTap: () => setState(() => _priority = p),
            )),
            const SizedBox(height: 20),

            // Target Audience
            Text('Target Audience', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ..._audiences.map((a) => _buildSelectableOption(
              label: a['label'],
              icon: a['icon'],
              isSelected: _targetAudience == a['label'],
              onTap: () => setState(() => _targetAudience = a['label']),
            )),
            const SizedBox(height: 24),

            // Post Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_titleController.text.isNotEmpty && _messageController.text.isNotEmpty) {
                    widget.onPost({
                      'title': _titleController.text,
                      'message': _messageController.text,
                      'priority': _priority,
                      'target_audience': _targetAudience,
                      'created_at': DateTime.now().toIso8601String(),
                    });
                  }
                  Navigator.pop(context);
                },
                icon: Icon(widget.initialAnnouncement != null ? Icons.save : Icons.send, color: Colors.black, size: 18),
                label: Text(widget.initialAnnouncement != null ? 'Update Announcement' : 'Post Announcement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectableOption({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: isSelected ? Colors.black : AppTheme.textMuted),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

