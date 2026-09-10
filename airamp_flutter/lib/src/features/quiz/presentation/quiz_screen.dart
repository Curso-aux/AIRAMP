import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../student/data/student_repository.dart';
import '../../auth/application/auth_provider.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String quizId;

  const QuizScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _state = 0; // 0: intro, 1: active, 2: results, 3: countdown
  bool _loading = true;

  int? _quizId;
  int _loId = 0;
  Map<String, dynamic>? _quizData;
  List<Map<String, dynamic>> _questions = [];
  int _passingScore = 70;
  int _subjectId = 0;
  String _quizTitle = '';
  int _timeLimitMinutes = 0;
  String? _scheduleStart;
  String? _scheduleEnd;

  int _currentIndex = 0;
  final Map<int, String> _selectedAnswers = {}; // question index -> 'A' | 'B' | 'C' | 'D'
  int _score = 0;
  double _percentage = 0.0;
  bool _isPassed = false;
  DateTime? _startTime;
  bool _hasAlreadyTaken = false; // Track if student already completed this quiz

  // Countdown Timer
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  DateTime? _scheduleStartDate;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scheduleTimer?.cancel();
    super.dispose();
  }

  Timer? _scheduleTimer;

  /// Periodically check if the quiz has become available
  void _startScheduleCheck() {
    _scheduleTimer?.cancel();
    _scheduleTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_scheduleStartDate != null && _isQuizAvailable()) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _state = 0; // Go to intro screen
          });
        }
      }
    });
  }

  Future<void> _loadQuiz() async {
    final parsedId = int.tryParse(widget.quizId);
    if (parsedId == null) {
      setState(() => _loading = false);
      return;
    }

    // Check if student already completed this quiz
    final student = ref.read(authProvider);
    final studentId = student?.id ?? '';
    // After teacher reset, attempts are deleted so student can retake
    final canAttempt = await DatabaseHelper().hasStudentCompletedQuiz(
      studentId: studentId,
      quizId: parsedId,
    );
    if (!canAttempt && mounted) {
      setState(() {
        _loading = false;
        _hasAlreadyTaken = true;
      });
      return;
    }

    // 1. Try loading as first-class quiz from `quizzes` table
    final quizData = await DatabaseHelper().getQuizById(parsedId);
    if (quizData != null && mounted) {
      final qList = (quizData['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final tLimit = (quizData['time_limit_minutes'] as int?) ?? 0;
      _scheduleStart = quizData['schedule_start'] as String?;
      _scheduleEnd = quizData['schedule_end'] as String?;
      DateTime? scheduleDate;
      if (_scheduleStart != null && _scheduleStart!.isNotEmpty) {
        try {
          scheduleDate = DateTime.parse(_scheduleStart!).toLocal();
        } catch (_) {}
      }

      setState(() {
        _quizId = parsedId;
        _loId = (quizData['lo_id'] as int?) ?? 0;
        _quizData = quizData;
        _questions = qList;
        _quizTitle = quizData['title']?.toString() ?? 'Assessment';
        _passingScore = (quizData['passing_score'] as int?) ?? 70;
        _subjectId = (quizData['subject_id'] as int?) ?? 0;
        _timeLimitMinutes = tLimit;
        _remainingSeconds = tLimit * 60;
        _scheduleStartDate = scheduleDate;
        _loading = false;
      });
      // Start schedule check if quiz has a future start time
      if (_scheduleStartDate != null && !_isQuizAvailable()) {
        _startScheduleCheck();
      }
      return;
    }

    // 2. Fallback: try loading as LO quiz
    final loData = await DatabaseHelper().getLoQuiz(parsedId);
    if (mounted) {
      if (loData != null) {
        final qList = (loData['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _quizId = null;
          _loId = parsedId;
          _quizData = loData;
          _questions = qList;
          _quizTitle = loData['title']?.toString() ?? 'Learning Outcome';
          _passingScore = (loData['passing_score'] as int?) ?? 70;
          _subjectId = (loData['subject_id'] as int?) ?? 0;
          _timeLimitMinutes = 0;
          _remainingSeconds = 0;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    }
  }

  void _startTimer() {
    if (_timeLimitMinutes <= 0) return;
    _remainingSeconds = _timeLimitMinutes * 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _submitQuiz(isTimeout: true);
      }
    });
  }

  // Check if the quiz is available now based on schedule_start
  bool _isQuizAvailable() {
    if (_scheduleStartDate == null) return true; // No schedule restriction
    return DateTime.now().isAfter(_scheduleStartDate!);
  }

  // Time remaining until quiz becomes available
  Duration _timeUntilAvailable() {
    if (_scheduleStartDate == null) return Duration.zero;
    return _scheduleStartDate!.difference(DateTime.now());
  }

  String _formatTimer(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _submitQuiz({bool isTimeout = false}) async {
    try {
      _countdownTimer?.cancel();

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

      // Use validation method to prevent duplicate attempts
      await ref.read(studentQuizAttemptsProvider.notifier).recordAttemptWithValidation(
        loId: _loId,
        quizId: _quizId,
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

      if (isTimeout) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            content: const Text("Time is up! Your quiz has been automatically submitted."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Quiz submission error: $e'),
          ),
        );
      }
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

    if (_quizData == null || _questions.isEmpty) {
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
                  _hasAlreadyTaken ? 'Quiz Already Completed' : 'No Assessment Questions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 8),
                Text(
                  _hasAlreadyTaken
                      ? 'You have already completed this quiz. Contact your instructor if you need to retake it.'
                      : 'The instructor has not added quiz questions for this assessment yet.',
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

    // Check schedule — if not yet available, show countdown
    if (_state == 3 || (_scheduleStartDate != null && !_isQuizAvailable())) {
      _state = 3; // Show countdown state
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _quizTitle,
          style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: AppTheme.text),
        actions: [
          if (_state == 1 && _timeLimitMinutes > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _remainingSeconds < 60
                        ? AppTheme.error.withValues(alpha: 0.15)
                        : AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _remainingSeconds < 60 ? AppTheme.error : AppTheme.primary,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 15,
                        color: _remainingSeconds < 60 ? AppTheme.error : AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimer(_remainingSeconds),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _remainingSeconds < 60 ? AppTheme.error : AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case 3:
        return _buildScheduleCountdown();
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

  /// Show a countdown until the quiz becomes available
  Widget _buildScheduleCountdown() {
    final duration = _timeUntilAvailable();
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60);
    final seconds = (duration.inSeconds % 60);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.schedule_outlined, size: 64, color: AppTheme.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Quiz Not Available Yet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              const SizedBox(height: 8),
              Text(
                'This quiz will be available at:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (_scheduleStart != null && _scheduleStart!.isNotEmpty)
                Text(
                  _scheduleStart!.substring(0, _scheduleStart!.length - 3),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              const SizedBox(height: 32),
              // Countdown timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCountdownBlock(hours.toString().padLeft(2, '0'), 'HOURS'),
                    const SizedBox(width: 12),
                    Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.text)),
                    const SizedBox(width: 12),
                    _buildCountdownBlock(minutes.toString().padLeft(2, '0'), 'MINS'),
                    const SizedBox(width: 12),
                    Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.text)),
                    const SizedBox(width: 12),
                    _buildCountdownBlock(seconds.toString().padLeft(2, '0'), 'SECS'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_scheduleEnd != null && _scheduleEnd!.isNotEmpty)
                Text(
                  'Quiz will close at ${_scheduleEnd!.substring(0, _scheduleEnd!.length - 3)}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              const SizedBox(height: 32),
              // Auto-refresh countdown
              Text(
                'This page will auto-refresh when the quiz becomes available.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownBlock(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
        ),
      ],
    );
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
              _quizTitle,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'This assessment consists of ${_questions.length} multiple-choice questions.\nYou must achieve at least $_passingScore% to pass.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5, fontSize: 14),
            ),
            if (_timeLimitMinutes > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      'Time Limit: $_timeLimitMinutes Minutes',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
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
                  _startTimer();
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
                      fontSize: 17,
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
                const SizedBox(height: 10),
                _buildAnswerCard('B', q['option_b']?.toString() ?? '', selectedOption == 'B'),
                const SizedBox(height: 10),
                _buildAnswerCard('C', q['option_c']?.toString() ?? '', selectedOption == 'C'),
                const SizedBox(height: 10),
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
                  fontSize: 14,
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isPassed ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPassed ? Icons.check_circle_outline : Icons.cancel_outlined,
                size: 64,
                color: _isPassed ? AppTheme.success : AppTheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isPassed ? 'Congratulations! You Passed' : 'Assessment Not Passed',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _isPassed
                  ? 'Great job! Your score and progress have been recorded.'
                  : 'You scored ${_percentage.round()}%, which is below the passing mark of $_passingScore%. Review the answers below and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),

            // Score details card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
                      Text('Score', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('$_score / ${_questions.length}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text)),
                    ],
                  ),
                  Container(height: 36, width: 1, color: AppTheme.border),
                  Column(
                    children: [
                      Text('Percentage', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        '${_percentage.round()}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isPassed ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                  Container(height: 36, width: 1, color: AppTheme.border),
                  Column(
                    children: [
                      Text('Passing Mark', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('$_passingScore%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Question Review Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Review Answers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
            ),
            const SizedBox(height: 10),

            ..._questions.asMap().entries.map((entry) {
              final i = entry.key;
              final q = entry.value;
              final selected = _selectedAnswers[i] ?? 'None';
              final correct = (q['correct_option']?.toString() ?? 'A').toUpperCase().trim();
              final isCorrect = selected == correct;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCorrect ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          color: isCorrect ? AppTheme.success : AppTheme.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Question ${i + 1}: ${q['question_text']}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.text),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Answer: Option $selected ${isCorrect ? '(Correct)' : '(Incorrect)'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCorrect ? AppTheme.success : AppTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isCorrect)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Correct Answer: Option $correct (${q['option_${correct.toLowerCase()}'] ?? ''})',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/student/quiz-history');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Quizzes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
