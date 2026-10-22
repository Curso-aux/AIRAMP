import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/philippine_time_helper.dart';
import '../../auth/application/auth_provider.dart';
import '../../admin/data/admin_repository.dart';
import '../../teacher/data/teacher_schedule_repository.dart';
import '../data/student_repository.dart';
import 'components/student_schedule_widget.dart';
import 'components/student_announcements_sheet.dart';
import 'components/student_sticky_top_header.dart';
import '../../esp32_hub/presentation/student_esp32_sync_modal.dart';
import '../../esp32_hub/domain/esp32_hub_models.dart';
import '../../esp32_hub/data/saved_materials_service.dart';
import '../../esp32_hub/presentation/saved_offline_materials_modal.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  Timer? _scheduleTicker;

  @override
  void initState() {
    super.initState();
    _startScheduleTicker();
  }

  void _startScheduleTicker() {
    _scheduleTicker?.cancel();
    _scheduleTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scheduleTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final currentUser = ref.watch(authProvider);
    final courses = ref.watch(studentCoursesProvider);
    final allAnnouncements = ref.watch(announcementsProvider);

    if (currentUser == null) return const SizedBox.shrink();

    if (currentUser.mustChangePassword) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/student/profile');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
    final isCompact = screenWidth < 400;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Persistent Sticky Top Header (Profile on Left, Institutional Actions on Right)
            StudentStickyTopHeader(isCompact: isCompact),

            // Scrollable Dashboard Body
            Expanded(
              child: RefreshIndicator(
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
                    horizontal: isDesktop ? 32 : (isCompact ? 14 : 20),
                    vertical: isDesktop ? 16 : 8,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1360),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Responsive Body: 2 Columns on Desktop, 1 Column on Mobile
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column (flex: 7): Offline Hub, Continue Learning, Class Schedule
                                Expanded(
                                  flex: 7,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildEsp32OfflineHubCard(context, currentUser),
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
                                _buildEsp32OfflineHubCard(context, currentUser),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEsp32OfflineHubCard(BuildContext context, dynamic currentUser) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.border,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.qr_code_scanner, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Classroom Offline Hub',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'OFFLINE HUB',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scan teacher\'s QR code or read and review saved modules & quizzes completely offline.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<List<HubMaterialItem>>(
            valueListenable: SavedMaterialsService.instance.savedMaterialsNotifier,
            builder: (context, savedList, _) {
              final count = savedList.length;
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        SavedOfflineMaterialsModal.show(
                          context,
                          studentName: currentUser.fullName,
                          studentSection: currentUser.section,
                        );
                      },
                      icon: Icon(Icons.folder_special_outlined, size: 16, color: AppTheme.primary),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          count > 0 ? 'Saved ($count)' : 'Saved Materials',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.text),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.text,
                        side: BorderSide(
                          color: AppTheme.border,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        StudentEsp32SyncModal.show(
                          context,
                          studentName: currentUser.fullName,
                          studentSection: currentUser.section,
                          onSyncCompleted: () {
                            ref.read(studentCoursesProvider.notifier).reload();
                          },
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Scan QR',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
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


  Widget _buildQuizzesSection(BuildContext context, List<Map<String, dynamic>> pendingQuizzes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.quiz_outlined, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Assigned Quizzes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (pendingQuizzes.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  '${pendingQuizzes.length} Pending',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
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
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.campaign_outlined, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Announcements',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (studentAnnouncements.isNotEmpty)
              GestureDetector(
                onTap: () => showStudentAnnouncementsSheet(context, studentAnnouncements),
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
                    foregroundColor: Colors.white,
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
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isHigh ? AppTheme.error.withValues(alpha: 0.10) : AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isHigh ? AppTheme.error : AppTheme.primary,
                    letterSpacing: 0.3,
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
    final scheduleStart = q['schedule_start']?.toString();
    final scheduleEnd = q['schedule_end']?.toString();
    final effectiveDeadline = (scheduleEnd != null && scheduleEnd.isNotEmpty) ? scheduleEnd : dueDate;

    final isDeadlinePassed = effectiveDeadline != null && effectiveDeadline.isNotEmpty && PhilippineTimeHelper.isDatePassed(effectiveDeadline);
    final isNotYetAvailable = !isDeadlinePassed && scheduleStart != null && scheduleStart.isNotEmpty && !PhilippineTimeHelper.isDatePassed(scheduleStart);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.border,
        ),
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
              if (effectiveDeadline != null && effectiveDeadline.isNotEmpty)
                _buildDueDateBadge(effectiveDeadline),
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
            child: isDeadlinePassed
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.event_busy, size: 16, color: AppTheme.textMuted),
                    label: Text('Missed Quiz (Closed)', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textMuted,
                      side: BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                : isNotYetAvailable
                    ? OutlinedButton.icon(
                        onPressed: () async {
                          if (PhilippineTimeHelper.isDatePassed(scheduleStart)) {
                            if (quizId != null) {
                              await context.push('/quiz/$quizId');
                              if (context.mounted) {
                                ref.read(studentQuizAssignmentsProvider.notifier).reload();
                                ref.read(studentProgressProvider.notifier).loadProgress();
                                ref.read(studentCoursesProvider.notifier).reload();
                              }
                            }
                          } else {
                            final remaining = PhilippineTimeHelper.timeUntil(scheduleStart);
                            final timeStr = PhilippineTimeHelper.formatRemaining(remaining);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Quiz unlocks in $timeStr (at ${PhilippineTimeHelper.formatDateTime(scheduleStart)}). It will automatically unlock!'),
                                duration: const Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.lock_clock, size: 16, color: AppTheme.textMuted),
                        label: Text('Locked — Opens ${PhilippineTimeHelper.formatDateTime(scheduleStart)}', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textMuted,
                          side: BorderSide(color: AppTheme.border.withValues(alpha: 0.6)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      )
                    : ElevatedButton.icon(
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
    final dt = PhilippineTimeHelper.parseToPht(rawDate);
    String label;
    Color badgeColor;

    if (dt == null) {
      label = rawDate.length > 10 ? rawDate.substring(0, 10) : rawDate;
      badgeColor = AppTheme.error;
    } else {
      final now = PhilippineTimeHelper.now();
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
