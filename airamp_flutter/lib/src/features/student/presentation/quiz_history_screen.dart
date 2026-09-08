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
  int _selectedSubjectIndex = 0;

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

    // Compute dynamic summary stats
    final totalAttempts = attempts.length;
    final passedCount = attempts.where((a) => (a['is_passed'] == 1 || a['is_passed'] == true)).length;
    final avgScore = totalAttempts > 0
        ? '${((attempts.map((a) => (a['percentage'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b)) / totalAttempts).toStringAsFixed(0)}%'
        : '0%';
    final bestScore = totalAttempts > 0
        ? '${(attempts.map((a) => (a['percentage'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a > b ? a : b)).toStringAsFixed(0)}%'
        : '0%';

    // Build subject filter chip list
    final subjectFilters = <String>['All'];
    for (final course in enrolledCourses) {
      final label = (course['code'] as String?)?.isNotEmpty == true
          ? course['code'] as String
          : (course['name'] as String? ?? 'Course');
      subjectFilters.add(label);
    }

    // Safety bounds on subject index
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
            await ref.read(studentQuizAttemptsProvider.notifier).loadAttempts(subjectId: subjectId);
            await ref.read(studentCoursesProvider.notifier).reload();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment, color: AppTheme.primary, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Quiz History',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete record of all your quiz attempts',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),

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
                const SizedBox(height: 24),

                // Dynamic Subject Filter Chips
                if (subjectFilters.isNotEmpty) ...[
                  SizedBox(
                    height: 40,
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
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive ? AppTheme.primary : AppTheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isActive ? AppTheme.primary : AppTheme.border),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              subjectFilters[index],
                              style: TextStyle(
                                color: isActive ? Colors.white : AppTheme.textSecondary,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Dynamic History List or Empty State
                if (attempts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 54, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No Quiz Attempts Yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Complete lesson quizzes in your courses to track your scores, review answers, and monitor performance.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/student/courses'),
                          icon: const Icon(Icons.school, size: 16),
                          label: const Text('Explore Courses'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      final rawDate = attempt['completed_at'] as String?;
                      final subject = (attempt['subject_code'] as String?)?.isNotEmpty == true
                          ? attempt['subject_code'] as String
                          : (attempt['subject_name'] as String? ?? 'Subject');
                      final loTitle = attempt['lo_title'] as String? ?? 'Learning Outcome';
                      final quizTitle = '$loTitle Quiz';
                      final duration = _formatDuration((attempt['duration_seconds'] as num?)?.toInt());

                      return _buildHistoryCard(
                        attempt: attempt,
                        subject: subject,
                        loTitle: loTitle,
                        quizTitle: quizTitle,
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
            ),
          ),
        ),
      ),
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              subject,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loTitle,
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        quizTitle,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text('$date at $time', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(width: 12),
                          Icon(Icons.schedule, size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(duration, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isPassed ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(29),
                    border: Border.all(
                      color: isPassed ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.error.withValues(alpha: 0.3),
                      width: 2.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPassed ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                      Text(
                        '/$total',
                        style: TextStyle(
                          fontSize: 10,
                          color: isPassed ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
          InkWell(
            onTap: () => _showAttemptDetailsModal(attempt, subject, loTitle, score, total, percentage, isPassed, date, time, duration),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isPassed ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: isPassed ? AppTheme.success : AppTheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPassed ? 'Passed' : 'Failed',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isPassed ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${percentage.toStringAsFixed(0)}%)',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text('Review', style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttemptDetailsModal(
    Map<String, dynamic> attempt,
    String subject,
    String loTitle,
    int score,
    int total,
    double percentage,
    bool isPassed,
    String date,
    String time,
    String duration,
  ) {
    final loId = attempt['lo_id'] as int?;
    final subjectId = attempt['subject_id'] as int?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quiz Result Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPassed ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPassed ? 'PASSED' : 'FAILED',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isPassed ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Subject', subject),
                    const Divider(height: 16),
                    _buildModalRow('Topic/Outcome', loTitle),
                    const Divider(height: 16),
                    _buildModalRow('Score', '$score / $total (${percentage.toStringAsFixed(0)}%)'),
                    const Divider(height: 16),
                    _buildModalRow('Date & Time', '$date at $time'),
                    const Divider(height: 16),
                    _buildModalRow('Time Spent', duration),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (subjectId != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/student/course/$subjectId');
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('View Course', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (loId != null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/quiz/$loId');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Retake Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
