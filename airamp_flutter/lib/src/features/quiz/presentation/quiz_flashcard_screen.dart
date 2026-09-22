import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/application/auth_provider.dart';

class QuizFlashcardScreen extends ConsumerStatefulWidget {
  final String quizTitle;
  final List<Map<String, dynamic>>? initialQuestions;
  final Map<int, String>? initialSelectedAnswers;
  final int? quizId;
  final int? loId;

  const QuizFlashcardScreen({
    super.key,
    required this.quizTitle,
    this.initialQuestions,
    this.initialSelectedAnswers,
    this.quizId,
    this.loId,
  });

  @override
  ConsumerState<QuizFlashcardScreen> createState() => _QuizFlashcardScreenState();
}

class _QuizFlashcardScreenState extends ConsumerState<QuizFlashcardScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _allQuestions = [];
  Map<int, String> _selectedAnswers = {}; // original question index -> 'A' | 'B' | ...

  // Filter: 'missed' or 'all'
  String _scope = 'all'; // will be set dynamically in initState
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isShuffled = false;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _loadData();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // 1. If questions already passed in, use them
    if (widget.initialQuestions != null && widget.initialQuestions!.isNotEmpty) {
      _allQuestions = List<Map<String, dynamic>>.from(widget.initialQuestions!);
      if (widget.initialSelectedAnswers != null) {
        _selectedAnswers = Map<int, String>.from(widget.initialSelectedAnswers!);
      }
      _decideInitialScopeAndFinishLoading();
      return;
    }

    // 2. Otherwise load offline from SQLite
    try {
      final dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> questions = [];

      if (widget.quizId != null && widget.quizId! > 0) {
        final quizData = await dbHelper.getQuizById(widget.quizId!);
        if (quizData != null) {
          questions = (quizData['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        }
      } else if (widget.loId != null && widget.loId! > 0) {
        final loData = await dbHelper.getLoQuiz(widget.loId!);
        if (loData != null) {
          questions = (loData['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        }
      }

      _allQuestions = questions;

      // Try loading past attempt answers for this student
      final user = ref.read(authProvider);
      if (user != null) {
        final attempt = await dbHelper.getQuizAttemptWithAnswers(
          studentId: user.id,
          quizId: widget.quizId,
          loId: widget.loId,
        );

        if (attempt != null && attempt['answers'] != null) {
          try {
            final rawMap = jsonDecode(attempt['answers'] as String) as Map<String, dynamic>;
            _selectedAnswers = rawMap.map((k, v) => MapEntry(int.parse(k), v.toString()));
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error loading flashcard data: $e');
    }

    _decideInitialScopeAndFinishLoading();
  }

  void _decideInitialScopeAndFinishLoading() {
    // If student has missed questions, default to 'missed' for targeted review!
    final missedCount = _calculateMissedCount();
    final defaultScope = (missedCount > 0 && _selectedAnswers.isNotEmpty) ? 'missed' : 'all';

    if (mounted) {
      setState(() {
        _scope = defaultScope;
        _loading = false;
      });
    }
  }

  int _calculateMissedCount() {
    int missed = 0;
    for (int i = 0; i < _allQuestions.length; i++) {
      final q = _allQuestions[i];
      final correct = (q['correct_option']?.toString() ?? 'A').toUpperCase().trim();
      final selected = _selectedAnswers[i]?.toUpperCase().trim();
      if (selected != null && selected != correct) {
        missed++;
      }
    }
    return missed;
  }

  /// Filtered deck based on current scope: returns List of Pair (originalIndex, questionMap)
  List<MapEntry<int, Map<String, dynamic>>> get _filteredDeck {
    final list = <MapEntry<int, Map<String, dynamic>>>[];
    for (int i = 0; i < _allQuestions.length; i++) {
      final q = _allQuestions[i];
      final correct = (q['correct_option']?.toString() ?? 'A').toUpperCase().trim();
      final selected = _selectedAnswers[i]?.toUpperCase().trim();

      if (_scope == 'missed') {
        if (selected != null && selected != correct) {
          list.add(MapEntry(i, q));
        }
      } else {
        list.add(MapEntry(i, q));
      }
    }

    if (_isShuffled) {
      // Return a deterministically shuffled view using card seed
      final shuffled = List<MapEntry<int, Map<String, dynamic>>>.from(list);
      shuffled.shuffle(Random(42));
      return shuffled;
    }
    return list;
  }

  void _toggleFlip() {
    if (_flipController.isAnimating) return;
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  void _goToNextCard(int totalCards) {
    if (_currentIndex < totalCards - 1) {
      _resetFlip();
      setState(() => _currentIndex++);
    } else {
      _showCompletedDialog();
    }
  }

  void _goToPreviousCard() {
    if (_currentIndex > 0) {
      _resetFlip();
      setState(() => _currentIndex--);
    }
  }

  void _resetFlip() {
    _flipController.reset();
    _isFlipped = false;
  }

  void _switchScope(String newScope) {
    if (_scope == newScope) return;
    _resetFlip();
    setState(() {
      _scope = newScope;
      _currentIndex = 0;
    });
  }

  void _toggleShuffle() {
    _resetFlip();
    setState(() {
      _isShuffled = !_isShuffled;
      _currentIndex = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        backgroundColor: AppTheme.surfaceElevated,
        content: Text(
          _isShuffled ? 'Card deck shuffled!' : 'Standard question order restored',
          style: TextStyle(color: AppTheme.text),
        ),
      ),
    );
  }

  void _showCompletedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.emoji_events_outlined, color: AppTheme.primary, size: 28),
            const SizedBox(width: 10),
            Text('Deck Completed!', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          _scope == 'missed'
              ? 'You have reviewed all your missed questions. Great job targeting your weak spots!'
              : 'You have reviewed all the flashcards in this quiz.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetFlip();
              setState(() => _currentIndex = 0);
            },
            child: Text('Review Again', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);

    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          title: Text(widget.quizTitle, style: TextStyle(color: AppTheme.text, fontSize: 16)),
          iconTheme: IconThemeData(color: AppTheme.text),
        ),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final deck = _filteredDeck;
    final totalCards = deck.length;
    final missedCount = _calculateMissedCount();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.text),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.quizTitle,
              style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Flashcard Review Mode',
              style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isShuffled ? 'Unshuffle cards' : 'Shuffle cards',
            icon: Icon(
              Icons.shuffle,
              color: _isShuffled ? AppTheme.primary : AppTheme.textMuted,
            ),
            onPressed: totalCards > 1 ? _toggleShuffle : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Scope Filter Control ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchScope('all'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _scope == 'all' ? AppTheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'All Questions (${_allQuestions.length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _scope == 'all' ? Colors.black : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchScope('missed'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _scope == 'missed' ? AppTheme.error : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Missed Only ($missedCount)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _scope == 'missed' ? Colors.white : AppTheme.textSecondary,
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
            ),

            // ── Progress Bar & Indicator ─────────────────────
            if (totalCards > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Card ${_currentIndex + 1} of $totalCards',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        Text(
                          '${(((_currentIndex + 1) / totalCards) * 100).round()}%',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / totalCards,
                        backgroundColor: AppTheme.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _scope == 'missed' ? AppTheme.error : AppTheme.primary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Main Card Area with Flip Animation ───────────
            Expanded(
              child: totalCards == 0
                  ? _buildEmptyState()
                  : Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: GestureDetector(
                        onTap: _toggleFlip,
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity != null) {
                            if (details.primaryVelocity! < -200) {
                              _goToNextCard(totalCards);
                            } else if (details.primaryVelocity! > 200) {
                              _goToPreviousCard();
                            }
                          }
                        },
                        child: AnimatedBuilder(
                          animation: _flipAnimation,
                          builder: (context, child) {
                            final angle = _flipAnimation.value * pi;
                            final isUnder = angle > (pi / 2);

                            final activeEntry = deck[_currentIndex];
                            final origIndex = activeEntry.key;
                            final q = activeEntry.value;

                            return Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0015) // 3D perspective
                                ..rotateY(angle),
                              alignment: Alignment.center,
                              child: isUnder
                                  ? Transform(
                                      transform: Matrix4.identity()..rotateY(pi),
                                      alignment: Alignment.center,
                                      child: _buildCardBack(q, origIndex, _currentIndex, totalCards),
                                    )
                                  : _buildCardFront(q, origIndex, _currentIndex, totalCards),
                            );
                          },
                        ),
                      ),
                    ),
            ),

            // ── Bottom Controls ──────────────────────────────
            if (totalCards > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    // Previous
                    OutlinedButton.icon(
                      onPressed: _currentIndex > 0 ? _goToPreviousCard : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.text,
                        side: BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.arrow_back_ios, size: 14),
                      label: const Text('Prev'),
                    ),
                    const SizedBox(width: 8),

                    // Flip Card
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _toggleFlip,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.flip, size: 16),
                        label: Text(
                          _isFlipped ? 'Show Question' : 'Reveal Answer',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Next / Complete
                    ElevatedButton.icon(
                      onPressed: () => _goToNextCard(totalCards),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(
                        _currentIndex == totalCards - 1 ? Icons.check : Icons.arrow_forward_ios,
                        size: 14,
                      ),
                      label: Text(
                        _currentIndex == totalCards - 1 ? 'Finish' : 'Next',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Card Front (Question & Options) ─────────────────────────
  Widget _buildCardFront(Map<String, dynamic> q, int origIndex, int cardIdx, int totalCards) {
    final correct = (q['correct_option']?.toString() ?? 'A').toUpperCase().trim();
    final selected = _selectedAnswers[origIndex]?.toUpperCase().trim();
    final hasAnswered = selected != null;
    final isCorrect = hasAnswered && (selected == correct);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasAnswered
              ? (isCorrect ? AppTheme.success.withValues(alpha: 0.5) : AppTheme.error.withValues(alpha: 0.5))
              : AppTheme.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Q${origIndex + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasAnswered)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? AppTheme.success.withValues(alpha: 0.15)
                            : AppTheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            size: 13,
                            color: isCorrect ? AppTheme.success : AppTheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCorrect ? 'Correct' : 'Missed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCorrect ? AppTheme.success : AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Icon(Icons.touch_app_outlined, size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to Flip',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // Question & Options Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q['question_text']?.toString() ?? 'Question',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Choices:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    _buildOptionChoice('A', q['option_a']?.toString() ?? ''),
                    _buildOptionChoice('B', q['option_b']?.toString() ?? ''),
                    if ((q['option_c']?.toString() ?? '').isNotEmpty)
                      _buildOptionChoice('C', q['option_c']?.toString() ?? ''),
                    if ((q['option_d']?.toString() ?? '').isNotEmpty)
                      _buildOptionChoice('D', q['option_d']?.toString() ?? ''),
                  ],
                ),
              ),
            ),

            // Footer prompt
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rotate_right, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Tap anywhere to reveal correct answer',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionChoice(String letter, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.background,
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card Back (Revealed Answer & Comparison) ────────────────
  Widget _buildCardBack(Map<String, dynamic> q, int origIndex, int cardIdx, int totalCards) {
    final correct = (q['correct_option']?.toString() ?? 'A').toUpperCase().trim();
    final selected = _selectedAnswers[origIndex]?.toUpperCase().trim();
    final hasAnswered = selected != null;
    final isCorrect = hasAnswered && (selected == correct);
    final correctText = q['option_${correct.toLowerCase()}']?.toString() ?? '';
    final selectedText = (selected != null) ? (q['option_${selected.toLowerCase()}']?.toString() ?? '') : '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                border: Border(bottom: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Answer Key · Question ${origIndex + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.flip_to_back, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to Flip Back',
                    style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // Answer Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question summary
                    Text(
                      q['question_text']?.toString() ?? 'Question',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Highlighted Correct Answer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.success, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.success,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, size: 16, color: Colors.black),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Correct Answer: Option $correct',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.success,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            correctText,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Student Attempt Summary
                    if (hasAnswered) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? AppTheme.success.withValues(alpha: 0.08)
                              : AppTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCorrect
                                ? AppTheme.success.withValues(alpha: 0.3)
                                : AppTheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isCorrect ? Icons.check_circle : Icons.cancel,
                                  size: 16,
                                  color: isCorrect ? AppTheme.success : AppTheme.error,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isCorrect ? 'You answered correctly!' : 'Your answer was incorrect',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isCorrect ? AppTheme.success : AppTheme.error,
                                  ),
                                ),
                              ],
                            ),
                            if (!isCorrect) ...[
                              const SizedBox(height: 6),
                              Text(
                                'You selected: Option $selected ($selectedText)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // All Options Reference
                    Text(
                      'All Options Reference:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    _buildOptionKey('A', q['option_a']?.toString() ?? '', correct == 'A', selected == 'A'),
                    _buildOptionKey('B', q['option_b']?.toString() ?? '', correct == 'B', selected == 'B'),
                    if ((q['option_c']?.toString() ?? '').isNotEmpty)
                      _buildOptionKey('C', q['option_c']?.toString() ?? '', correct == 'C', selected == 'C'),
                    if ((q['option_d']?.toString() ?? '').isNotEmpty)
                      _buildOptionKey('D', q['option_d']?.toString() ?? '', correct == 'D', selected == 'D'),
                  ],
                ),
              ),
            ),

            // Footer prompt
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flip_to_front, size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Tap anywhere to flip back to question',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionKey(String letter, String text, bool isCorrect, bool isSelected) {
    if (text.isEmpty) return const SizedBox.shrink();

    Color borderColor = AppTheme.border;
    Color bgColor = AppTheme.surfaceLight;
    if (isCorrect) {
      borderColor = AppTheme.success;
      bgColor = AppTheme.success.withValues(alpha: 0.1);
    } else if (isSelected) {
      borderColor = AppTheme.error;
      bgColor = AppTheme.error.withValues(alpha: 0.1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCorrect ? AppTheme.success : (isSelected ? AppTheme.error : AppTheme.background),
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isCorrect || isSelected ? Colors.black : AppTheme.text,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                color: isCorrect ? AppTheme.success : AppTheme.textSecondary,
              ),
            ),
          ),
          if (isCorrect)
            Icon(Icons.check, size: 16, color: AppTheme.success)
          else if (isSelected)
            Icon(Icons.close, size: 16, color: AppTheme.error),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration_outlined, size: 64, color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(
              'No Missed Questions!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
            const SizedBox(height: 8),
            Text(
              'You answered every question correctly on this assessment! Switch to "All Questions" to review the entire quiz deck.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _switchScope('all'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.style, size: 16),
              label: const Text('View All Questions', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
