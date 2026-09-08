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
                                  const Spacer(),
                                  Text(
                                    a['created_at'] != null ? a['created_at'].toString().split('T').first : '',
                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                  ),
                                ],
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

    // Filter announcements for students
    final studentAnnouncements = allAnnouncements.where((a) {
      final aud = (a['target_audience'] as String? ?? 'all').toLowerCase();
      return aud == 'all' || aud == 'students';
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
            await ref.read(studentCoursesProvider.notifier).reload();
            await ref.read(studentProgressProvider.notifier).loadProgress();
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
                    studentAnnouncements.first['title']?.toString() ?? '',
                    studentAnnouncements.first['message']?.toString() ?? '',
                    studentAnnouncements.first['priority']?.toString() ?? 'medium',
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

  Widget _buildAnnouncementCard(String title, String body, String priority) {
    final isHigh = priority.toLowerCase() == 'high';
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
}

