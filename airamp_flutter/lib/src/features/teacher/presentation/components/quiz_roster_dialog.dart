import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/application/auth_provider.dart';
import '../../data/teacher_repository.dart';

class QuizRosterDialog extends ConsumerWidget {
  final int quizId;
  final String quizTitle;

  const QuizRosterDialog({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rosterAsync = ref.watch(quizRosterProvider(quizId));

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 550,
        height: 520,
        padding: const EdgeInsets.all(20),
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
                  child: Icon(Icons.people_outline, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assignment Roster & Live Scores',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      Text(
                        quizTitle,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppTheme.textMuted),
                ),
              ],
            ),
            const Divider(height: 24),

            // Roster List
            Expanded(
              child: rosterAsync.when(
                loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                error: (e, _) => Center(child: Text('Error loading roster: $e', style: TextStyle(color: AppTheme.error))),
                data: (roster) {
                  if (roster.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_ind_outlined, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 8),
                          Text('No students assigned yet.', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    );
                  }

                  final completedCount = roster.where((r) => r['status'] == 'completed').length;
                  final totalCount = roster.length;

                  return Column(
                    children: [
                      // KPI bar
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMiniMetric('Assigned', '$totalCount', AppTheme.primary),
                            _buildMiniMetric('Completed', '$completedCount', AppTheme.success),
                            _buildMiniMetric('Pending', '${totalCount - completedCount}', Colors.orange),
                            _buildMiniMetric(
                              'Completion',
                              '${totalCount > 0 ? ((completedCount / totalCount) * 100).round() : 0}%',
                              AppTheme.accent,
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: ListView.builder(
                          itemCount: roster.length,
                          itemBuilder: (context, i) {
                            final row = roster[i];
                            final name = row['student_name']?.toString() ?? 'Student';
                            final email = row['student_email']?.toString() ?? '';
                            final section = row['student_section']?.toString() ?? 'No section';
                            final isCompleted = row['status'] == 'completed';
                            final score = row['score'] ?? 0;
                            final total = row['total_questions'] ?? 0;
                            final pct = (row['percentage'] as num?)?.round() ?? 0;
                            final result = row['result']?.toString() ?? 'Pending';
                            final studentId = row['student_id']?.toString() ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCompleted ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isCompleted ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.primary.withValues(alpha: 0.15),
                                    child: Icon(
                                      isCompleted ? Icons.check : Icons.hourglass_empty,
                                      color: isCompleted ? AppTheme.success : Colors.orange,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.text)),
                                        const SizedBox(height: 2),
                                        Text('$email · Section: $section', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Reset/Retake button for completed students
                                      if (isCompleted)
                                        Tooltip(
                                          message: 'Reset this student to allow retake',
                                          child: IconButton(
                                            icon: const Icon(Icons.refresh, size: 18),
                                            color: AppTheme.accent,
                                            onPressed: () => _showResetConfirmation(context, ref, studentId, name),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          ),
                                        ),
                                      // Score display or Pending
                                      if (isCompleted)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: result == 'Passed' ? AppTheme.success.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            result == 'Passed' ? 'Passed ($pct%)' : 'Failed',
                                            style: TextStyle(
                                              color: result == 'Passed' ? AppTheme.success : Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Pending',
                                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                      const SizedBox(height: 2),
                                      Text('$score / $total pts', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                    ],
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref, String studentId, String studentName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Reset Student Quiz'),
        content: Text('Reset attempt for $studentName? They will be able to retake the quiz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper().resetStudentQuizAttempt(
                quizId: quizId,
                studentId: studentId,
              );
              // Refresh the roster so the reset shows immediately
              ref.invalidate(quizRosterProvider(quizId));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppTheme.success,
                    content: Text('$studentName can now retake the quiz.'),
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}
