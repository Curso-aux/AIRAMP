import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/philippine_time_helper.dart';
import '../data/student_repository.dart';
import '../../quiz/presentation/quiz_flashcard_screen.dart';

class QuizHistoryScreen extends ConsumerStatefulWidget {
  const QuizHistoryScreen({super.key});

  @override
  ConsumerState<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends ConsumerState<QuizHistoryScreen> {
  int _selectedTab = 0; // 0: Assigned Quizzes, 1: Quiz History
  int _selectedSubjectIndex = 0;
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

  String _formatDate(String? isoString) {
    return PhilippineTimeHelper.formatDate(isoString);
  }

  bool _isDatePassed(String isoString) {
    return PhilippineTimeHelper.isDatePassed(isoString);
  }

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $ampm';
    } catch (_) {
      return '';
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '< 1m';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final enrolledCourses = ref.watch(studentCoursesProvider);
    final attempts = ref.watch(studentQuizAttemptsProvider);
    final assignedQuizzes = ref.watch(studentQuizAssignmentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    // Compute dynamic summary stats
    final totalAttempts = attempts.length;
    final passedCount = attempts.where((a) => (a['is_passed'] == 1 || a['is_passed'] == true)).length;
    final avgScore = totalAttempts > 0
        ? '${((attempts.map((a) => (a['percentage'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b)) / totalAttempts).toStringAsFixed(0)}%'
        : '0%';
    final bestScore = totalAttempts > 0
        ? '${(attempts.map((a) => (a['percentage'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a > b ? a : b)).toStringAsFixed(0)}%'
        : '0%';

    final pendingCount = assignedQuizzes.where((q) => q['status'] == 'pending').length;

    // Build subject filter chip list
    final subjectFilters = <String>['All'];
    for (final course in enrolledCourses) {
      final label = (course['code'] as String?)?.isNotEmpty == true
          ? course['code'] as String
          : (course['name'] as String? ?? 'Course');
      subjectFilters.add(label);
    }

    if (_selectedSubjectIndex >= subjectFilters.length) {
      _selectedSubjectIndex = 0;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final subjectId = _selectedSubjectIndex == 0 || _selectedSubjectIndex > enrolledCourses.length
                ? null
                : (enrolledCourses[_selectedSubjectIndex - 1]['id'] as int?);
            await ref.read(studentQuizAssignmentsProvider.notifier).loadAssignedQuizzes(subjectId: subjectId);
            await ref.read(studentQuizAttemptsProvider.notifier).loadAttempts(subjectId: subjectId);
            await ref.read(studentCoursesProvider.notifier).reload();
          },
          color: primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Icon(
                        Icons.assignment_outlined,
                        color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Quizzes',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Assigned quizzes, exams & live results',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Top Segmented Tab Switcher (Matching Courses Design System)
                Container(
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkInputBg : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 0),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _selectedTab == 0
                                  ? (isDark ? AppTheme.darkSurface : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _selectedTab == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_turned_in_outlined,
                                  size: 14,
                                  color: _selectedTab == 0
                                      ? (isDark ? AppTheme.darkText : const Color(0xFF0F172A))
                                      : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Assigned Quizzes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w500,
                                    color: _selectedTab == 0
                                        ? (isDark ? AppTheme.darkText : const Color(0xFF0F172A))
                                        : AppTheme.textMuted,
                                  ),
                                ),
                                if (pendingCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$pendingCount',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppTheme.darkText : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 1),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _selectedTab == 1
                                  ? (isDark ? AppTheme.darkSurface : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _selectedTab == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 14,
                                  color: _selectedTab == 1
                                      ? (isDark ? AppTheme.darkText : const Color(0xFF0F172A))
                                      : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'History & Results ($totalAttempts)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w500,
                                    color: _selectedTab == 1
                                        ? (isDark ? AppTheme.darkText : const Color(0xFF0F172A))
                                        : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Content Views
                if (_selectedTab == 0)
                  _buildAssignedQuizzesView(assignedQuizzes)
                else
                  _buildQuizHistoryView(
                    attempts: attempts,
                    enrolledCourses: enrolledCourses,
                    totalAttempts: totalAttempts,
                    passedCount: passedCount,
                    avgScore: avgScore,
                    bestScore: bestScore,
                    subjectFilters: subjectFilters,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 0: ASSIGNED QUIZZES VIEW ---
  Widget _buildAssignedQuizzesView(List<Map<String, dynamic>> assignedQuizzes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    if (assignedQuizzes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt_rounded,
                size: 36,
                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'All Caught Up!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You have no pending quizzes or assignments right now. When your teacher assigns a new quiz, it will appear here immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Assigned Quizzes (${assignedQuizzes.length})',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: assignedQuizzes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = assignedQuizzes[index];
            final quizId = item['quiz_id'] as int;
            final title = item['title']?.toString() ?? 'Quiz';
            final desc = item['description']?.toString() ?? '';
            final subjectCode = item['subject_code']?.toString() ?? 'CS';
            final subjectName = item['subject_name']?.toString() ?? 'Subject';
            final teacherName = item['teacher_name']?.toString() ?? 'Instructor';
            final qCount = item['question_count'] ?? item['total_questions'] ?? 0;
            final timeLimit = item['time_limit_minutes'] ?? 0;
            final passingScore = item['passing_score'] ?? 70;
            final dueDate = item['due_date']?.toString();
            final isCompleted = item['status'] == 'completed';
            final quizStatus = item['quiz_status']?.toString();
            final score = item['score'] ?? 0;
            final pct = (item['percentage'] as num?)?.round() ?? 0;
            final scheduleStart = item['schedule_start']?.toString();
            final scheduleEnd = item['schedule_end']?.toString();

            final isDeadlinePassed = (scheduleEnd != null && scheduleEnd.isNotEmpty && _isDatePassed(scheduleEnd)) ||
                (dueDate != null && dueDate.isNotEmpty && _isDatePassed(dueDate));
            final isMissed = !isCompleted && (item['status'] == 'missed' || isDeadlinePassed);
            final isNotYetAvailable = !isCompleted && !isMissed && scheduleStart != null && scheduleStart.isNotEmpty && !_isDatePassed(scheduleStart);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          subjectCode,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.darkText : const Color(0xFF1E293B),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subjectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? (isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9))
                              : isMissed
                                  ? (isDark ? const Color(0xFF2C1E20) : const Color(0xFFFEE2E2))
                                  : isNotYetAvailable
                                      ? (isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9))
                                      : (isDark ? const Color(0xFF1E2B24) : const Color(0xFFDCFCE7)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCompleted
                                ? (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))
                                : isMissed
                                    ? (isDark ? const Color(0xFF4C282C) : const Color(0xFFFECACA))
                                    : isNotYetAvailable
                                        ? (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))
                                        : (isDark ? const Color(0xFF234433) : const Color(0xFFBBF7D0)),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          isCompleted
                              ? 'Completed · $pct%'
                              : isMissed
                                  ? 'Missed'
                                  : isNotYetAvailable
                                      ? 'Upcoming'
                                      : 'Open',
                          style: TextStyle(
                            color: isCompleted
                                ? AppTheme.textSecondary
                                : isMissed
                                    ? (isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B))
                                    : isNotYetAvailable
                                        ? AppTheme.textSecondary
                                        : (isDark ? const Color(0xFF34D399) : const Color(0xFF166534)),
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Missed Quiz notice (Subtle & Institutional)
                  if (isMissed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Submission window closed on ${_formatDate(scheduleEnd ?? dueDate)}',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.normal,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Not Yet Available notice
                  if (isNotYetAvailable)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Available from ${_formatDate(scheduleStart)}',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.normal,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Quiz Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Metadata row
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildMetaChip(Icons.person_outline_rounded, teacherName),
                      _buildMetaChip(Icons.help_outline_rounded, '$qCount Questions'),
                      _buildMetaChip(Icons.timer_outlined, timeLimit > 0 ? '$timeLimit mins' : 'No limit'),
                      _buildMetaChip(Icons.verified_outlined, 'Pass: $passingScore%'),
                      if (dueDate != null && dueDate.isNotEmpty)
                        _buildMetaChip(Icons.calendar_today_outlined, 'Due ${_formatDate(dueDate)}'),
                      if (scheduleStart != null && scheduleStart.isNotEmpty)
                        _buildMetaChip(Icons.schedule_outlined, 'Starts ${_formatDate(scheduleStart)}'),
                      if (scheduleEnd != null && scheduleEnd.isNotEmpty)
                        _buildMetaChip(Icons.access_time_rounded, 'Until ${_formatDate(scheduleEnd)}'),
                      if (quizStatus == 'draft')
                        _buildMetaChip(Icons.save_outlined, 'Draft'),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: isCompleted
                        ? Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (ctx) => QuizFlashcardScreen(
                                              quizTitle: title,
                                              quizId: quizId,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.style_outlined, size: 16),
                                      label: const Text('Review Flashcards', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      'Score: $score / $qCount',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.textMuted,
                                    side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onPressed: null,
                                  icon: const Icon(Icons.lock_outline_rounded, size: 15),
                                  label: const Text('Quiz Completed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                              ),
                            ],
                          )
                        : isMissed
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.event_busy_outlined, size: 15, color: AppTheme.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Submission Window Closed',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : isNotYetAvailable
                                ? OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.textSecondary,
                                      side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () async {
                                      if (_isDatePassed(scheduleStart)) {
                                        await context.push('/quiz/$quizId');
                                        if (context.mounted) {
                                          ref.read(studentQuizAssignmentsProvider.notifier).reload();
                                        }
                                      } else {
                                        final remaining = PhilippineTimeHelper.timeUntil(scheduleStart);
                                        final timeStr = PhilippineTimeHelper.formatRemaining(remaining);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Quiz unlocks in $timeStr (at ${_formatDate(scheduleStart)}). It will automatically unlock!'),
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.schedule_rounded, size: 16),
                                    label: Text('Opens ${_formatDate(scheduleStart)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  )
                                : ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () async {
                                      await context.push('/quiz/$quizId');
                                      if (context.mounted) {
                                        ref.read(studentQuizAssignmentsProvider.notifier).reload();
                                        ref.read(studentQuizAttemptsProvider.notifier).loadAttempts();
                                        ref.read(studentCoursesProvider.notifier).reload();
                                      }
                                    },
                                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                    label: const Text('Take Quiz Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --- TAB 1: QUIZ HISTORY & PERFORMANCE VIEW ---
  Widget _buildQuizHistoryView({
    required List<Map<String, dynamic>> attempts,
    required List<Map<String, dynamic>> enrolledCourses,
    required int totalAttempts,
    required int passedCount,
    required String avgScore,
    required String bestScore,
    required List<String> subjectFilters,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Executive KPI Stat Cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: 'Attempts',
                value: '$totalAttempts',
                icon: Icons.assignment_outlined,
                accentColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                label: 'Passed',
                value: '$passedCount',
                icon: Icons.check_circle_outline_rounded,
                accentColor: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                label: 'Avg Score',
                value: avgScore,
                icon: Icons.trending_up_rounded,
                accentColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                label: 'Best Score',
                value: bestScore,
                icon: Icons.verified_outlined,
                accentColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Subject Filter Chips
        if (subjectFilters.isNotEmpty) ...[
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: subjectFilters.length,
              itemBuilder: (context, index) {
                final isActive = _selectedSubjectIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedSubjectIndex = index);
                      final subjectId = index == 0 || index > enrolledCourses.length
                          ? null
                          : (enrolledCourses[index - 1]['id'] as int?);
                      ref.read(studentQuizAttemptsProvider.notifier).loadAttempts(subjectId: subjectId);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? primary
                            : (isDark ? AppTheme.darkSurface : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? primary
                              : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        subjectFilters[index],
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // History List
        if (attempts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history_toggle_off_rounded,
                    size: 32,
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No Quiz Attempts Yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Take quizzes in the "Assigned Quizzes" tab to record your scores and review performance history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: attempts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final attempt = attempts[index];
              final isPassed = attempt['is_passed'] == 1 || attempt['is_passed'] == true;
              final score = (attempt['score'] as num?)?.toInt() ?? 0;
              final total = (attempt['total_questions'] as num?)?.toInt() ?? 0;
              final rawDate = attempt['attempted_at'] as String?;
              final subject = (attempt['subject_code'] as String?)?.isNotEmpty == true
                  ? attempt['subject_code'] as String
                  : (attempt['subject_name'] as String? ?? 'Subject');
              final loTitle = attempt['lo_title'] as String? ?? 'Assessment';
              final duration = _formatDuration((attempt['duration_seconds'] as num?)?.toInt());

              return _buildHistoryCard(
                attempt: attempt,
                subject: subject,
                loTitle: loTitle,
                quizTitle: loTitle,
                score: score,
                total: total,
                date: _formatDate(rawDate),
                time: _formatTime(rawDate),
                duration: duration,
                isPassed: isPassed,
                isDark: isDark,
              );
            },
          ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: accentColor, size: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard({
    required Map<String, dynamic> attempt,
    required String subject,
    required String loTitle,
    required String quizTitle,
    required int score,
    required int total,
    required String date,
    required String time,
    required String duration,
    required bool isPassed,
    required bool isDark,
  }) {
    final double percentage = total > 0 ? (score / total) * 100 : 0;
    final primary = AppTheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Subject Code Tag + Soft Status Pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkText : const Color(0xFF1E293B),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPassed
                        ? (isDark ? const Color(0x2410B981) : const Color(0xFFDCFCE7))
                        : (isDark ? const Color(0x24EF4444) : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isPassed
                          ? (isDark ? const Color(0x4010B981) : const Color(0xFFBBF7D0))
                          : (isDark ? const Color(0x40EF4444) : const Color(0xFFFECACA)),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPassed ? Icons.check_rounded : Icons.close_rounded,
                        size: 11,
                        color: isPassed
                            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                            : (isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C)),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isPassed ? 'Passed' : 'Needs Review',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPassed
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                              : (isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Quiz Title
            Text(
              quizTitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),

            // Score and Performance Row
            Row(
              children: [
                Text(
                  '$score / $total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPassed
                        ? (isDark ? const Color(0x1F10B981) : const Color(0xFFECFDF5))
                        : (isDark ? const Color(0x1FEF4444) : const Color(0xFFFFF1F2)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPassed
                          ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                          : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    if (duration.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.timer_outlined, size: 12, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        duration,
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  backgroundColor: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                  side: BorderSide(
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () {
                  final qId = attempt['quiz_id'] as int?;
                  final loId = attempt['lo_id'] as int?;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => QuizFlashcardScreen(
                        quizTitle: quizTitle,
                        quizId: qId,
                        loId: loId,
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.style_outlined, size: 15, color: primary),
                label: const Text(
                  'Review Flashcards',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
