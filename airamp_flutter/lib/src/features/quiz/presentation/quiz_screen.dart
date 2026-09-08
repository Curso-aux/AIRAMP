import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../student/data/student_repository.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String quizId;

  const QuizScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _state = 0; // 0: intro, 1: active, 2: results
  bool _loading = true;

  Map<String, dynamic>? _loData;
  List<Map<String, dynamic>> _questions = [];
  int _passingScore = 70;
  int _subjectId = 0;
  String _loTitle = '';

  int _currentIndex = 0;
  final Map<int, String> _selectedAnswers = {}; // question index -> 'A' | 'B' | 'C' | 'D'
  int _score = 0;
  double _percentage = 0.0;
  bool _isPassed = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    final loId = int.tryParse(widget.quizId);
    if (loId == null) {
      setState(() => _loading = false);
      return;
    }

    final data = await DatabaseHelper().getLoQuiz(loId);
    if (mounted) {
      if (data != null) {
        final qList = (data['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _loData = data;
          _questions = qList;
          _loTitle = data['title']?.toString() ?? 'Learning Outcome';
          _passingScore = (data['passing_score'] as int?) ?? 70;
          _subjectId = (data['subject_id'] as int?) ?? 0;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitQuiz() async {
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final correct = (q['correct_option']?.toString() ?? '').toUpperCase().trim();
      final selected = (_selectedAnswers[i] ?? '').toUpperCase().trim();
      if (selected == correct) {
        score++;
      }
    }

    final total = _questions.length;
    final pct = total > 0 ? (score / total) * 100 : 0.0;
    final passed = pct >= _passingScore;
    final duration = _startTime != null ? DateTime.now().difference(_startTime!).inSeconds : 0;
    final loId = int.tryParse(widget.quizId) ?? 0;

    await ref.read(studentQuizAttemptsProvider.notifier).recordAttempt(
      loId: loId,
      subjectId: _subjectId,
      score: score,
      totalQuestions: total,
      percentage: pct,
      isPassed: passed,
      durationSeconds: duration,
    );

    if (mounted) {
      setState(() {
        _score = score;
        _percentage = pct;
        _isPassed = passed;
        _state = 2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);

    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text('Assessment', style: TextStyle(color: AppTheme.text)),
          iconTheme: IconThemeData(color: AppTheme.text),
        ),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_loData == null || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text('Assessment', style: TextStyle(color: AppTheme.text)),
          iconTheme: IconThemeData(color: AppTheme.text),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 64, color: AppTheme.textMuted),
                const SizedBox(height: 16),
                Text(
                  'No Assessment Questions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 8),
                Text(
                  'The instructor has not added quiz questions for this learning outcome yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Back to Course', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_loTitle, style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: AppTheme.text),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case 0:
        return _buildIntro();
      case 1:
        return _buildActive();
      case 2:
        return _buildResults();
      default:
        return const SizedBox();
    }
  }

  Widget _buildIntro() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.quiz_outlined, size: 64, color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Assessment: $_loTitle',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'This quiz consists of ${_questions.length} multiple-choice questions.\nYou must achieve at least $_passingScore% to pass and complete this learning outcome.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5, fontSize: 14),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _state = 1;
                    _startTime = DateTime.now();
                    _currentIndex = 0;
                    _selectedAnswers.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Start Assessment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActive() {
    final q = _questions[_currentIndex];
    final selectedOption = _selectedAnswers[_currentIndex];
    final isLast = _currentIndex == _questions.length - 1;

    return Column(
      children: [
        // Top Progress Indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_currentIndex + 1} of ${_questions.length}',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(((_currentIndex + 1) / _questions.length) * 100).round()}%',
                    style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _questions.length,
                  backgroundColor: AppTheme.border,
                  color: AppTheme.primary,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppTheme.border),

        // Question content & options
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    q['question_text']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Select one answer:',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                _buildAnswerCard('A', q['option_a']?.toString() ?? '', selectedOption == 'A'),
                const SizedBox(height: 12),
                _buildAnswerCard('B', q['option_b']?.toString() ?? '', selectedOption == 'B'),
                const SizedBox(height: 12),
                _buildAnswerCard('C', q['option_c']?.toString() ?? '', selectedOption == 'C'),
                const SizedBox(height: 12),
                _buildAnswerCard('D', q['option_d']?.toString() ?? '', selectedOption == 'D'),
              ],
            ),
          ),
        ),

        // Bottom Navigation bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              if (_currentIndex > 0)
                OutlinedButton(
                  onPressed: () {
                    setState(() => _currentIndex--);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.text,
                    side: BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Previous'),
                ),
              if (_currentIndex > 0) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: selectedOption != null
                      ? () {
                          if (isLast) {
                            _submitQuiz();
                          } else {
                            setState(() => _currentIndex++);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: AppTheme.border,
                    disabledForegroundColor: AppTheme.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isLast ? 'Submit Assessment' : 'Next Question',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerCard(String optionKey, String text, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedAnswers[_currentIndex] = optionKey;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.primary : AppTheme.background,
                border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
              ),
              child: Center(
                child: Text(
                  optionKey,
                  style: TextStyle(
                    color: isSelected ? Colors.black : AppTheme.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isSelected ? AppTheme.text : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _isPassed ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPassed ? Icons.check_circle_outline : Icons.cancel_outlined,
                size: 72,
                color: _isPassed ? AppTheme.success : AppTheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isPassed ? 'Congratulations! You Passed' : 'Assessment Not Passed',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isPassed
                  ? 'Great job! This learning outcome is now marked as complete.'
                  : 'You did not reach the passing score of $_passingScore%. You can review the materials and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),

            // Score details card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Score', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('$_score / ${_questions.length}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text)),
                    ],
                  ),
                  Container(height: 40, width: 1, color: AppTheme.border),
                  Column(
                    children: [
                      Text('Percentage', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        '${_percentage.round()}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _isPassed ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                  Container(height: 40, width: 1, color: AppTheme.border),
                  Column(
                    children: [
                      Text('Passing Score', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('$_passingScore%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Return to Course', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _state = 0;
                  _currentIndex = 0;
                  _selectedAnswers.clear();
                  _score = 0;
                });
              },
              icon: Icon(Icons.refresh, color: AppTheme.primary, size: 18),
              label: Text('Retake Assessment', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

