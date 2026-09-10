import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../data/teacher_repository.dart';
import 'components/create_quiz_dialog.dart';
import 'components/post_announcement_dialog.dart';

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends ConsumerState<TeacherDashboardScreen> {
  String _activeSectionFilter = 'All Handled Sections';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(teacherHandledSectionsDetailsProvider);
      ref.invalidate(teacherHandledSectionsProvider);
      ref.read(teacherDashboardProvider.notifier).reload();
    });
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(teacherDashboardProvider.notifier).reload(),
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
                    IconButton(
                      icon: Icon(Icons.refresh, color: AppTheme.primary),
                      tooltip: 'Refresh Dashboard',
                      onPressed: () {
                        ref.read(teacherDashboardProvider.notifier).reload();
                        ref.read(teacherSubjectsProvider.notifier).reload();
                        ref.read(teacherAnnouncementsProvider.notifier).reload(sectionFilter: _activeSectionFilter);
                        ref.invalidate(teacherHandledSectionsProvider);
                        ref.invalidate(teacherHandledSectionsDetailsProvider);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // KPI Metric Cards Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Assigned Subjects',
                                value: '$totalSubjects',
                                subtitle: 'Active courses',
                                icon: Icons.menu_book_outlined,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Enrolled Students',
                                value: '$totalStudents',
                                subtitle: 'Across your classes',
                                icon: Icons.people_alt_outlined,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Class Pass Rate',
                                value: '$passRate%',
                                subtitle: '$passedAttempts passed ($totalAttempts attempts)',
                                icon: Icons.verified_outlined,
                                color: passRate >= 75 ? AppTheme.success : AppTheme.warning,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Average Score',
                                value: '$avgScore%',
                                subtitle: 'Overall assessments',
                                icon: Icons.trending_up,
                                color: AppTheme.accent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Quick Action Buttons
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.menu_book,
                        label: 'Curriculum & Quizzes',
                        color: AppTheme.primary,
                        onTap: () => context.go('/teacher/subjects'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.add_circle_outline,
                        label: 'Create Quiz',
                        color: const Color(0xFF0D9488),
                        onTap: () => _showCreateQuizDialog(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.assignment_turned_in,
                        label: 'Live Scores',
                        color: AppTheme.accent,
                        onTap: () => context.go('/teacher/scores'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.people_alt,
                        label: 'Student Roster',
                        color: AppTheme.primary.withValues(alpha: 0.7),
                        onTap: () => context.go('/teacher/students'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.campaign_rounded,
                        label: 'Announce',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => PostAnnouncementDialog.show(
                          context,
                          defaultSection: _activeSectionFilter,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Handled Class Sections Block
                _buildHandledSectionsSection(context, handledSectionsDetailsAsync),
                const SizedBox(height: 28),

                // Announcements & Broadcasts Section
                _buildAnnouncementsSection(currentUser, announcements, handledSections),
                const SizedBox(height: 28),

                // Recent Student Submissions Section
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
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.quiz_outlined, size: 40, color: AppTheme.textMuted),
                          const SizedBox(height: 8),
                          Text(
                            'No quiz submissions yet',
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'When enrolled students complete quizzes in your subjects, their live results will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
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

                const SizedBox(height: 24),

                // Assigned Subjects Section
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
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

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.text,
              ),
            ),
          ],
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
    showDialog(
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Announcement deleted.')),
                );
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
                              Icon(Icons.people_alt_outlined, size: 14, color: const Color(0xFF0D9488)),
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

  void _showCreateQuizDialog(BuildContext context) {
    final subjects = ref.watch(teacherSubjectsProvider);
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subjects assigned. Please contact your admin to assign subjects first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => CreateQuizDialog(
          initialSubjectId: subjects.first['id'] as int?,
          subjectName: subjects.first['name']?.toString() ?? 'Subject',
        ),
      ),
    );
  }
}

