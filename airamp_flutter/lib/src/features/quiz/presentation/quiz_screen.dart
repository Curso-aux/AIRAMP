import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/skeleton_loader.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../student/data/student_repository.dart';
import '../../auth/application/auth_provider.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String quizId;
  final bool isTeacherPreview;

  const QuizScreen({super.key, required this.quizId, this.isTeacherPreview = false});

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
  bool _isTimedOut = false;
  DateTime? _startTime;
  bool _hasAlreadyTaken = false; // Track if student already completed this quiz

  // Countdown Timer
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  DateTime? _scheduleStartDate;
  DateTime? _scheduleEndDate;
  bool _isMissed = false;

  String _formatScheduleDateTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$m $ampm';
  }

  String _formatDateTimeString(String? isoStr) {
    if (isoStr == null || isoStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return _formatScheduleDateTime(dt);
    } catch (_) {
      return isoStr;
    }
  }

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
    final isTeacher = widget.isTeacherPreview || (student?.role == 'teacher');
    if (!isTeacher) {
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
    }

    // 1. Try loading as first-class quiz from `quizzes` table
    final quizData = await DatabaseHelper().getQuizById(parsedId);
    if (quizData != null && mounted) {
      final qList = (quizData['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final tLimit = (quizData['time_limit_minutes'] as int?) ?? 0;
      _scheduleStart = quizData['schedule_start'] as String?;
      _scheduleEnd = quizData['schedule_end'] as String?;
      final dueDateStr = quizData['due_date'] as String?;

      DateTime? scheduleDate;
      if (_scheduleStart != null && _scheduleStart!.isNotEmpty) {
        try {
          scheduleDate = DateTime.parse(_scheduleStart!).toLocal();
        } catch (_) {}
      }

      DateTime? scheduleEndDate;
      if (_scheduleEnd != null && _scheduleEnd!.isNotEmpty) {
        try {
          scheduleEndDate = DateTime.parse(_scheduleEnd!).toLocal();
          if (_scheduleEnd!.length == 10 && !_scheduleEnd!.contains('T')) {
            scheduleEndDate = DateTime(scheduleEndDate.year, scheduleEndDate.month, scheduleEndDate.day, 23, 59, 59);
          }
        } catch (_) {}
      } else if (dueDateStr != null && dueDateStr.isNotEmpty) {
        try {
          final d = DateTime.parse(dueDateStr).toLocal();
          if (dueDateStr.length == 10 && !dueDateStr.contains('T')) {
            scheduleEndDate = DateTime(d.year, d.month, d.day, 23, 59, 59);
          } else {
            scheduleEndDate = d;
          }
        } catch (_) {}
      }

      // Check if student missed this quiz (past due deadline without completing)
      if (!isTeacher && scheduleEndDate != null && DateTime.now().isAfter(scheduleEndDate)) {
        await DatabaseHelper().markQuizAssignmentMissed(
          quizId: parsedId,
          studentId: studentId,
        );

        if (mounted) {
          setState(() {
            _quizId = parsedId;
            _quizData = quizData;
            _quizTitle = quizData['title']?.toString() ?? 'Assessment';
            _scheduleEndDate = scheduleEndDate;
            _isMissed = true;
            _loading = false;
          });
        }
        return;
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
        _scheduleEndDate = scheduleEndDate;
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
        if (!isTeacher) {
          final canAttemptLo = await DatabaseHelper().hasStudentCompletedLoQuiz(
            studentId: studentId,
            loId: parsedId,
          );
          if (!canAttemptLo && mounted) {
            setState(() {
              _loading = false;
              _hasAlreadyTaken = true;
            });
            return;
          }
        }
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

  /// Reset in-memory quiz state (answers, score, timer, question index)
  void _resetQuizState() {
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _currentIndex = 0;
        _selectedAnswers.clear();
        _score = 0;
        _percentage = 0.0;
        _isPassed = false;
        _startTime = null;
        _remainingSeconds = _timeLimitMinutes * 60;
        _state = 0; // return to intro
        _hasAlreadyTaken = false;
      });
    }
  }

  /// Restart preview (teacher preview only - in-memory only)
  void _restartPreview() {
    _resetQuizState();
    _loadQuiz();
  }

  Future<bool> _handlePopScope() async {
    if (_state != 1) return true;

    final isTeacher = widget.isTeacherPreview || (ref.read(authProvider)?.role == 'teacher');
    if (isTeacher) {
      _resetQuizState();
      return true;
    }

    final shouldSubmitAndExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 24),
            const SizedBox(width: 8),
            Text('Exit & Submit Quiz?', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Leaving now will automatically submit your quiz with your current answers as your final attempt. You will NOT be able to retake this quiz unless your instructor resets it.\n\nAre you sure you want to submit and exit?',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Continue Quiz', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit & Exit'),
          ),
        ],
      ),
    );

    if (shouldSubmitAndExit == true) {
      await _submitQuiz(isTimeout: false);
      return true;
    }
    return false;
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
      // If quiz window deadline has passed during active quiz, auto-submit with timeout
      if (_scheduleEndDate != null && DateTime.now().isAfter(_scheduleEndDate!)) {
        timer.cancel();
        _submitQuiz(isTimeout: true);
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
      final passed = isTimeout ? false : (pct >= _passingScore);
      final duration = _startTime != null ? DateTime.now().difference(_startTime!).inSeconds : 0;

      final isTeacher = widget.isTeacherPreview || (ref.read(authProvider)?.role == 'teacher');
      if (!isTeacher) {
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
          selectedAnswers: Map<int, String>.from(_selectedAnswers),
        );
      }

      if (mounted) {
        setState(() {
          _score = score;
          _percentage = pct;
          _isPassed = passed;
          _isTimedOut = isTimeout;
          _state = 2;
        });
      }

      if (isTimeout && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 4),
            content: const Text("Time is up! You exceeded the time limit, so the quiz is marked as failed."),
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
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoader(width: double.infinity, height: 18),
              SizedBox(height: 16),
              SkeletonCard(height: 110),
              SizedBox(height: 14),
              SkeletonCard(height: 56),
              SizedBox(height: 8),
              SkeletonCard(height: 56),
              SizedBox(height: 8),
              SkeletonCard(height: 56),
            ],
          ),
        ),
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
                      ? 'You have already completed this quiz. Only your instructor can reset this quiz if a retake is permitted.'
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

    if (_isMissed) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(_quizTitle.isNotEmpty ? _quizTitle : 'Assessment', style: TextStyle(color: AppTheme.text)),
          iconTheme: IconThemeData(color: AppTheme.text),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.event_busy, size: 64, color: AppTheme.error),
                ),
                const SizedBox(height: 20),
                Text(
                  'Quiz Missed (Past Due)',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _scheduleEndDate != null
                      ? 'This quiz closed on ${_formatScheduleDateTime(_scheduleEndDate!)}. You did not complete it within the scheduled window, so it is marked as Missed.\n\nPlease contact your instructor if you need a reset or an extension.'
                      : 'The deadline for this quiz has passed. It is marked as Missed.\n\nPlease contact your instructor if you need a reset or an extension.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.4, fontSize: 14),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Course', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

    return PopScope(
      canPop: _state != 1,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canLeave = await _handlePopScope();
        if (canLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            _quizTitle,
            style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          iconTheme: IconThemeData(color: AppTheme.text),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canLeave = await _handlePopScope();
              if (canLeave && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            if (_state == 1 && (widget.isTeacherPreview || (ref.read(authProvider)?.role == 'teacher')))
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Restart Preview',
                color: AppTheme.textSecondary,
                onPressed: _restartPreview,
              ),
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
      ),
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
                  _formatDateTimeString(_scheduleStart),
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
                  'Quiz will close at ${_formatDateTimeString(_scheduleEnd)}',
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
            if (widget.isTeacherPreview || (ref.read(authProvider)?.role == 'teacher')) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Teacher Preview Mode — Answers and scores will not be recorded in student records.',
                        style: TextStyle(fontSize: 12, color: AppTheme.text, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            if (_scheduleStart != null || _scheduleEnd != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _scheduleStart != null && _scheduleEnd != null
                            ? 'Available: ${_formatDateTimeString(_scheduleStart)} – ${_formatDateTimeString(_scheduleEnd)}'
                            : (_scheduleEnd != null
                                ? 'Available until: ${_formatDateTimeString(_scheduleEnd)}'
                                : 'Available from: ${_formatDateTimeString(_scheduleStart)}'),
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        textAlign: TextAlign.center,
                      ),
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
                  final isTeacher = widget.isTeacherPreview || (ref.read(authProvider)?.role == 'teacher');
                  if (!isTeacher && _scheduleEndDate != null && DateTime.now().isAfter(_scheduleEndDate!)) {
                    final studentId = ref.read(authProvider)?.id;
                    final targetQuizId = _quizId ?? int.tryParse(widget.quizId);
                    if (studentId != null && targetQuizId != null) {
                      DatabaseHelper().markQuizAssignmentMissed(
                        quizId: targetQuizId,
                        studentId: studentId,
                      );
                    }
                    setState(() => _isMissed = true);
                    return;
                  }
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

    final isTeacher = widget.isTeacherPreview || (ref.read(authProvider)?.role == 'teacher');

    return Column(
      children: [
        if (isTeacher)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppTheme.primary.withValues(alpha: 0.15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Teacher Preview Mode — No score will be recorded',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ],
            ),
          ),
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
            if (widget.isTeacherPreview || (ref.read(authProvider)?.role == 'teacher'))
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Teacher Preview Complete — No student scores or records were modified.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  textAlign: TextAlign.center,
                ),
              ),
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
              _isPassed
                  ? 'Congratulations! You Passed'
                  : (_isTimedOut ? 'Time Expired - Quiz Failed' : 'Assessment Not Passed'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _isPassed
                  ? 'Great job! Your score and progress have been recorded.'
                  : (_isTimedOut
                      ? 'You exceeded the time limit. This quiz has been marked as failed. You cannot retake this quiz unless your instructor resets it.'
                      : 'You scored ${_percentage.round()}%, which is below the passing mark of $_passingScore%. Your result has been submitted. You cannot retake this quiz unless your instructor resets it.'),
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
            if (widget.isTeacherPreview || (ref.read(authProvider)?.role == 'teacher')) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _restartPreview,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.text,
                    side: BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text(
                    'Restart Preview',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
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
                child: const Text('Back to Course', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
