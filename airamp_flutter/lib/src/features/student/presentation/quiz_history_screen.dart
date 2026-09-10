import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../data/student_repository.dart';

class QuizHistoryScreen extends ConsumerStatefulWidget {
  const QuizHistoryScreen({super.key});

  @override
  ConsumerState<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends ConsumerState<QuizHistoryScreen> {
  int _selectedTab = 0; // 0: Assigned Quizzes, 1: Quiz History
  int _selectedSubjectIndex = 0;

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    } catch (_) {
      return 'Recent';
    }
  }

  bool _isDatePassed(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return dt.isBefore(DateTime.now());
    } catch (_) {
      return true;
    }
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
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.assignment, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Quizzes',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        Text(
                          'Assigned quizzes, exams & live results',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Top Segmented Tab Switcher
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTab == 0 ? AppTheme.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_turned_in_outlined,
                                  size: 16,
                                  color: _selectedTab == 0 ? Colors.black : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Assigned Quizzes',
                                  style: TextStyle(
                                    color: _selectedTab == 0 ? Colors.black : AppTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                if (pendingCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 0 ? Colors.black : Colors.orange,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$pendingCount',
                                      style: TextStyle(
                                        color: _selectedTab == 0 ? AppTheme.primary : Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
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
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTab == 1 ? AppTheme.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 16,
                                  color: _selectedTab == 1 ? Colors.black : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'History & Results ($totalAttempts)',
                                  style: TextStyle(
                                    color: _selectedTab == 1 ? Colors.black : AppTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
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
    if (assignedQuizzes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(Icons.task_alt, size: 56, color: AppTheme.success),
            const SizedBox(height: 14),
            Text(
              'All Caught Up!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.text),
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
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.text),
        ),
        const SizedBox(height: 10),
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

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCompleted ? AppTheme.border : AppTheme.primary.withValues(alpha: 0.5),
                  width: isCompleted ? 1 : 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          subjectCode,
                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subjectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCompleted ? AppTheme.success.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isCompleted ? 'Completed · $pct%' : 'Pending',
                          style: TextStyle(
                            color: isCompleted ? AppTheme.success : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Not Yet Available banner
                  if (scheduleStart != null && scheduleStart.isNotEmpty && !_isDatePassed(scheduleStart))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Available from ${_formatDate(scheduleStart)}',
                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  if (scheduleStart != null && scheduleStart.isNotEmpty && !_isDatePassed(scheduleStart))
                    const SizedBox(height: 10),

                  // Quiz Title
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
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
                      _buildMetaChip(Icons.person_outline, teacherName),
                      _buildMetaChip(Icons.help_outline, '$qCount Questions'),
                      _buildMetaChip(Icons.timer_outlined, timeLimit > 0 ? '$timeLimit mins' : 'No limit'),
                      _buildMetaChip(Icons.verified_outlined, 'Pass: $passingScore%'),
                      if (dueDate != null && dueDate.isNotEmpty)
                        _buildMetaChip(Icons.calendar_today, 'Due ${_formatDate(dueDate)}'),
                      if (scheduleStart != null && scheduleStart.isNotEmpty)
                        _buildMetaChip(Icons.schedule, 'Starts ${_formatDate(scheduleStart)}'),
                      if (scheduleEnd != null && scheduleEnd.isNotEmpty)
                        _buildMetaChip(Icons.access_time, 'Until ${_formatDate(scheduleEnd)}'),
                      if (quizStatus == 'draft')
                        _buildMetaChip(Icons.save, 'Draft'),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: isCompleted
                        ? Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                    side: BorderSide(color: AppTheme.primary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () => context.push('/quiz/$quizId'),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retake Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Score: $score / $qCount',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success, fontSize: 13),
                                ),
                              ),
                            ],
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => context.push('/quiz/$quizId'),
                            icon: const Icon(Icons.play_arrow, size: 18),
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
        Icon(icon, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dynamic Stats Row
        Row(
          children: [
            Expanded(child: _buildStatCard('Attempts', '$totalAttempts', Icons.assignment, AppTheme.primary)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('Passed', '$passedCount', Icons.check_circle, AppTheme.success)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('Avg Score', avgScore, Icons.trending_up, AppTheme.accent)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('Best', bestScore, Icons.emoji_events, AppTheme.warning)),
          ],
        ),
        const SizedBox(height: 18),

        // Dynamic Subject Filter Chips
        if (subjectFilters.isNotEmpty) ...[
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: subjectFilters.length,
              itemBuilder: (context, index) {
                final isActive = _selectedSubjectIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedSubjectIndex = index);
                    final subjectId = index == 0 || index > enrolledCourses.length
                        ? null
                        : (enrolledCourses[index - 1]['id'] as int?);
                    ref.read(studentQuizAttemptsProvider.notifier).loadAttempts(subjectId: subjectId);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.primary : AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? AppTheme.primary : AppTheme.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      subjectFilters[index],
                      style: TextStyle(
                        color: isActive ? Colors.black : AppTheme.textSecondary,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
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
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 56, color: AppTheme.textMuted),
                const SizedBox(height: 14),
                Text(
                  'No Quiz Attempts Yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 6),
                Text(
                  'Take quizzes in the "Assigned Quizzes" tab to record your scores and review performance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
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
              );
            },
          ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
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
  }) {
    final double percentage = total > 0 ? (score / total) * 100 : 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subject,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPassed ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPassed ? 'PASSED' : 'FAILED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPassed ? AppTheme.success : AppTheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              quizTitle,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '$score / $total',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${percentage.toStringAsFixed(0)}%)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isPassed ? AppTheme.success : AppTheme.error,
                  ),
                ),
                const Spacer(),
                Text(
                  '$date · $time',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
