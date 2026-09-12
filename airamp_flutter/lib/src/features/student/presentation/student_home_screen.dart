import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../admin/data/admin_repository.dart';
import '../data/student_repository.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(studentCoursesProvider.notifier).reload(),
              ref.read(studentProgressProvider.notifier).loadProgress(),
              ref.read(studentQuizAssignmentsProvider.notifier).reload(),
            ]);
            ref.invalidate(announcementsProvider);
          },
          color: AppTheme.primary,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            physics: const AlwaysScrollableScrollPhysics(),
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
                        _buildBellButton(studentAnnouncements),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            context.go('/student/profile');
                          },
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: AppTheme.primary,
                            child: Text(
                              currentUser.fullName.isNotEmpty ? currentUser.fullName[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick Stats
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Active Courses', Icons.book, activeCourses.toString(), AppTheme.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Lessons Done', Icons.check_circle, lessonsDone.toString(), AppTheme.success)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Pending', Icons.schedule, pending.toString(), AppTheme.warning)),
                  ],
                ),
                const SizedBox(height: 32),

                // Assigned Quizzes & Tasks
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
                  // Scaffold layout for 3+ quizzes: ListView with separators
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
                  // Column layout for 1-2 quizzes
                  ...pendingQuizzes.map((q) => _buildQuizCard(q)),

                const SizedBox(height: 32),

                // Active Announcements
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
                
                const SizedBox(height: 32),

                // Continue Learning
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
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Due $dueDate',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.error),
                  ),
                ),
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
              onPressed: () {
                if (quizId != null) {
                  context.push('/quiz/$quizId');
                }
              },
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Start Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

