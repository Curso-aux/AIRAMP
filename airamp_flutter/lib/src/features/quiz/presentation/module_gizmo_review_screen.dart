import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../data/module_review_provider.dart';

/// Gizmo-style interactive review screen for module learning outcomes.
/// Features high-impact 3D active-recall flashcards, self-grading spaced repetition,
/// gamified practice quizzes with lifelines (50:50, smart hints, read-aloud),
/// streak tracking, live accuracy statistics, and star bookmarking.
class ModuleGizmoReviewScreen extends ConsumerStatefulWidget {
  final int loId;
  final String? initialModuleTitle;
  final String? initialSubjectName;
  final String initialMode;

  const ModuleGizmoReviewScreen({
    super.key,
    required this.loId,
    this.initialModuleTitle,
    this.initialSubjectName,
    this.initialMode = 'quiz',
  });

  @override
  ConsumerState<ModuleGizmoReviewScreen> createState() => _ModuleGizmoReviewScreenState();
}

class _ModuleGizmoReviewScreenState extends ConsumerState<ModuleGizmoReviewScreen>
    with SingleTickerProviderStateMixin {
  // Mode: 'quiz' | 'flashcard'
  late String _activeMode;

  // Filter Scope: 'all' | 'weak' | 'mastered' | 'starred'
  String _scope = 'all';

  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isShuffled = false;
  int _streak = 0;
  int _bestStreak = 0;

  // Gamification & Features
  final Map<int, String> _quizUserSelections = {}; // cardIdx -> 'A' | 'B' | 'C' | 'D'
  final Set<int> _starredCardIds = {};             // Card IDs bookmarked for review
  final Map<int, Set<String>> _eliminatedOptions = {}; // 50:50 per cardIdx -> {'B', 'D'}
  final Set<int> _revealedHints = {};              // cardIdx -> hint shown
  int? _speakingCardIndex;                        // cardIdx currently being read aloud

  // Timer Feature
  Timer? _sessionTimer;
  int _secondsElapsed = 0;
  bool _timerActive = true;

  // 3D Flip Animation
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.initialMode;
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    _startTimer();

    Future.microtask(() {
      ref.read(moduleReviewProvider.notifier).loadDeck(widget.loId);
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _flipController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerActive && mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _toggleFlip() {
    if (_flipController.isAnimating) return;
    HapticFeedback.lightImpact();
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  void _resetFlip() {
    _flipController.reset();
    _isFlipped = false;
  }

  void _goToNextCard(int totalCards) {
    HapticFeedback.selectionClick();
    if (_currentIndex < totalCards - 1) {
      _resetFlip();
      setState(() => _currentIndex++);
    } else {
      _showMasterySummaryDialog();
    }
  }

  void _goToPreviousCard() {
    HapticFeedback.selectionClick();
    if (_currentIndex > 0) {
      _resetFlip();
      setState(() => _currentIndex--);
    }
  }

  void _toggleStarred(int? cardId) {
    if (cardId == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      if (_starredCardIds.contains(cardId)) {
        _starredCardIds.remove(cardId);
      } else {
        _starredCardIds.add(cardId);
      }
    });
  }

  void _use5050Lifeline(int cardIdx, String correctOpt, List<String> options) {
    if (_eliminatedOptions.containsKey(cardIdx)) return;
    HapticFeedback.mediumImpact();

    final wrongLetters = options
        .map((opt) => opt.length >= 2 && opt[1] == ':' ? opt[0].toUpperCase() : '')
        .where((letter) => letter.isNotEmpty && letter != correctOpt.toUpperCase())
        .toList();

    wrongLetters.shuffle(Random());
    final toEliminate = wrongLetters.take(2).toSet();

    setState(() {
      _eliminatedOptions[cardIdx] = toEliminate;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bolt, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Text(
              '50:50 Used: Eliminated choices ${toEliminate.join(' & ')}!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.grey.shade900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleHint(int cardIdx) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_revealedHints.contains(cardIdx)) {
        _revealedHints.remove(cardIdx);
      } else {
        _revealedHints.add(cardIdx);
      }
    });
  }

  void _simulateReadAloud(int cardIdx) {
    HapticFeedback.lightImpact();
    setState(() {
      _speakingCardIndex = cardIdx;
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _speakingCardIndex == cardIdx) {
        setState(() => _speakingCardIndex = null);
      }
    });
  }

  void _markCardConfidence({
    required Map<String, dynamic> card,
    required bool gotIt,
    required int totalCards,
  }) {
    if (gotIt) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }

    final cardId = card['id'] as int?;
    if (cardId != null) {
      ref.read(moduleReviewProvider.notifier).updateCardMastery(cardId, gotIt);
    }

    setState(() {
      if (gotIt) {
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;
      } else {
        _streak = 0;
      }
    });

    _goToNextCard(totalCards);
  }

  void _handleQuizOptionSelect(int cardIndex, String optionLetter, String correctOption, int totalCards) {
    if (_quizUserSelections.containsKey(cardIndex)) return; // Already answered

    final isCorrect = optionLetter.toUpperCase() == correctOption.toUpperCase();

    if (isCorrect) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    setState(() {
      _quizUserSelections[cardIndex] = optionLetter;
      if (isCorrect) {
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;
      } else {
        _streak = 0;
      }
    });

    final deck = _getFilteredDeck(ref.read(moduleReviewProvider).cards);
    if (cardIndex < deck.length) {
      final cardId = deck[cardIndex]['id'] as int?;
      if (cardId != null) {
        ref.read(moduleReviewProvider.notifier).updateCardMastery(cardId, isCorrect);
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredDeck(List<Map<String, dynamic>> allCards) {
    List<Map<String, dynamic>> filtered = [];
    if (_scope == 'weak') {
      filtered = allCards.where((c) => c['is_mastered'] != 1 && c['is_mastered'] != true).toList();
    } else if (_scope == 'mastered') {
      filtered = allCards.where((c) => c['is_mastered'] == 1 || c['is_mastered'] == true).toList();
    } else if (_scope == 'starred') {
      filtered = allCards.where((c) => _starredCardIds.contains(c['id'])).toList();
    } else {
      filtered = List.from(allCards);
    }

    if (_isShuffled) {
      return List.from(filtered)..shuffle(Random(42));
    }
    return filtered;
  }

  void _showMasterySummaryDialog() {
    final deckState = ref.read(moduleReviewProvider);
    final total = deckState.cards.length;
    final mastered = deckState.masteredCount;
    final pct = total > 0 ? ((mastered / total) * 100).round() : 100;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Grade tier badge
    String gradeBadge = 'S';
    Color gradeColor = const Color(0xFFF59E0B);
    if (pct < 60) {
      gradeBadge = 'C';
      gradeColor = AppTheme.error;
    } else if (pct < 80) {
      gradeBadge = 'B';
      gradeColor = AppTheme.accent;
    } else if (pct < 95) {
      gradeBadge = 'A';
      gradeColor = AppTheme.primary;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration Icon & Badge
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.2),
                          AppTheme.accent.withValues(alpha: 0.1),
                        ],
                      ),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.6), width: 3),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: AppTheme.text)),
                        Text('Mastery', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: gradeColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: gradeColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Tier $gradeBadge 🏆',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Session Complete! 🎉',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.text),
              ),
              const SizedBox(height: 4),
              Text(
                'Gizmo Spaced Repetition Mastery Report',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),

              // Statistics Grid
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem('Mastered', '$mastered', AppTheme.success, Icons.check_circle_rounded),
                    Container(width: 1, height: 32, color: AppTheme.border),
                    _buildStatItem('Needs Drill', '${total - mastered}', const Color(0xFFF59E0B), Icons.replay_rounded),
                    Container(width: 1, height: 32, color: AppTheme.border),
                    _buildStatItem('Best Streak', '🔥 $_bestStreak', const Color(0xFFFF8C42), null),
                    Container(width: 1, height: 32, color: AppTheme.border),
                    _buildStatItem('Time', _formatDuration(_secondsElapsed), AppTheme.accent, Icons.timer_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                pct >= 80
                    ? 'Outstanding performance! You have reinforced this module\'s critical concepts with flying colors.'
                    : 'Solid practice! Repeat the weak cards or review your starred questions to reach complete mastery.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.45),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (total - mastered > 0) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.fitness_center_rounded, size: 18),
                    label: Text('Drill Weak Cards (${total - mastered})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _resetFlip();
                      setState(() {
                        _scope = 'weak';
                        _currentIndex = 0;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                if (_starredCardIds.isNotEmpty) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
                    label: Text('Review Starred (${_starredCardIds.length})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.text,
                      side: BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _resetFlip();
                      setState(() {
                        _scope = 'starred';
                        _currentIndex = 0;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _resetFlip();
                          setState(() {
                            _scope = 'all';
                            _currentIndex = 0;
                            _quizUserSelections.clear();
                            _eliminatedOptions.clear();
                            _revealedHints.clear();
                            _streak = 0;
                          });
                        },
                        label: const Text('Restart All'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData? icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
            ],
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _showStudyGuideModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lightbulb_rounded, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gizmo Review Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.text)),
                          Text('Power up your study efficiency', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildGuideRow(Icons.quiz_rounded, AppTheme.accent, 'Practice Quiz', 'Interactive multiple choice questions with instant explanations & XP.'),
                const SizedBox(height: 12),
                _buildGuideRow(Icons.style_rounded, AppTheme.primary, '3D Flashcards', 'Tap to flip, test your recall, and self-grade with spaced repetition.'),
                const SizedBox(height: 12),
                _buildGuideRow(Icons.bolt_rounded, const Color(0xFFF59E0B), '50:50 Lifeline', 'Eliminate 2 wrong answers on tricky questions so you can focus.'),
                const SizedBox(height: 12),
                _buildGuideRow(Icons.star_rounded, const Color(0xFFF59E0B), 'Star Questions', 'Bookmark high-priority concepts and drill them separately anytime.'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Got It!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideRow(IconData icon, Color color, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.text)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final deckState = ref.watch(moduleReviewProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (deckState.isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          leading: BackButton(color: AppTheme.text),
          title: Text('Scanning Module...', style: TextStyle(color: AppTheme.text, fontSize: 16)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.25),
                      AppTheme.accent.withValues(alpha: 0.15),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 2),
                ),
                child: Icon(Icons.psychology_rounded, size: 44, color: AppTheme.primary),
              ),
              const SizedBox(height: 24),
              CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
              const SizedBox(height: 18),
              Text(
                'AI Module Scanner Active',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Extracting key competencies, definitions & practice quizzes...',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final module = deckState.moduleData;
    final moduleTitle = module?['title']?.toString() ?? widget.initialModuleTitle ?? 'Module Review';
    final subjectCode = module?['subject_code']?.toString() ?? '';
    final deck = _getFilteredDeck(deckState.cards);
    final totalCards = deck.length;

    // Guard index
    if (_currentIndex >= totalCards && totalCards > 0) {
      _currentIndex = totalCards - 1;
    }

    final currentCard = deck.isNotEmpty ? deck[_currentIndex] : <String, dynamic>{};
    final currentCardId = currentCard['id'] as int?;
    final isStarred = currentCardId != null && _starredCardIds.contains(currentCardId);

    // Live session stats
    final answeredCount = _quizUserSelections.length;
    int correctCount = 0;
    _quizUserSelections.forEach((idx, opt) {
      if (idx < deck.length) {
        final card = deck[idx];
        final cor = (card['correct_option']?.toString() ?? 'A').toUpperCase().trim();
        if (opt.toUpperCase() == cor) correctCount++;
      }
    });
    final accuracyPct = answeredCount > 0 ? ((correctCount / answeredCount) * 100).round() : 100;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: BackButton(color: AppTheme.text),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (subjectCode.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      subjectCode,
                      style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    moduleTitle,
                    style: TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: 13, color: AppTheme.primary),
                const SizedBox(width: 3),
                Text(
                  'Gizmo Active Review',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                if (_streak >= 2) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF8C42), Color(0xFFF59E0B)]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF8C42).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 2),
                        Text(
                          '$_streak Streak',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          // Timer badge
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _timerActive = !_timerActive);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceLight : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _timerActive ? AppTheme.border.withValues(alpha: 0.7) : AppTheme.warning,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _timerActive ? Icons.timer_outlined : Icons.pause_circle_outline_rounded,
                    size: 13,
                    color: _timerActive ? AppTheme.textSecondary : AppTheme.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(_secondsElapsed),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _timerActive ? AppTheme.textSecondary : AppTheme.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: _isShuffled ? 'Restore Card Order' : 'Shuffle Cards',
            icon: Icon(
              Icons.shuffle_rounded,
              color: _isShuffled ? AppTheme.primary : AppTheme.textMuted,
              size: 20,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _resetFlip();
              setState(() {
                _isShuffled = !_isShuffled;
                _currentIndex = 0;
              });
            },
          ),
          IconButton(
            tooltip: 'Study Guide & Tips',
            icon: Icon(Icons.help_outline_rounded, color: AppTheme.textMuted, size: 20),
            onPressed: _showStudyGuideModal,
          ),
          IconButton(
            tooltip: 'Rescan Module',
            icon: Icon(Icons.refresh_rounded, color: AppTheme.textMuted, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(moduleReviewProvider.notifier).refreshDeck();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Mode Switcher (Practice Quiz vs Flashcards) ─────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeTab(
                        title: 'Practice Quiz',
                        subtitle: 'Interactive test',
                        icon: Icons.quiz_rounded,
                        isActive: _activeMode == 'quiz',
                        badgeText: '${deckState.cards.length}',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _activeMode = 'quiz');
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildModeTab(
                        title: 'Flashcards',
                        subtitle: '3D Active recall',
                        icon: Icons.style_rounded,
                        isActive: _activeMode == 'flashcard',
                        badgeText: '${deckState.cards.length}',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _resetFlip();
                          setState(() => _activeMode = 'flashcard');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Scope Filter Chips ────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildScopeBadge('all', 'All (${deckState.cards.length})', Icons.layers_outlined, AppTheme.primary),
                  const SizedBox(width: 8),
                  _buildScopeBadge('weak', 'Needs Review (${deckState.weakCount})', Icons.replay_rounded, const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _buildScopeBadge('mastered', 'Mastered (${deckState.masteredCount})', Icons.verified_rounded, AppTheme.success),
                  const SizedBox(width: 8),
                  _buildScopeBadge('starred', 'Starred (${_starredCardIds.length})', Icons.star_rounded, const Color(0xFFF59E0B)),
                ],
              ),
            ),

            // ── Live Progress & Stats Header Bar ──────────────────
            if (totalCards > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              _activeMode == 'quiz'
                                  ? 'Question ${_currentIndex + 1} of $totalCards'
                                  : 'Card ${_currentIndex + 1} of $totalCards',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (_activeMode == 'quiz' && answeredCount > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.track_changes_rounded, size: 12, color: AppTheme.primary),
                                    const SizedBox(width: 3),
                                    Text('$accuracyPct% Acc', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('+${correctCount * 10} XP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: totalCards > 0 ? (_currentIndex + 1) / totalCards : 0,
                        backgroundColor: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFE2E8F0),
                        color: AppTheme.primary,
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Main Card Area (Quiz vs Flashcards) ─────────────────
            Expanded(
              child: totalCards == 0
                  ? _buildEmptyState()
                  : GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! < -300) {
                            // Swipe Left -> Next
                            _goToNextCard(totalCards);
                          } else if (details.primaryVelocity! > 300) {
                            // Swipe Right -> Previous
                            _goToPreviousCard();
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _activeMode == 'flashcard'
                              ? _build3DFlipCard(deck[_currentIndex], _currentIndex, totalCards, isStarred)
                              : _buildPracticeQuizCard(deck[_currentIndex], _currentIndex, totalCards, isStarred),
                        ),
                      ),
                    ),
            ),

            // ── Sticky Bottom Action Controls ──────────────────────
            if (totalCards > 0)
              _buildBottomControls(deck.isNotEmpty ? deck[_currentIndex] : {}, totalCards),
          ],
        ),
      ),
    );
  }

  // ── Segmented Mode Tab ──────────────────────────────────────
  Widget _buildModeTab({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? AppTheme.darkSurfaceLight : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
          border: isActive
              ? Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isActive ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppTheme.text : AppTheme.textSecondary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9,
                    color: isActive ? AppTheme.primary : AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter Badge Pill ────────────────────────────────────────
  Widget _buildScopeBadge(String scopeVal, String label, IconData icon, Color color) {
    final isSelected = _scope == scopeVal;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _resetFlip();
        setState(() {
          _scope = scopeVal;
          _currentIndex = 0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : (isDark ? AppTheme.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppTheme.border.withValues(alpha: 0.8),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? color : AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3D Flashcard Renderer ─────────────────────────────────────
  Widget _build3DFlipCard(Map<String, dynamic> card, int cardIdx, int totalCards, bool isStarred) {
    return GestureDetector(
      onTap: _toggleFlip,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * pi;
          final isFront = angle <= (pi / 2);

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isFront
                ? _buildCardFront(card, cardIdx, totalCards, isStarred)
                : Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildCardBack(card, cardIdx, totalCards, isStarred),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardFront(Map<String, dynamic> card, int cardIdx, int totalCards, bool isStarred) {
    final type = card['card_type']?.toString() ?? 'concept';
    final frontText = card['front_text']?.toString() ?? '';
    final sourceSnippet = card['source_snippet']?.toString() ?? 'Module Concept';
    final isMastered = card['is_mastered'] == 1 || card['is_mastered'] == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardId = card['id'] as int?;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isMastered ? AppTheme.success.withValues(alpha: 0.5) : AppTheme.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.7))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.style_rounded, size: 13, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          type.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isMastered)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 12, color: AppTheme.success),
                          const SizedBox(width: 3),
                          Text('Mastered', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.success)),
                        ],
                      ),
                    ),
                  const Spacer(),
                  // Read Aloud simulation
                  IconButton(
                    icon: Icon(
                      _speakingCardIndex == cardIdx ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
                      size: 18,
                      color: _speakingCardIndex == cardIdx ? AppTheme.primary : AppTheme.textMuted,
                    ),
                    onPressed: () => _simulateReadAloud(cardIdx),
                    tooltip: 'Listen to Concept',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  // Bookmark Star
                  IconButton(
                    icon: Icon(
                      isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 20,
                      color: isStarred ? const Color(0xFFF59E0B) : AppTheme.textMuted,
                    ),
                    onPressed: () => _toggleStarred(cardId),
                    tooltip: isStarred ? 'Remove Star' : 'Star Card',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // Card Front Question Body
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.psychology_rounded, color: AppTheme.primary, size: 28),
                      ),
                      const SizedBox(height: 18),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _speakingCardIndex == cardIdx ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          frontText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Tap card to reveal answer',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Card Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded, size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Source: $sourceSnippet',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildCardBack(Map<String, dynamic> card, int cardIdx, int totalCards, bool isStarred) {
    final backText = card['back_text']?.toString() ?? '';
    final explanation = card['explanation']?.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardId = card['id'] as int?;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.7))),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Answer & Core Concept',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 20,
                      color: isStarred ? const Color(0xFFF59E0B) : AppTheme.textMuted,
                    ),
                    onPressed: () => _toggleStarred(cardId),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.flip_rounded, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text('Flip', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),

            // Back Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      backText,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text, height: 1.45),
                    ),
                    if (explanation != null && explanation.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                explanation,
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Self-Assessment Prompt Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: AppTheme.border.withValues(alpha: 0.6))),
              ),
              child: Row(
                children: [
                  Icon(Icons.psychology_outlined, size: 15, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Did you recall this correctly?',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Practice Mini-Quiz Renderer ──────────────────────────────
  Widget _buildPracticeQuizCard(Map<String, dynamic> card, int cardIdx, int totalCards, bool isStarred) {
    final frontText = card['front_text']?.toString() ?? '';
    final explanation = card['explanation']?.toString();
    final userSelection = _quizUserSelections[cardIdx];
    final hasAnswered = userSelection != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardId = card['id'] as int?;

    List<String> options = [];
    if (card['options_json'] != null) {
      try {
        final decoded = jsonDecode(card['options_json'] as String);
        if (decoded is List && decoded.isNotEmpty) {
          options = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    String correctOpt = (card['correct_option']?.toString() ?? '').toUpperCase().trim();

    // Fallback: If options empty, generate distractors
    if (options.isEmpty) {
      final back = card['back_text']?.toString().trim() ?? 'Correct Answer';
      final distractors = [
        'Fundamental Module Standard',
        'Lifecycle State Protocol',
        'System Architecture Configuration',
      ];
      final pool = [back, ...distractors]..shuffle(Random(card['id'] as int? ?? cardIdx));
      final cIdx = pool.indexOf(back);
      correctOpt = String.fromCharCode(65 + (cIdx >= 0 ? cIdx : 0));
      options = pool.asMap().entries.map((e) => '${String.fromCharCode(65 + e.key)}: ${e.value}').toList();
    } else if (correctOpt.isEmpty || correctOpt.length > 1) {
      correctOpt = 'A';
    }

    final eliminated = _eliminatedOptions[cardIdx] ?? <String>{};
    final isHintShown = _revealedHints.contains(cardIdx);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasAnswered
              ? (userSelection == correctOpt
                  ? AppTheme.success.withValues(alpha: 0.6)
                  : AppTheme.error.withValues(alpha: 0.5))
              : AppTheme.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Bar ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.7))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.quiz_rounded, size: 14, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Text(
                          'PRACTICE QUIZ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_streak > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 3),
                          Text(
                            '$_streak Streak!',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  // Read Aloud
                  IconButton(
                    icon: Icon(
                      _speakingCardIndex == cardIdx ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
                      size: 18,
                      color: _speakingCardIndex == cardIdx ? AppTheme.primary : AppTheme.textMuted,
                    ),
                    onPressed: () => _simulateReadAloud(cardIdx),
                    tooltip: 'Listen to Question',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  // Star / Bookmark
                  IconButton(
                    icon: Icon(
                      isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 20,
                      color: isStarred ? const Color(0xFFF59E0B) : AppTheme.textMuted,
                    ),
                    onPressed: () => _toggleStarred(cardId),
                    tooltip: isStarred ? 'Remove Star' : 'Star Question',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // ── Lifelines & Power-Ups Bar (Hint & 50:50) ─────────────
            if (!hasAnswered)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceLight.withValues(alpha: 0.4) : const Color(0xFFF1F5F9),
                  border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
                ),
                child: Row(
                  children: [
                    Text(
                      'Study Tools:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    // 50:50 Button
                    InkWell(
                      onTap: eliminated.isEmpty
                          ? () => _use5050Lifeline(cardIdx, correctOpt, options)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: eliminated.isEmpty
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: eliminated.isEmpty
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                                : Colors.grey.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 13,
                              color: eliminated.isEmpty ? const Color(0xFFF59E0B) : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              eliminated.isEmpty ? '50:50' : '50:50 Used',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: eliminated.isEmpty ? const Color(0xFFF59E0B) : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Hint Button
                    InkWell(
                      onTap: () => _toggleHint(cardIdx),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isHintShown
                              ? AppTheme.accent.withValues(alpha: 0.25)
                              : AppTheme.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isHintShown ? AppTheme.accent : AppTheme.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, size: 13, color: AppTheme.accent),
                            const SizedBox(width: 3),
                            Text(
                              isHintShown ? 'Hide Hint' : 'Hint',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Question text & Options ─────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Highlighted Question Text
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _speakingCardIndex == cardIdx
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        frontText,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasAnswered
                          ? 'Review the outcome and detailed takeaway below:'
                          : 'Select the best option from the choices below:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),

                    // Expandable Hint Box
                    if (isHintShown && !hasAnswered) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_rounded, size: 16, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                card['source_snippet'] != null && card['source_snippet'].toString().isNotEmpty
                                    ? 'Hint: This concept relates to ${card['source_snippet']}. Look for terms representing immutability or non-reassignment.'
                                    : 'Hint: Think carefully about variables that cannot be reassigned after declaration.',
                                style: TextStyle(fontSize: 12, color: AppTheme.text, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Options List
                    ...options.map((opt) {
                      final optLetter = opt.length >= 2 && opt[1] == ':' ? opt[0].toUpperCase() : 'A';
                      final isSelected = userSelection == optLetter;
                      final isTheCorrectAnswer = optLetter == correctOpt;
                      final isEliminated = eliminated.contains(optLetter);

                      // Distinct letter accent color
                      Color letterAccent = const Color(0xFF4F46E5); // A
                      if (optLetter == 'B') letterAccent = const Color(0xFF0D9488);
                      if (optLetter == 'C') letterAccent = const Color(0xFF7C3AED);
                      if (optLetter == 'D') letterAccent = const Color(0xFFD97706);

                      Color btnBg = isDark ? AppTheme.darkSurfaceElevated : Colors.white;
                      Color btnBorder = AppTheme.border;
                      Color textColor = AppTheme.text;
                      Widget? trailingBadge;

                      if (isEliminated) {
                        btnBg = isDark ? AppTheme.darkSurface.withValues(alpha: 0.4) : const Color(0xFFF1F5F9);
                        textColor = AppTheme.textMuted;
                        trailingBadge = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ELIMINATED',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                          ),
                        );
                      } else if (hasAnswered) {
                        if (isTheCorrectAnswer) {
                          btnBg = isDark ? const Color(0x2600C9A7) : const Color(0xFFE6F9F5);
                          btnBorder = AppTheme.success;
                          textColor = isDark ? AppTheme.darkPrimaryLight : const Color(0xFF007A63);
                          trailingBadge = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '✓ CORRECT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.success,
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else if (isSelected) {
                          btnBg = isDark ? const Color(0x26FF6B6B) : const Color(0xFFFEECEC);
                          btnBorder = AppTheme.error;
                          textColor = AppTheme.error;
                          trailingBadge = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '✕ INCORRECT',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.error),
                                ),
                              ),
                            ],
                          );
                        }
                      }

                      final optionTextBody = opt.replaceFirst(RegExp(r'^[A-D]:\s*'), '');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: isEliminated ? 0.4 : 1.0,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: (hasAnswered || isEliminated)
                                  ? null
                                  : () => _handleQuizOptionSelect(cardIdx, optLetter, correctOpt, totalCards),
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: btnBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: btnBorder,
                                    width: isSelected || (hasAnswered && isTheCorrectAnswer) ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Letter Avatar Pill
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isEliminated
                                            ? Colors.grey.withValues(alpha: 0.2)
                                            : (isSelected || (hasAnswered && isTheCorrectAnswer)
                                                ? btnBorder.withValues(alpha: 0.2)
                                                : letterAccent.withValues(alpha: 0.12)),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isEliminated
                                              ? Colors.grey.withValues(alpha: 0.3)
                                              : (isSelected || (hasAnswered && isTheCorrectAnswer)
                                                  ? btnBorder
                                                  : letterAccent.withValues(alpha: 0.4)),
                                          width: 1.5,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        optLetter,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isEliminated ? AppTheme.textMuted : (isSelected || (hasAnswered && isTheCorrectAnswer) ? textColor : letterAccent),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        optionTextBody,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: textColor,
                                          fontWeight: isSelected || (hasAnswered && isTheCorrectAnswer)
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          decoration: isEliminated ? TextDecoration.lineThrough : null,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                    ?trailingBadge,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // ── Post-Answer Takeaway / Explanation ──────────────
                    if (hasAnswered && explanation != null && explanation.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: userSelection == correctOpt
                                ? AppTheme.success.withValues(alpha: 0.4)
                                : AppTheme.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: (userSelection == correctOpt ? AppTheme.success : AppTheme.accent).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.lightbulb_rounded,
                                    size: 16,
                                    color: userSelection == correctOpt ? AppTheme.success : AppTheme.accent,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  userSelection == correctOpt
                                      ? 'Correct! Key Takeaway'
                                      : 'Explanation & Concept Review',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: userSelection == correctOpt ? AppTheme.success : AppTheme.accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              explanation,
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.45),
                            ),
                            if (card['source_snippet'] != null && card['source_snippet'].toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.menu_book_rounded, size: 12, color: AppTheme.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Source: ${card['source_snippet']}',
                                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Action Controls ────────────────────────────────────
  Widget _buildBottomControls(Map<String, dynamic> card, int totalCards) {
    final hasAnsweredQuiz = _quizUserSelections.containsKey(_currentIndex);
    final isLastCard = _currentIndex >= totalCards - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border.withValues(alpha: 0.7))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Flashcard Confidence Grading Buttons ──────────────────
          if (_activeMode == 'flashcard') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _markCardConfidence(card: card, gotIt: false, totalCards: totalCards),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text('Need Practice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _markCardConfidence(card: card, gotIt: true, totalCards: totalCards),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.black),
                    label: const Text('Got It! (Mastered)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // ── Practice Quiz Big Action Button ───────────────────────
          if (_activeMode == 'quiz') ...[
            if (hasAnsweredQuiz)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _goToNextCard(totalCards),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  icon: Icon(
                    isLastCard ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded,
                    size: 19,
                    color: Colors.black,
                  ),
                  label: Text(
                    isLastCard ? 'Complete Quiz & View Score 🎉' : 'Next Question ➔',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_rounded, size: 15, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Select an option (A, B, C, or D) to answer',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],

          // ── Secondary Card Navigation Row ─────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Previous Card',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                color: _currentIndex > 0 ? AppTheme.text : AppTheme.textMuted,
                onPressed: _currentIndex > 0 ? _goToPreviousCard : null,
              ),
              if (_activeMode == 'flashcard')
                TextButton.icon(
                  onPressed: _toggleFlip,
                  icon: const Icon(Icons.flip_rounded, size: 16),
                  label: Text(_isFlipped ? 'Show Front' : 'Reveal Answer'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                ),
              if (_activeMode == 'quiz' && !hasAnsweredQuiz)
                TextButton.icon(
                  onPressed: () => _goToNextCard(totalCards),
                  icon: const Icon(Icons.skip_next_rounded, size: 16),
                  label: const Text('Skip Question'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
                ),
              IconButton(
                tooltip: 'Next Card',
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                color: AppTheme.text,
                onPressed: () => _goToNextCard(totalCards),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.style_outlined, size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              _scope == 'starred'
                  ? 'No Starred Questions Yet'
                  : (_scope == 'weak'
                      ? 'All caught up! No weak cards in this deck.'
                      : 'No cards available for this filter.'),
              style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _scope == 'starred'
                  ? 'Tap the star icon on any question or card to save it here for targeted drilling.'
                  : (_scope == 'weak'
                      ? 'Great job mastering all scanned module concepts!'
                      : 'Switch back to All Cards or rescan module.'),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.layers_rounded, size: 16),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _scope = 'all');
              },
              label: const Text('View All Cards'),
            ),
          ],
        ),
      ),
    );
  }
}
