import 'package:flutter/material.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../quiz/presentation/quiz_screen.dart';
import 'create_quiz_dialog.dart';

class QuizViewDialog extends StatefulWidget {
  final int quizId;
  final String quizTitle;
  final int subjectId;
  final String subjectName;
  final Map<String, dynamic>? initialQuizData;

  const QuizViewDialog({
    super.key,
    required this.quizId,
    required this.quizTitle,
    required this.subjectId,
    required this.subjectName,
    this.initialQuizData,
  });

  @override
  State<QuizViewDialog> createState() => _QuizViewDialogState();
}

class _QuizViewDialogState extends State<QuizViewDialog> {
  bool _loading = true;
  Map<String, dynamic>? _quizData;
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuizData != null) {
      _quizData = widget.initialQuizData;
      _questions = (widget.initialQuizData?['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _loading = false;
    } else {
      _loadQuiz();
    }
  }

  Future<void> _loadQuiz() async {
    final data = await DatabaseHelper().getQuizById(widget.quizId);
    if (!mounted) return;
    setState(() {
      _quizData = data;
      _questions = (data?['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPublished = (_quizData?['status']?.toString() ?? 'published') == 'published';
    final passingScore = _quizData?['passing_score'] as int? ?? 70;
    final timeLimit = _quizData?['time_limit_minutes'] as int? ?? 0;
    final dueDate = _quizData?['due_date']?.toString();
    final description = _quizData?['description']?.toString() ?? '';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 640,
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
                  child: Icon(Icons.quiz_outlined, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiz Overview & Questions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      Text(
                        widget.quizTitle,
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
            const Divider(height: 20),

            // Body
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _quizData == null
                      ? Center(
                          child: Text('Quiz details not found.', style: TextStyle(color: AppTheme.textMuted)),
                        )
                      : ListView(
                          children: [
                            // Metadata chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPublished
                                        ? AppTheme.success.withValues(alpha: 0.15)
                                        : Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isPublished
                                          ? AppTheme.success.withValues(alpha: 0.4)
                                          : Colors.orange.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isPublished ? Icons.check_circle_outline : Icons.edit_note,
                                        size: 14,
                                        color: isPublished ? AppTheme.success : Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isPublished ? 'Published' : 'Draft',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isPublished ? AppTheme.success : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Text(
                                    '${_questions.length} Questions',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Text(
                                    'Pass: $passingScore%',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Text(
                                    timeLimit > 0 ? '$timeLimit Mins' : 'No Limit',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
                                  ),
                                ),
                                if (dueDate != null && dueDate.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Text(
                                      'Due: ${dueDate.length > 10 ? dueDate.substring(0, 10) : dueDate}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                                    ),
                                  ),
                              ],
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(
                                  description,
                                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'Questions & Answer Key',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.text),
                            ),
                            const SizedBox(height: 10),

                            if (_questions.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text('No questions added yet.', style: TextStyle(color: AppTheme.textMuted)),
                                ),
                              )
                            else
                              ...List.generate(_questions.length, (index) {
                                final q = _questions[index];
                                final qText = q['question_text']?.toString() ?? 'Question';
                                final optA = q['option_a']?.toString() ?? '';
                                final optB = q['option_b']?.toString() ?? '';
                                final optC = q['option_c']?.toString() ?? '';
                                final optD = q['option_d']?.toString() ?? '';
                                final correctOpt = (q['correct_option']?.toString() ?? 'A').toUpperCase();

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Q${index + 1}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              qText,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppTheme.text,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _buildOptionRow('A', optA, correctOpt == 'A'),
                                      _buildOptionRow('B', optB, correctOpt == 'B'),
                                      if (optC.isNotEmpty) _buildOptionRow('C', optC, correctOpt == 'C'),
                                      if (optD.isNotEmpty) _buildOptionRow('D', optD, correctOpt == 'D'),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
            ),
            const Divider(height: 20),

            // Footer Actions
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => QuizScreen(
                          quizId: widget.quizId.toString(),
                          isTeacherPreview: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_outlined, size: 16),
                  label: const Text('Preview as Student'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (ctx) => CreateQuizDialog(
                                initialSubjectId: widget.subjectId,
                                subjectName: widget.subjectName,
                                quizId: widget.quizId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text(
                          'Edit Quiz',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow(String letter, String text, bool isCorrect) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCorrect ? AppTheme.success.withValues(alpha: 0.12) : AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCorrect ? AppTheme.success : AppTheme.border,
          width: isCorrect ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCorrect ? AppTheme.success : AppTheme.surfaceLight,
            ),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isCorrect ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                color: isCorrect ? AppTheme.success : AppTheme.text,
              ),
            ),
          ),
          if (isCorrect) ...[
            const SizedBox(width: 6),
            Icon(Icons.check_circle, size: 16, color: AppTheme.success),
          ],
        ],
      ),
    );
  }
}
