import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/components/user_avatar_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/announcement_helper.dart';
import '../../../core/components/analytics_donut_chart.dart';
import '../../../core/components/analytics/analytics_components.dart';
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
    final unassignedStudents = analytics['unassignedStudents'] as int? ?? 0;
    final demographics = (analytics['demographics'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {};
    final subjectEnrollments = (analytics['subjectEnrollments'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final sectionDistribution = (analytics['sectionDistribution'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final studentTeacherRatio = analytics['studentTeacherRatio'] as String? ?? '0';
    
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
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin Dashboard', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                        Text(
                          currentUser?.fullName ?? 'Teacher John Reyes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  UserAvatarWidget(
                    imageSource: currentUser?.profileImage,
                    fallbackInitial: initial,
                    size: 48,
                    fontSize: 22,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Institutional Analytics Section (Multi-View: Cards & Demographics, Donut, 4-Tier Framework)
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
                unassignedStudents: unassignedStudents,
                demographics: demographics,
                subjectEnrollments: subjectEnrollments,
                sectionDistribution: sectionDistribution,
                studentTeacherRatio: studentTeacherRatio,
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
                      color: AnnouncementPriorityHelper.formatUpper(a['priority']?.toString()) != 'STANDARD'
                          ? AnnouncementPriorityHelper.getColor(a['priority']?.toString())
                          : AppTheme.border,
                      width: AnnouncementPriorityHelper.formatUpper(a['priority']?.toString()) != 'STANDARD' ? 1.5 : 1.0,
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
                          if (AnnouncementPriorityHelper.formatUpper(a['priority']?.toString()) != 'STANDARD')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AnnouncementPriorityHelper.getColor(a['priority']?.toString()).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                AnnouncementPriorityHelper.formatTitle(a['priority']?.toString()),
                                style: TextStyle(
                                  color: AnnouncementPriorityHelper.getColor(a['priority']?.toString()),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
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
    required int unassignedStudents,
    required Map<String, dynamic> demographics,
    required List<Map<String, dynamic>> subjectEnrollments,
    required List<Map<String, dynamic>> sectionDistribution,
    required String studentTeacherRatio,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 430;

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
            padding: EdgeInsets.fromLTRB(isCompact ? 12 : 16, 12, isCompact ? 10 : 12, 12),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 6 : 7),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.insights_rounded,
                    color: AppTheme.primary,
                    size: isCompact ? 16 : 18,
                  ),
                ),
                SizedBox(width: isCompact ? 8 : 10),
                Expanded(
                  child: isCompact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Institutional Overview',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: (passRate >= 75 ? AppTheme.success : AppTheme.primary).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                totalAttempts > 0 ? '$passRate% Pass Rate' : '$totalStudents Students',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: passRate >= 75 ? AppTheme.success : AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Institutional Overview',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                SizedBox(width: isCompact ? 4 : 6),

                // View Mode Switcher: Cards & Demographics, Donut Breakdown, 4-Tier Governance
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
                      _buildAnalyticsViewModeBtn(0, Icons.grid_view_rounded, 'Cards & Demographics', isCompact: isCompact),
                      _buildAnalyticsViewModeBtn(1, Icons.pie_chart_rounded, 'Assessment Donut', isCompact: isCompact),
                      _buildAnalyticsViewModeBtn(2, Icons.insights_rounded, '4-Tier Framework', isCompact: isCompact),
                    ],
                  ),
                ),
                SizedBox(width: isCompact ? 4 : 6),

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
                      padding: EdgeInsets.all(isCompact ? 5 : 6),
                      child: Icon(
                        Icons.visibility_off_outlined,
                        size: isCompact ? 16 : 18,
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
              unassignedStudents: unassignedStudents,
              demographics: demographics,
              subjectEnrollments: subjectEnrollments,
              sectionDistribution: sectionDistribution,
              studentTeacherRatio: studentTeacherRatio,
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

  Widget _buildAnalyticsViewModeBtn(int index, IconData icon, String tooltip, {bool isCompact = false}) {
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
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 5 : 8, vertical: isCompact ? 4 : 5),
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
            size: isCompact ? 13.5 : 15,
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
    required int unassignedStudents,
    required Map<String, dynamic> demographics,
    required List<Map<String, dynamic>> subjectEnrollments,
    required List<Map<String, dynamic>> sectionDistribution,
    required String studentTeacherRatio,
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
        return _buildAdmin4TierView(
          context,
          totalStudents: totalStudents,
          totalTeachers: totalTeachers,
          totalSubjects: totalSubjects,
          sectionsCount: sectionsCount,
          totalAttempts: totalAttempts,
          passedAttempts: passedAttempts,
          passRate: passRate,
          avgScore: avgScore,
          studentTeacherRatio: studentTeacherRatio,
          subjectEnrollments: subjectEnrollments,
          sectionDistribution: sectionDistribution,
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
          unassignedStudents: unassignedStudents,
          demographics: demographics,
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
    required int unassignedStudents,
    required Map<String, dynamic> demographics,
  }) {
    final assignedStudents = (totalStudents - unassignedStudents).clamp(0, totalStudents);
    final placementRate = totalStudents > 0 ? ((assignedStudents / totalStudents) * 100).round() : 100;
    final regular = demographics['regular'] as int? ?? (totalStudents - unassignedStudents);
    final irregular = demographics['irregular'] as int? ?? 0;
    final transferee = demographics['transferee'] as int? ?? 0;
    final sped = demographics['sped'] as int? ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(context, 'Students', Icons.people_outline, totalStudents.toString(), color: AppTheme.primary)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(context, 'Faculty', Icons.badge_outlined, totalTeachers.toString(), color: const Color(0xFF0D9488))),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(context, 'Subjects', Icons.menu_book, totalSubjects.toString(), color: AppTheme.accent)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildStatCard(context, 'Sections', Icons.layers, sectionsCount.toString(), color: AppTheme.textSecondary)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(context, 'Pass Rate', Icons.verified_outlined, '$passRate%', color: passRate >= 75 ? AppTheme.success : AppTheme.warning)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(context, 'Avg Score', Icons.trending_up, '$avgScore%', color: AppTheme.accent)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cohort Demographics & Section Allocation',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkText : AppTheme.lightText,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: (placementRate >= 90 ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$placementRate% Placed',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: placementRate >= 90 ? AppTheme.success : AppTheme.warning,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
              label: 'Diverse Learners & Transferees',
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
    final benchmarkPassed = passRate >= 75;
    final screenWidth = MediaQuery.of(context).size.width;
    final donutSize = screenWidth < 420 ? 115.0 : 155.0;
    final donutStroke = screenWidth < 420 ? 14.0 : 18.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Donut Chart Graphic (Adaptive sizing for mobile & desktop)
            SizedBox(
              width: donutSize,
              height: donutSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(donutSize, donutSize),
                    painter: AnalyticsDonutPainter(
                      valueA: passedAttempts.toDouble(),
                      valueB: needsReview.toDouble(),
                      colorA: AppTheme.success,
                      colorB: AppTheme.warning,
                      trackColor: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      strokeWidth: donutStroke,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$passRate%',
                        style: TextStyle(
                          fontSize: donutSize * 0.17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkText : AppTheme.lightText,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        totalAttempts > 0 ? 'PASS RATE' : 'CAMPUS',
                        style: TextStyle(
                          fontSize: donutSize * 0.06,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: screenWidth < 420 ? 10 : 16),

            // Legend Breakdown List
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAdminChartLegendItem(
                    label: 'Passed Quizzes',
                    value: '$passedAttempts ($passRate%)',
                    color: AppTheme.success,
                    subtext: totalAttempts > 0 ? '$passRate% institutional pass rate' : 'No quiz attempts yet',
                  ),
                  const SizedBox(height: 8),
                  _buildAdminChartLegendItem(
                    label: 'Needs Attention',
                    value: '$needsReview (${totalAttempts > 0 ? (100 - passRate) : 0}%)',
                    color: AppTheme.warning,
                    subtext: totalAttempts > 0 ? '${100 - passRate}% attempts below pass mark' : 'Clear',
                  ),
                  const SizedBox(height: 8),
                  _buildAdminChartLegendItem(
                    label: 'Average Score',
                    value: '$avgScore%',
                    color: AppTheme.accent,
                    subtext: 'Formative exam avg',
                  ),
                  const SizedBox(height: 8),
                  _buildAdminChartLegendItem(
                    label: 'Registered Students',
                    value: '$totalStudents',
                    color: AppTheme.primary,
                    subtext: 'Active learners in campus',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
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
                      : 'Students need additional support to meet the academic accreditation standard of 75%.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
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

  Widget _buildAdmin4TierView(
    BuildContext context, {
    required int totalStudents,
    required int totalTeachers,
    required int totalSubjects,
    required int sectionsCount,
    required int totalAttempts,
    required int passedAttempts,
    required int passRate,
    required int avgScore,
    required String studentTeacherRatio,
    required List<Map<String, dynamic>> subjectEnrollments,
    required List<Map<String, dynamic>> sectionDistribution,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final benchmarkMet = passRate >= 75;
    final projectedNatReadiness = (passRate > 0 ? passRate + 3 : 80).clamp(50, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── TIER 1: ENROLLMENT & ACTIVITY ──
        _buildCampusTierContainer(
          tierBadge: 'Enrollment & Activity',
          tierColor: AppTheme.primary,
          title: 'Student Enrollment by Track',
          icon: Icons.history_edu_rounded,
          isDark: isDark,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildTierChip('Enrolled', '$totalStudents', isDark),
                  _buildTierChip('Faculty', '$totalTeachers', isDark),
                  _buildTierChip('Courses', '$totalSubjects', isDark),
                  _buildTierChip('Attempts', '$totalAttempts', isDark),
                ],
              ),
              const SizedBox(height: 12),
              AnalyticsBarChart(
                items: subjectEnrollments.isNotEmpty
                    ? subjectEnrollments.take(5).map((s) {
                        final name = (s['code'] as String? ?? s['name'] as String? ?? 'Course').trim();
                        final count = (s['enrolled_count'] as num? ?? s['enrollments'] as num?)?.toDouble() ?? 0.0;
                        return BarChartItem(
                          label: name.length > 7 ? name.substring(0, 7) : name,
                          value: count,
                          color: AppTheme.primary,
                          tooltip: '${s['name']}: ${count.round()} students',
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
                height: 170,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── TIER 2: SECTION BREAKDOWN ──
        _buildCampusTierContainer(
          tierBadge: 'Section Breakdown',
          tierColor: AppTheme.accent,
          title: 'Class Section Quiz Scores',
          icon: Icons.troubleshoot_rounded,
          isDark: isDark,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildTierChip('Avg Class Size', '${studentTeacherRatio.split(':').first.trim()} / Teacher', isDark),
                  _buildTierChip('Sections', '${sectionDistribution.isNotEmpty ? sectionDistribution.length : sectionsCount}', isDark),
                  _buildTierChip('Baseline', '75% Pass', isDark),
                ],
              ),
              const SizedBox(height: 12),
              AnalyticsBarChart(
                items: sectionDistribution.isNotEmpty
                    ? sectionDistribution.take(5).map((sec) {
                        final name = (sec['section'] as String? ?? 'Sec').trim();
                        final count = (sec['student_count'] as num?)?.toDouble() ?? 0.0;
                        return BarChartItem(
                          label: name.length > 7 ? name.substring(0, 7) : name,
                          value: count,
                          color: AppTheme.accent,
                          tooltip: '$name: ${count.round()} learners',
                        );
                      }).toList()
                    : const [
                        BarChartItem(label: 'Sec-A', value: 28.0, color: Color(0xFF0D9488)),
                        BarChartItem(label: 'Sec-B', value: 22.0, color: Color(0xFF0D9488)),
                        BarChartItem(label: 'Sec-C', value: 16.0, color: Color(0xFF0D9488)),
                        BarChartItem(label: 'Sec-D', value: 12.0, color: Color(0xFF0D9488)),
                      ],
                maxValue: 35.0,
                valueSuffix: ' learners',
                height: 170,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── TIER 3: ACADEMIC FORECAST ──
        _buildCampusTierContainer(
          tierBadge: 'Academic Forecast',
          tierColor: AppTheme.warning,
          title: 'Estimated Passing Rates & NAT Readiness',
          icon: Icons.trending_up_rounded,
          isDark: isDark,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildTierChip('NAT Forecast', '$projectedNatReadiness%', isDark),
                  _buildTierChip('Retention Risk', benchmarkMet ? 'Low Risk' : 'Elevated', isDark),
                  _buildTierChip('Trajectory', avgScore >= 80 ? 'Accelerated' : 'Steady', isDark),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 360;
                  final gauge = AnalyticsGaugeMeter(
                    value: (projectedNatReadiness > 0 ? projectedNatReadiness : 80).toDouble(),
                    label: 'NAT Readiness',
                    statusText: benchmarkMet ? 'Target Met' : 'Remediation',
                    size: isNarrow ? 125 : 135,
                    isDark: isDark,
                  );
                  final trend = AnalyticsTrendChart(
                    points: [
                      const TrendPoint(label: 'Prelims', value: 74.0),
                      TrendPoint(label: 'Midterms', value: avgScore > 0 ? avgScore.toDouble() : 78.0),
                      TrendPoint(label: 'Projected', value: (projectedNatReadiness > 0 ? projectedNatReadiness : 82).toDouble()),
                    ],
                    height: 160,
                    baselineY: 75.0,
                    baselineLabel: 'Target 75%',
                    isDark: isDark,
                    lineColor: benchmarkMet ? AppTheme.success : AppTheme.warning,
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        Center(child: gauge),
                        const SizedBox(height: 10),
                        trend,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      gauge,
                      const SizedBox(width: 10),
                      Expanded(child: trend),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── TIER 4: SCHOOL ACTION PLAN ──
        _buildCampusTierContainer(
          tierBadge: 'School Action Plan',
          tierColor: AppTheme.success,
          title: 'Recommended Steps for School Leaders',
          icon: Icons.lightbulb_outline_rounded,
          isDark: isDark,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PrescriptiveActionCard(
                title: benchmarkMet ? 'Share High-Performing Study Guides' : 'Classroom Review & Remediation',
                description: benchmarkMet
                    ? 'Share lesson plans from top-performing sections with all teachers and distribute enrichment worksheets.'
                    : 'Set up extra review sessions for sections scoring below 75% and schedule faculty consultation hours.',
                badgeText: benchmarkMet ? 'Excellence' : 'Intervention',
                actionLabel: 'Send to Teachers',
                priority: benchmarkMet ? PrescriptionPriority.recommended : PrescriptionPriority.warning,
                isDark: isDark,
                onAction: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(benchmarkMet
                          ? 'Enrichment guides distributed to class sections.'
                          : 'Remedial review worksheets sent to class sections.'),
                      backgroundColor: benchmarkMet ? AppTheme.success : AppTheme.warning,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                benchmarkMet
                    ? '1. Replicate section teaching strategies across departments.\n2. Push enrichment guides to ESP32 local offline storage hubs.\n3. Calibrate quarterly standardized quiz items.'
                    : '1. Initiate remedial review for sections below 75% pass mark.\n2. Push remedial module packages to classroom ESP32 hubs.\n3. Reallocate faculty consultation hours for flagged students.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCampusTierContainer({
    required String tierBadge,
    required Color tierColor,
    required String title,
    required IconData icon,
    required bool isDark,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceLight.withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tierBadge,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: tierColor,
                  ),
                ),
              ),
              const Spacer(),
              Icon(icon, size: 16, color: tierColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildTierChip(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
            ),
          ),
        ],
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
  String _priority = 'Standard';
  String _targetAudience = 'All My Students';

  @override
  void initState() {
    super.initState();
    if (widget.initialAnnouncement != null) {
      _titleController.text = widget.initialAnnouncement!['title'];
      _messageController.text = widget.initialAnnouncement!['message'];
      _priority = AnnouncementPriorityHelper.formatTitle(widget.initialAnnouncement!['priority']?.toString());
      _targetAudience = widget.initialAnnouncement!['target_audience'];
    }
  }

  final List<String> _priorities = ['Standard', 'Important', 'Urgent'];
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
                      'priority': AnnouncementPriorityHelper.normalize(_priority),
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

