import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../data/teacher_repository.dart';
import 'components/post_announcement_dialog.dart';
import 'components/assignment_roster_dialog.dart';
import 'components/class_overview_widget.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/components/app_toast.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/components/skeleton_loader.dart';
import '../../../core/animations/app_transitions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/components/analytics_donut_chart.dart';
import '../../submissions/data/submissions_repository.dart';

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends ConsumerState<TeacherDashboardScreen> {
  String _activeSectionFilter = 'All Handled Sections';
  bool _isAnalyticsExpanded = false; // Analytics collapsed by default or loaded from preferences
  int _analyticsViewIndex = 0; // 0: Cards View, 1: Donut Breakdown, 2: Performance Mastery
  String _analyticsSectionFilter = 'All Handled Sections';
  String _analyticsStudentFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadAnalyticsPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(teacherHandledSectionsDetailsProvider);
      ref.invalidate(teacherHandledSectionsProvider);
      ref.read(teacherDashboardProvider.notifier).reload(
        section: _analyticsSectionFilter,
        studentId: _analyticsStudentFilter,
      );
    });
  }

  Future<void> _loadAnalyticsPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isAnalyticsExpanded = prefs.getBool('teacher_analytics_expanded') ?? false;
          _analyticsViewIndex = prefs.getInt('teacher_analytics_view_index') ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAnalyticsPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('teacher_analytics_expanded', _isAnalyticsExpanded);
      await prefs.setInt('teacher_analytics_view_index', _analyticsViewIndex);
    } catch (_) {}
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(isoString);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    } catch (_) {
      return 'Recent';
    }
  }

  void _showNotificationsDialog(BuildContext context, String teacherId) {
    AppModalTransitions.showSmoothDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final notifsAsync = ref.watch(userNotificationsProvider(teacherId));
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.notifications_outlined, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Activity Notifications',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await DatabaseHelper().markAllNotificationsRead(teacherId);
                      ref.invalidate(userNotificationsProvider(teacherId));
                      ref.invalidate(unreadNotificationsCountProvider(teacherId));
                    },
                    child: const Text('Mark All Read', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 480,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                child: SizedBox(
                  width: double.maxFinite,
                  child: notifsAsync.when(
                  loading: () => const AppShimmer(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SkeletonListTile(leadingSize: 36, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6)),
                          SkeletonListTile(leadingSize: 36, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6)),
                          SkeletonListTile(leadingSize: 36, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6)),
                        ],
                      ),
                    ),
                  ),
                  error: (err, _) => AppErrorState(
                    compact: true,
                    error: err,
                    onRetry: () => ref.refresh(userNotificationsProvider(teacherId)),
                  ),
                  data: (notifs) {
                    if (notifs.isEmpty) {
                      return const AppEmptyState(
                        compact: true,
                        icon: Icons.notifications_none_outlined,
                        title: 'All Caught Up!',
                        message: 'No new activity notifications right now. New student submissions will appear here.',
                      );
                    }
                    return ListView.separated(
                      itemCount: notifs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final n = notifs[index];
                        final id = n['id'].toString();
                        final title = n['title'] as String? ?? 'Notification';
                        final message = n['message'] as String? ?? '';
                        final isRead = (n['is_read'] as int? ?? 0) == 1;
                        final relatedId = n['related_id'] as String?;
                        final assignmentId = relatedId != null ? int.tryParse(relatedId) : null;

                        return InkWell(
                          onTap: () async {
                            await DatabaseHelper().markNotificationRead(id);
                            ref.invalidate(userNotificationsProvider(teacherId));
                            ref.invalidate(unreadNotificationsCountProvider(teacherId));

                            if (assignmentId != null && ctx.mounted) {
                              Navigator.pop(ctx);
                              final assignment = await DatabaseHelper().getAssignmentById(assignmentId);
                              if (context.mounted && assignment != null) {
                                AppModalTransitions.showSmoothDialog(
                                  context: context,
                                  builder: (c) => AssignmentRosterDialog(
                                    assignmentId: assignmentId,
                                    assignmentTitle: assignment['title'] as String? ?? 'Activity',
                                    totalPoints: (assignment['total_points'] as num?)?.toInt() ?? 100,
                                    dueDate: assignment['due_date'] as String?,
                                  ),
                                );
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isRead ? AppTheme.background : AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isRead ? AppTheme.border : AppTheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.assignment_turned_in_outlined,
                                  size: 20,
                                  color: isRead ? AppTheme.textMuted : AppTheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.text,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        message,
                                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 4, left: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Close', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final currentUser = ref.watch(authProvider);
    final stats = ref.watch(teacherDashboardProvider);
    final subjects = ref.watch(teacherSubjectsProvider);
    final announcements = ref.watch(teacherAnnouncementsProvider);
    final handledSectionsAsync = ref.watch(teacherHandledSectionsProvider);
    final handledSections = handledSectionsAsync.value ?? [];
    final handledSectionsDetailsAsync = ref.watch(teacherHandledSectionsDetailsProvider);
    final allStudents = ref.watch(teacherStudentsProvider);

    final totalSubjects = stats['totalSubjects'] as int? ?? 0;
    final totalStudents = stats['totalStudents'] as int? ?? 0;
    final totalAttempts = stats['totalAttempts'] as int? ?? 0;
    final passedAttempts = stats['passedAttempts'] as int? ?? 0;
    final passRate = stats['passRate'] as int? ?? 0;
    final avgScore = stats['avgScore'] as int? ?? 0;
    final recentAttempts = (stats['recentAttempts'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    final teacherName = currentUser?.fullName ?? 'Faculty Instructor';
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1050;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(teacherDashboardProvider.notifier).reload(
                section: _analyticsSectionFilter,
                studentId: _analyticsStudentFilter,
              ),
              ref.read(teacherSubjectsProvider.notifier).reload(),
              ref.read(teacherAnnouncementsProvider.notifier).reload(sectionFilter: _activeSectionFilter),
              ref.refresh(teacherHandledSectionsProvider.future),
              ref.refresh(teacherHandledSectionsDetailsProvider.future),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Profile & Greeting
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'FACULTY PORTAL',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.border.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'DepEd Senior High',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            teacherName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Curriculum delivery, quiz authoring & live score evaluation',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final unreadCount = ref.watch(unreadNotificationsCountProvider(currentUser?.id ?? '')).value ?? 0;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: Icon(Icons.notifications_outlined, color: AppTheme.text),
                              tooltip: 'Activity Notifications',
                              onPressed: () => _showNotificationsDialog(context, currentUser?.id ?? ''),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text(
                                    unreadCount > 9 ? '9+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildProfileAvatarButton(context, currentUser, teacherName),
                  ],
                ),
                const SizedBox(height: 20),

                // Collapsible & Filterable Performance Analytics Section
                _buildAnalyticsSection(
                  isDesktop: isDesktop,
                  totalSubjects: totalSubjects,
                  totalStudents: totalStudents,
                  totalAttempts: totalAttempts,
                  passedAttempts: passedAttempts,
                  passRate: passRate,
                  avgScore: avgScore,
                  handledSections: handledSections,
                  allStudents: allStudents,
                ),
                const SizedBox(height: 20),

                // Today's Class Schedule Banner
                const TodayScheduleBanner(),
                const SizedBox(height: 24),

                // Responsive Area: 2 Columns on Desktop, 1 Column on Mobile
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Class Overview & Submissions & Subjects
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ClassOverviewWidget(),
                            const SizedBox(height: 28),
                            _buildSubmissionsSection(context, recentAttempts),
                            const SizedBox(height: 28),
                            _buildAssignedSubjectsSection(context, subjects),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column: Handled Sections & Announcements
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHandledSectionsSection(context, handledSectionsDetailsAsync),
                            const SizedBox(height: 28),
                            _buildAnnouncementsSection(currentUser, announcements, handledSections),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ClassOverviewWidget(),
                      const SizedBox(height: 28),
                      _buildHandledSectionsSection(context, handledSectionsDetailsAsync),
                      const SizedBox(height: 28),
                      _buildAnnouncementsSection(currentUser, announcements, handledSections),
                      const SizedBox(height: 28),
                      _buildSubmissionsSection(context, recentAttempts),
                      const SizedBox(height: 28),
                      _buildAssignedSubjectsSection(context, subjects),
                    ],
                  ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);
}

  Widget _buildSubmissionsSection(BuildContext context, List<Map<String, dynamic>> recentAttempts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Live Student Quiz Submissions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/teacher/scores'),
              child: Text('View All', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recentAttempts.isEmpty)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: AppEmptyState(
              compact: true,
              icon: Icons.quiz_outlined,
              title: 'No Quiz Submissions Yet',
              message: 'When enrolled students complete quizzes in your subjects, their live results will appear here.',
              actionLabel: 'View Quiz Scores',
              actionIcon: Icons.insights_rounded,
              onAction: () => context.go('/teacher/scores'),
            ),
          )
        else
          ...recentAttempts.take(5).map((attempt) {
            final isPassed = attempt['is_passed'] == 1 || attempt['is_passed'] == true;
            final studentName = attempt['student_name']?.toString() ?? 'Student';
            final subjectName = attempt['subject_name']?.toString() ?? 'Subject';
            final score = attempt['score'] ?? 0;
            final total = attempt['total_questions'] ?? 0;
            final pct = (attempt['percentage'] as num?)?.round() ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isPassed
                        ? AppTheme.success.withValues(alpha: 0.15)
                        : AppTheme.error.withValues(alpha: 0.15),
                    child: Icon(
                      isPassed ? Icons.check_circle : Icons.cancel,
                      color: isPassed ? AppTheme.success : AppTheme.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subjectName,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$score / $total ($pct%)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isPassed ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPassed
                              ? AppTheme.success.withValues(alpha: 0.1)
                              : AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPassed ? 'PASSED' : 'FAILED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isPassed ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAssignedSubjectsSection(BuildContext context, List<Map<String, dynamic>> subjects) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Assigned Subjects',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/teacher/subjects'),
              child: Text('Manage', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (subjects.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: Text(
                'No subjects currently assigned. School Administrators assign subjects in the Admin Portal.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          ...subjects.map((sub) {
            final subId = sub['id'] as int;
            final name = sub['name']?.toString() ?? 'Subject';
            final code = sub['subject_code']?.toString() ?? '';
            final unlockType = sub['unlock_type']?.toString() ?? 'Sequential';
            final semester = sub['semester']?.toString() ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.menu_book, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (code.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.border.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  code,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.text),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              unlockType,
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            if (semester.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '· $semester',
                                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.primary),
                    tooltip: 'Open Curriculum & Quizzes',
                    onPressed: () => context.push('/teacher/subjects/$subId'),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAnalyticsSection({
    required bool isDesktop,
    required int totalSubjects,
    required int totalStudents,
    required int totalAttempts,
    required int passedAttempts,
    required int passRate,
    required int avgScore,
    required List<String> handledSections,
    required List<Map<String, dynamic>> allStudents,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Determine effective section and students available for filter
    final sectionOptions = <String>[
      'All Handled Sections',
      ...handledSections.where((s) => s.isNotEmpty && s != 'All Handled Sections'),
    ];
    final effectiveSection = sectionOptions.contains(_analyticsSectionFilter)
        ? _analyticsSectionFilter
        : 'All Handled Sections';

    final availableStudents = effectiveSection == 'All Handled Sections'
        ? allStudents
        : allStudents.where((s) {
            final sec = (s['section'] as String?)?.toLowerCase().trim() ?? '';
            return sec == effectiveSection.toLowerCase().trim();
          }).toList();

    final effectiveStudentId = availableStudents.any((s) => s['id'] == _analyticsStudentFilter)
        ? _analyticsStudentFilter
        : 'All';

    final hasActiveFilter = effectiveSection != 'All Handled Sections' || effectiveStudentId != 'All';

    String selectedStudentName = 'Student';
    if (effectiveStudentId != 'All') {
      final match = availableStudents.firstWhere(
        (s) => s['id'] == effectiveStudentId,
        orElse: () => <String, dynamic>{},
      );
      selectedStudentName = match['full_name'] as String? ?? 'Student';
    }

    final collapsedView = Container(
      key: const ValueKey('analytics_collapsed'),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _isAnalyticsExpanded = true);
          _saveAnalyticsPreferences();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.analytics_outlined, size: 20, color: AppTheme.primary),
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
                            'Performance & Analytics',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (passRate >= 75 ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$passRate% Pass Rate',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: passRate >= 75 ? AppTheme.success : AppTheme.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasActiveFilter
                          ? 'Filtered: ${effectiveStudentId != 'All' ? selectedStudentName : effectiveSection} • Tap to view'
                          : '$totalSubjects Subjects • $totalStudents Students • $passRate% Pass Rate • $avgScore% Avg',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Show',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!_isAnalyticsExpanded) {
      return AnimatedSize(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.topCenter,
                child: child,
              ),
            );
          },
          child: collapsedView,
        ),
      );
    }

    // Expanded View: Filter controls + 4 Metric Cards
    final expandedView = Container(
      key: const ValueKey('analytics_expanded'),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title, Subtitle, View Mode Switcher, and Hide Toggle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.analytics_outlined, size: 20, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Performance & Analytics',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (totalAttempts > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (passRate >= 75 ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$passRate% Pass Rate',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: passRate >= 75 ? AppTheme.success : AppTheme.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time metrics filtered by section or student',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // View Mode Switcher: Cards, Donut, Gauge
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
                    _buildAnalyticsViewModeBtn(2, Icons.trending_up_rounded, 'Performance Mastery'),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              Tooltip(
                message: 'Hide Analytics',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isAnalyticsExpanded = false);
                    _saveAnalyticsPreferences();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.keyboard_arrow_up, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Hide',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filters: Section Dropdown & Student Dropdown
          Row(
            children: [
              // Section Filter Dropdown
              Expanded(
                flex: 5,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: effectiveSection,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 3,
                      icon: Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.textSecondary),
                      style: TextStyle(fontSize: 12, color: AppTheme.text, fontWeight: FontWeight.w500),
                      dropdownColor: AppTheme.surface,
                      items: sectionOptions.map((sec) {
                        return DropdownMenuItem(
                          value: sec,
                          child: Text(
                            sec == 'All Handled Sections' ? 'All Sections' : sec,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _analyticsSectionFilter = val;
                            // Reset student filter if not available in selected section
                            if (val != 'All Handled Sections' && _analyticsStudentFilter != 'All') {
                              final inSec = allStudents.any((s) =>
                                  s['id'] == _analyticsStudentFilter &&
                                  (s['section'] as String?)?.toLowerCase().trim() == val.toLowerCase().trim());
                              if (!inSec) _analyticsStudentFilter = 'All';
                            }
                          });
                          ref.read(teacherDashboardProvider.notifier).reload(
                            section: _analyticsSectionFilter,
                            studentId: _analyticsStudentFilter,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Student Filter Dropdown
              Expanded(
                flex: 5,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: effectiveStudentId,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 3,
                      icon: Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.textSecondary),
                      style: TextStyle(fontSize: 12, color: AppTheme.text, fontWeight: FontWeight.w500),
                      dropdownColor: AppTheme.surface,
                      items: [
                        const DropdownMenuItem(
                          value: 'All',
                          child: Text('All Students', overflow: TextOverflow.ellipsis),
                        ),
                        ...availableStudents.map((st) {
                          final name = st['full_name'] as String? ?? 'Student';
                          final sec = st['section'] as String? ?? '';
                          final label = effectiveSection == 'All Handled Sections' && sec.isNotEmpty
                              ? '$name ($sec)'
                              : name;
                          return DropdownMenuItem(
                            value: st['id'] as String,
                            child: Text(label, overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _analyticsStudentFilter = val);
                          ref.read(teacherDashboardProvider.notifier).reload(
                            section: _analyticsSectionFilter,
                            studentId: _analyticsStudentFilter,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),

              // Reset Filter Button if active
              if (hasActiveFilter) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Reset Analytics Filter',
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.background,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    setState(() {
                      _analyticsSectionFilter = 'All Handled Sections';
                      _analyticsStudentFilter = 'All';
                    });
                    ref.read(teacherDashboardProvider.notifier).reload(
                      section: 'All Handled Sections',
                      studentId: 'All',
                    );
                  },
                ),
              ],
            ],
          ),

          // Active filter indicator badge
          if (hasActiveFilter)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.filter_alt_outlined, size: 13, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Showing stats for: ',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  Text(
                    effectiveStudentId != 'All'
                        ? selectedStudentName
                        : effectiveSection,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          // View Content based on _analyticsViewIndex (0: Cards, 1: Donut Breakdown, 2: Performance Mastery)
          if (_analyticsViewIndex == 1)
            _buildTeacherDonutView(
              totalSubjects: totalSubjects,
              totalStudents: totalStudents,
              totalAttempts: totalAttempts,
              passedAttempts: passedAttempts,
              passRate: passRate,
              avgScore: avgScore,
            )
          else if (_analyticsViewIndex == 2)
            _buildTeacherGaugeView(
              totalSubjects: totalSubjects,
              totalStudents: totalStudents,
              totalAttempts: totalAttempts,
              passedAttempts: passedAttempts,
              passRate: passRate,
              avgScore: avgScore,
            )
          else
            _buildTeacherCardsView(
              isDesktop: isDesktop,
              totalSubjects: totalSubjects,
              totalStudents: totalStudents,
              totalAttempts: totalAttempts,
              passedAttempts: passedAttempts,
              passRate: passRate,
              avgScore: avgScore,
              effectiveStudentId: effectiveStudentId,
              selectedStudentName: selectedStudentName,
              effectiveSection: effectiveSection,
            ),
        ],
      ),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topCenter,
              child: child,
            ),
          );
        },
        child: expandedView,
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
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

  Widget _buildTeacherCardsView({
    required bool isDesktop,
    required int totalSubjects,
    required int totalStudents,
    required int totalAttempts,
    required int passedAttempts,
    required int passRate,
    required int avgScore,
    required String effectiveStudentId,
    required String selectedStudentName,
    required String effectiveSection,
  }) {
    if (isDesktop) {
      return Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              title: 'Assigned Subjects',
              value: '$totalSubjects',
              subtitle: effectiveStudentId != 'All' ? 'Enrolled subjects' : 'Active courses',
              icon: Icons.menu_book_outlined,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              title: effectiveStudentId != 'All' ? 'Target Student' : 'Enrolled Students',
              value: '$totalStudents',
              subtitle: effectiveStudentId != 'All'
                  ? selectedStudentName
                  : effectiveSection != 'All Handled Sections'
                      ? 'In $effectiveSection'
                      : 'Across your classes',
              icon: Icons.people_alt_outlined,
              color: AppTheme.info,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              title: effectiveStudentId != 'All' ? 'Student Pass Rate' : 'Class Pass Rate',
              value: '$passRate%',
              subtitle: totalAttempts == 0 ? 'No attempts yet' : '$passedAttempts passed ($totalAttempts attempts)',
              icon: Icons.verified_outlined,
              color: passRate >= 75 ? AppTheme.success : AppTheme.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              title: effectiveStudentId != 'All' ? 'Student Avg Score' : 'Average Score',
              value: '$avgScore%',
              subtitle: totalAttempts == 0 ? 'No attempts yet' : 'Overall assessments',
              icon: Icons.trending_up,
              color: AppTheme.accent,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Assigned Subjects',
                value: '$totalSubjects',
                subtitle: effectiveStudentId != 'All' ? 'Enrolled subjects' : 'Active courses',
                icon: Icons.menu_book_outlined,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: effectiveStudentId != 'All' ? 'Target Student' : 'Enrolled Students',
                value: '$totalStudents',
                subtitle: effectiveStudentId != 'All'
                    ? selectedStudentName
                    : effectiveSection != 'All Handled Sections'
                        ? 'In $effectiveSection'
                        : 'Across your classes',
                icon: Icons.people_alt_outlined,
                color: AppTheme.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: effectiveStudentId != 'All' ? 'Student Pass Rate' : 'Class Pass Rate',
                value: '$passRate%',
                subtitle: totalAttempts == 0 ? 'No attempts yet' : '$passedAttempts passed ($totalAttempts attempts)',
                icon: Icons.verified_outlined,
                color: passRate >= 75 ? AppTheme.success : AppTheme.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: effectiveStudentId != 'All' ? 'Student Avg Score' : 'Average Score',
                value: '$avgScore%',
                subtitle: totalAttempts == 0 ? 'No attempts yet' : 'Overall assessments',
                icon: Icons.trending_up,
                color: AppTheme.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeacherDonutView({
    required int totalSubjects,
    required int totalStudents,
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
                    totalAttempts > 0 ? 'PASS RATE' : 'NO DATA',
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
              _buildTeacherChartLegendItem(
                label: 'Passed Assessments',
                value: '$passedAttempts',
                color: AppTheme.success,
                subtext: totalAttempts > 0 ? '$passRate% passing rate' : 'No attempts',
              ),
              const SizedBox(height: 8),
              _buildTeacherChartLegendItem(
                label: 'Needs Review',
                value: '$needsReview',
                color: AppTheme.warning,
                subtext: totalAttempts > 0 ? '${100 - passRate}% attention required' : 'Clear',
              ),
              const SizedBox(height: 8),
              _buildTeacherChartLegendItem(
                label: 'Enrolled Students',
                value: '$totalStudents',
                color: AppTheme.primary,
                subtext: 'Active in class scope',
              ),
              const SizedBox(height: 8),
              _buildTeacherChartLegendItem(
                label: 'Class Avg Score',
                value: '$avgScore%',
                color: AppTheme.accent,
                subtext: 'Overall assessment mastery',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherChartLegendItem({
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

  Widget _buildTeacherGaugeView({
    required int totalSubjects,
    required int totalStudents,
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
      statusText = 'No assessments completed yet for this selection.';
      statusColor = AppTheme.textMuted;
      statusIcon = Icons.info_outline;
    } else if (passRate >= 85) {
      statusText = 'Exceptional class performance! Benchmark exceeded.';
      statusColor = AppTheme.success;
      statusIcon = Icons.stars_rounded;
    } else if (passRate >= 75) {
      statusText = 'On track! Class meets standard 75% pass benchmark.';
      statusColor = AppTheme.primary;
      statusIcon = Icons.verified_rounded;
    } else {
      statusText = 'Class pass rate is below target (75%). Review suggested.';
      statusColor = AppTheme.warning;
      statusIcon = Icons.warning_amber_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Pass Rate Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Class Pass Rate Benchmark',
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

        // 2. Average Score Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Average Score Mastery',
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
            _buildTeacherMiniChip('Attempts: $totalAttempts', AppTheme.primary),
            const SizedBox(width: 4),
            _buildTeacherMiniChip('Students: $totalStudents', AppTheme.accent),
          ],
        ),
      ],
    );
  }

  Widget _buildTeacherMiniChip(String text, Color color) {
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

  Widget _buildAnnouncementsSection(
    User? currentUser,
    List<Map<String, dynamic>> announcements,
    List<String> handledSections,
  ) {
    final sectionOptions = <String>{
      'All Handled Sections',
      ...handledSections.where((s) => s.isNotEmpty && s != 'All Handled Sections'),
    }.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Announcements',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => PostAnnouncementDialog.show(
                context,
                defaultSection: _activeSectionFilter,
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Post Announcement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                minimumSize: const Size(0, 34),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Section Filter Chips Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: sectionOptions.map((sec) {
              final isSelected = _activeSectionFilter == sec;
              final isAll = sec == 'All Handled Sections';
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAll ? Icons.domain : Icons.class_outlined,
                        size: 13,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        sec,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _activeSectionFilter = sec);
                      ref.read(teacherAnnouncementsProvider.notifier).reload(sectionFilter: sec);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Announcements Cards or Empty State
        if (announcements.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                Icon(Icons.campaign_outlined, size: 36, color: AppTheme.textMuted),
                const SizedBox(height: 8),
                Text(
                  'No announcements for $_activeSectionFilter',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Broadcast class updates, assignments, or reminders to students.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => PostAnnouncementDialog.show(
                    context,
                    defaultSection: _activeSectionFilter,
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Post First Announcement'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )
        else
          ...announcements.take(5).map((a) {
            final id = a['id'] as int? ?? 0;
            final title = a['title']?.toString() ?? '';
            final message = a['message']?.toString() ?? '';
            final priority = (a['priority']?.toString() ?? 'normal').toLowerCase();
            final section = a['section']?.toString() ?? 'All Handled Sections';
            final authorId = a['author_id']?.toString() ?? '';
            final authorName = a['author_name']?.toString() ?? 'Faculty';
            final date = _formatDate(a['created_at']?.toString());
            final isAuthor = currentUser != null && (authorId == currentUser.id || authorId.isEmpty);

            final isHigh = priority == 'high';
            final isMedium = priority == 'medium';
            final priorityColor = isHigh
                ? AppTheme.error
                : (isMedium ? AppTheme.warning : AppTheme.primary);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Badges and Author actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Priority Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              priority.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: priorityColor,
                              ),
                            ),
                          ),
                          // Section Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.groups, size: 10, color: AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  section.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isAuthor)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => PostAnnouncementDialog.show(context, existing: a),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.edit_outlined, size: 16, color: AppTheme.primary),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _showDeleteAnnouncementConfirm(id, title),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Message
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Footer: Author & Date
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 12, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        isAuthor ? '$authorName (You)' : authorName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 12, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _showDeleteAnnouncementConfirm(int id, String title) {
    AppModalTransitions.showSmoothDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.error, size: 22),
            const SizedBox(width: 8),
            Text('Delete Announcement?', style: TextStyle(color: AppTheme.text, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$title"? This cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(teacherAnnouncementsProvider.notifier).deleteAnnouncement(id);
              if (mounted) {
                AppToast.showSuccess(context, 'Announcement deleted.');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildHandledSectionsSection(
    BuildContext context,
    AsyncValue<List<Map<String, dynamic>>> sectionsAsync,
  ) {
    final sections = sectionsAsync.value ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.layers, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Your Handled Sections',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => context.go('/teacher/students'),
              child: Text('View Roster', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (sectionsAsync.isLoading && sections.isEmpty)
          Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (sections.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.layers_clear_outlined, size: 36, color: AppTheme.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    'No handled class sections yet',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sections are linked when students in your assigned subjects enroll.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 136,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final sec = sections[index];
                final name = sec['name'] as String? ?? 'Section';
                final grade = sec['grade'] as String? ?? 'Senior High';
                final studentCount = sec['student_count'] as int? ?? 0;
                final room = sec['room'] as String? ?? '';
                final subjectsList = (sec['subjects'] as List<dynamic>?)?.cast<String>() ?? [];

                return Container(
                  width: 205,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      context.go('/teacher/students?section=${Uri.encodeComponent(name)}');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  grade,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textMuted),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                room.isNotEmpty
                                    ? room
                                    : (subjectsList.isNotEmpty ? subjectsList.first : 'Handled Section'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.people_alt_outlined, size: 14, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                '$studentCount ${studentCount == 1 ? 'Student' : 'Students'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.text,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'View Roster',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProfileAvatarButton(
    BuildContext context,
    dynamic currentUser,
    String teacherName,
  ) {
    return _TeacherHeaderAvatarButton(
      currentUser: currentUser,
      teacherName: teacherName,
      onTap: () => context.push('/teacher/profile'),
    );
  }
}

/// A modern, tactile, interactive faculty profile avatar button for the teacher dashboard header.
///
/// Features:
/// - Outer interactive accent ring line with subtle depth and glow.
/// - Clean separation gap to prevent obstructing the user's avatar/initial.
/// - Side clickable indicator badge (subtle chevron indicator) signaling interaction without blocking the center.
/// - Haptic press and hover scaling feedback.
class _TeacherHeaderAvatarButton extends StatefulWidget {
  final dynamic currentUser;
  final String teacherName;
  final VoidCallback onTap;

  const _TeacherHeaderAvatarButton({
    required this.currentUser,
    required this.teacherName,
    required this.onTap,
  });

  @override
  State<_TeacherHeaderAvatarButton> createState() =>
      _TeacherHeaderAvatarButtonState();
}

class _TeacherHeaderAvatarButtonState
    extends State<_TeacherHeaderAvatarButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.currentUser?.profileImage != null &&
        (widget.currentUser!.profileImage as String).isNotEmpty;
    final initial = widget.teacherName.isNotEmpty
        ? widget.teacherName[0].toUpperCase()
        : 'T';

    return Tooltip(
      message: 'Faculty Profile & Settings',
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
                              widget.currentUser!.profileImage!,
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

