import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../data/module_review_provider.dart';

/// Gizmo-style interactive review screen for module learning outcomes.
/// Features 3D active-recall flashcards, self-grading spaced repetition,
/// and interactive practice mini-quizzes automatically scanned from the module.
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

  // Filter Scope: 'all' | 'weak' | 'mastered'
  String _scope = 'all';

  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isShuffled = false;
  int _streak = 0;

  // Mini-Quiz interactive state: card index -> selected option ('A' | 'B' | 'C' | 'D')
  final Map<int, String> _quizUserSelections = {};

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
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    Future.microtask(() {
      ref.read(moduleReviewProvider.notifier).loadDeck(widget.loId);
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
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

  void _resetFlip() {
    _flipController.reset();
    _isFlipped = false;
  }

  void _goToNextCard(int totalCards) {
    if (_currentIndex < totalCards - 1) {
      _resetFlip();
      setState(() => _currentIndex++);
    } else {
      _showMasterySummaryDialog();
    }
  }

  void _goToPreviousCard() {
    if (_currentIndex > 0) {
      _resetFlip();
      setState(() => _currentIndex--);
    }
  }

  void _markCardConfidence({required Map<String, dynamic> card, required bool gotIt, required int totalCards}) {
    final cardId = card['id'] as int?;
    if (cardId != null) {
      ref.read(moduleReviewProvider.notifier).updateCardMastery(cardId, gotIt);
    }

    if (gotIt) {
      setState(() => _streak++);
    } else {
      setState(() => _streak = 0);
    }

    _goToNextCard(totalCards);
  }

  void _handleQuizOptionSelect(int cardIndex, String optionLetter, String correctOption, int totalCards) {
    if (_quizUserSelections.containsKey(cardIndex)) return; // Already answered

    final isCorrect = optionLetter.toUpperCase() == correctOption.toUpperCase();
    setState(() {
      _quizUserSelections[cardIndex] = optionLetter;
      if (isCorrect) {
        _streak++;
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology, color: AppTheme.primary, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Review Session Complete!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.text)),
                    Text('Gizmo Active Recall Mastery', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // Circular Mastery Ring / Badge
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pct >= 80 ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.primary.withValues(alpha: 0.15),
                  border: Border.all(
                    color: pct >= 80 ? AppTheme.success : AppTheme.primary,
                    width: 3,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.text)),
                    Text('Mastery', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('Mastered', '$mastered', AppTheme.success),
                  Container(width: 1, height: 28, color: AppTheme.border),
                  _buildStatItem('To Review', '${total - mastered}', AppTheme.warning),
                  Container(width: 1, height: 28, color: AppTheme.border),
                  _buildStatItem('Best Streak', '🔥 $_streak', AppTheme.primary),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                pct >= 80
                  ? 'Fantastic work! You have a solid grasp of this module\'s concepts. Ready for the official quiz?'
                  : 'Great practice session! Drill your weak cards to lock in these concepts before taking the quiz.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
              ),
            ],
          ),
          actions: [
            if (total - mastered > 0)
              TextButton.icon(
                icon: const Icon(Icons.fitness_center, size: 16),
                label: Text('Drill Weak Cards (${total - mastered})'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.warning),
                onPressed: () {
                  Navigator.pop(ctx);
                  _resetFlip();
                  setState(() {
                    _scope = 'weak';
                    _currentIndex = 0;
                  });
                },
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resetFlip();
                setState(() {
                  _scope = 'all';
                  _currentIndex = 0;
                  _quizUserSelections.clear();
                });
              },
              child: Text('Review All Again', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final deckState = ref.watch(moduleReviewProvider);

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
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology, size: 40, color: AppTheme.primary),
              ),
              const SizedBox(height: 20),
              CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                'AI Module Scanner Active',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Extracting definitions, concepts & practice questions...',
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: BackButton(color: AppTheme.text),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (subjectCode.isNotEmpty) ...[
                  Text(
                    subjectCode,
                    style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Text('•', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                  const SizedBox(width: 6),
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
            Row(
              children: [
                Icon(Icons.psychology, size: 12, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Gizmo Automated Review Deck',
                  style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                if (_streak >= 2) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('🔥 $_streak Streak', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.warning)),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isShuffled ? 'Restore order' : 'Shuffle cards',
            icon: Icon(Icons.shuffle, color: _isShuffled ? AppTheme.primary : AppTheme.textMuted),
            onPressed: () {
              _resetFlip();
              setState(() {
                _isShuffled = !_isShuffled;
                _currentIndex = 0;
              });
            },
          ),
          IconButton(
            tooltip: 'Rescan Module',
            icon: Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: () {
              ref.read(moduleReviewProvider.notifier).refreshDeck();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Mode Switcher & Filter Pills ───────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  // Mode Selector: Flashcards vs Practice Quiz
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildModeTab(
                              title: 'Practice Quiz',
                              icon: Icons.quiz_outlined,
                              isActive: _activeMode == 'quiz',
                              onTap: () {
                                setState(() => _activeMode = 'quiz');
                              },
                            ),
                          ),
                          Expanded(
                            child: _buildModeTab(
                              title: 'Flashcards',
                              icon: Icons.style_outlined,
                              isActive: _activeMode == 'flashcard',
                              onTap: () {
                                _resetFlip();
                                setState(() => _activeMode = 'flashcard');
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scope Filter Badges (All / Weak / Mastered)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildScopeBadge('all', 'All (${deckState.cards.length})'),
                  const SizedBox(width: 8),
                  _buildScopeBadge('weak', 'Needs Review (${deckState.weakCount})', color: AppTheme.warning),
                  const SizedBox(width: 8),
                  _buildScopeBadge('mastered', 'Mastered (${deckState.masteredCount})', color: AppTheme.success),
                ],
              ),
            ),

            // Progress Bar
            if (totalCards > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      'Card ${_currentIndex + 1} of $totalCards',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_currentIndex + 1) / totalCards,
                          backgroundColor: AppTheme.surfaceElevated,
                          color: AppTheme.primary,
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Main Card Area ─────────────────────────────────────────
            Expanded(
              child: totalCards == 0
                  ? _buildEmptyState()
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: _activeMode == 'flashcard'
                          ? _build3DFlipCard(deck[_currentIndex], _currentIndex, totalCards)
                          : _buildPracticeQuizCard(deck[_currentIndex], _currentIndex, totalCards),
                    ),
            ),

            // ── Bottom Action Bar ──────────────────────────────────────
            if (totalCards > 0)
              _buildBottomControls(deck.isNotEmpty ? deck[_currentIndex] : {}, totalCards),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.black : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.black : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeBadge(String scopeVal, String label, {Color? color}) {
    final isSelected = _scope == scopeVal;
    final effectiveColor = color ?? AppTheme.primary;

    return GestureDetector(
      onTap: () {
        _resetFlip();
        setState(() {
          _scope = scopeVal;
          _currentIndex = 0;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? effectiveColor.withValues(alpha: 0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? effectiveColor : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? effectiveColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── 3D Flashcard Renderer ─────────────────────────────────────
  Widget _build3DFlipCard(Map<String, dynamic> card, int cardIdx, int totalCards) {
    return GestureDetector(
      onTap: _toggleFlip,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * pi;
          final isFront = angle <= (pi / 2);

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isFront
                ? _buildCardFront(card, cardIdx, totalCards)
                : Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildCardBack(card, cardIdx, totalCards),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardFront(Map<String, dynamic> card, int cardIdx, int totalCards) {
    final type = card['card_type']?.toString() ?? 'concept';
    final frontText = card['front_text']?.toString() ?? '';
    final sourceSnippet = card['source_snippet']?.toString() ?? 'Module Concept';
    final isMastered = card['is_mastered'] == 1 || card['is_mastered'] == true;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMastered ? AppTheme.success.withValues(alpha: 0.4) : AppTheme.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
                color: AppTheme.surfaceElevated,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      type.toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isMastered)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 11, color: AppTheme.success),
                          const SizedBox(width: 4),
                          Text('Mastered', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.success)),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Icon(Icons.touch_app_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text('Tap to Flip', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),

            // Question / Concept Front Body
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.help_outline, color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        frontText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                          height: 1.4,
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
                  Icon(Icons.menu_book, size: 13, color: AppTheme.textMuted),
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

  Widget _buildCardBack(Map<String, dynamic> card, int cardIdx, int totalCards) {
    final backText = card['back_text']?.toString() ?? '';
    final explanation = card['explanation']?.toString();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 1.5),
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
                color: AppTheme.primary.withValues(alpha: 0.1),
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Answer / Definition',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                  ),
                  const Spacer(),
                  Icon(Icons.flip, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text('Flip Back', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
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
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.text, height: 1.5),
                    ),
                    if (explanation != null && explanation.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                explanation,
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
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
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Text(
                    'Did you recall this correctly?',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
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
  Widget _buildPracticeQuizCard(Map<String, dynamic> card, int cardIdx, int totalCards) {
    final frontText = card['front_text']?.toString() ?? '';
    final explanation = card['explanation']?.toString();
    final userSelection = _quizUserSelections[cardIdx];
    final hasAnswered = userSelection != null;

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

    // Fallback: If card somehow doesn't have 4 options, dynamically generate them from back_text
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasAnswered
              ? (userSelection == correctOpt ? AppTheme.success.withValues(alpha: 0.6) : AppTheme.error.withValues(alpha: 0.4))
              : AppTheme.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
                color: AppTheme.surfaceElevated,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.quiz, size: 14, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Text('PRACTICE QUIZ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.accent)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_streak > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            '$_streak Streak!',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (hasAnswered)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: userSelection.toUpperCase() == correctOpt
                            ? AppTheme.success.withValues(alpha: 0.15)
                            : AppTheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: userSelection.toUpperCase() == correctOpt ? AppTheme.success : AppTheme.error,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            userSelection.toUpperCase() == correctOpt ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: userSelection.toUpperCase() == correctOpt ? AppTheme.success : AppTheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            userSelection.toUpperCase() == correctOpt ? 'Correct! +10 XP' : 'Incorrect',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: userSelection.toUpperCase() == correctOpt ? AppTheme.success : AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Question text & Options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      frontText,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text, height: 1.4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasAnswered
                          ? 'Review the outcome and explanation below:'
                          : 'Select the best option from the choices below:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 18),

                    // Options List
                    ...options.map((opt) {
                      final optLetter = opt.length >= 2 && opt[1] == ':' ? opt[0].toUpperCase() : 'A';
                      final isSelected = userSelection == optLetter;
                      final isTheCorrectAnswer = optLetter == correctOpt;

                      Color btnBg = AppTheme.background;
                      Color btnBorder = AppTheme.border;
                      Color textColor = AppTheme.text;
                      Widget? trailingBadge;

                      if (hasAnswered) {
                        if (isTheCorrectAnswer) {
                          btnBg = AppTheme.success.withValues(alpha: 0.18);
                          btnBorder = AppTheme.success;
                          textColor = AppTheme.success;
                          trailingBadge = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'CORRECT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.success,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.check_circle, size: 18, color: AppTheme.success),
                            ],
                          );
                        } else if (isSelected) {
                          btnBg = AppTheme.error.withValues(alpha: 0.18);
                          btnBorder = AppTheme.error;
                          textColor = AppTheme.error;
                          trailingBadge = Icon(Icons.cancel, size: 18, color: AppTheme.error);
                        }
                      } else if (isSelected) {
                        btnBorder = AppTheme.primary;
                      }

                      final optionTextBody = opt.replaceFirst(RegExp(r'^[A-D]:\s*'), '');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: hasAnswered
                                ? null
                                : () => _handleQuizOptionSelect(cardIdx, optLetter, correctOpt, totalCards),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: btnBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: btnBorder,
                                  width: isSelected || (hasAnswered && isTheCorrectAnswer) ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: isSelected || (hasAnswered && isTheCorrectAnswer)
                                          ? btnBorder.withValues(alpha: 0.25)
                                          : AppTheme.surfaceElevated,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: btnBorder.withValues(alpha: 0.4),
                                        width: 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      optLetter,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      optionTextBody,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: textColor,
                                        fontWeight: isSelected || (hasAnswered && isTheCorrectAnswer) ? FontWeight.bold : FontWeight.normal,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  ?trailingBadge,
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    if (hasAnswered && explanation != null && explanation.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline, size: 18, color: AppTheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Explanation & Study Takeaway',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    explanation,
                                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }

  // ── Bottom Action Controls ────────────────────────────────────
  Widget _buildBottomControls(Map<String, dynamic> card, int totalCards) {
    final hasAnsweredQuiz = _quizUserSelections.containsKey(_currentIndex);
    final isLastCard = _currentIndex >= totalCards - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_activeMode == 'flashcard') ...[
            // Confidence buttons (Gizmo / Spaced Repetition)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _markCardConfidence(card: card, gotIt: false, totalCards: totalCards),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.warning,
                      side: BorderSide(color: AppTheme.warning.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check, size: 16, color: Colors.black),
                    label: const Text('Got It!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // In Practice Quiz Mode: Big Prominent "Next Question" or "Answer above"
          if (_activeMode == 'quiz') ...[
            if (hasAnsweredQuiz)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _goToNextCard(totalCards),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  icon: Icon(
                    isLastCard ? Icons.emoji_events : Icons.arrow_forward,
                    size: 18,
                    color: Colors.black,
                  ),
                  label: Text(
                    isLastCard ? 'Complete Quiz & View Score 🎉' : 'Next Question ➡️',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                child: Text(
                  '👆 Select an option (A, B, C, or D) above to answer',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],

          // Card Navigation Secondary Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Previous Card',
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: _currentIndex > 0 ? AppTheme.text : AppTheme.textMuted,
                onPressed: _currentIndex > 0 ? _goToPreviousCard : null,
              ),
              if (_activeMode == 'flashcard')
                TextButton.icon(
                  onPressed: _toggleFlip,
                  icon: const Icon(Icons.flip, size: 16),
                  label: Text(_isFlipped ? 'Show Question' : 'Reveal Answer'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                ),
              if (_activeMode == 'quiz' && !hasAnsweredQuiz)
                TextButton.icon(
                  onPressed: () => _goToNextCard(totalCards),
                  icon: const Icon(Icons.skip_next, size: 16),
                  label: const Text('Skip Question'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
                ),
              if (_activeMode == 'quiz' && hasAnsweredQuiz)
                TextButton.icon(
                  onPressed: () => _goToNextCard(totalCards),
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  label: const Text('Next'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                ),
              IconButton(
                tooltip: 'Next Card',
                icon: const Icon(Icons.arrow_forward_ios, size: 18),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.style_outlined, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 14),
          Text(
            _scope == 'weak'
                ? 'All caught up! No weak cards in this deck.'
                : 'No cards available for this selection.',
            style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            _scope == 'weak'
                ? 'Great job mastering all scanned module concepts!'
                : 'Tap Rescan or switch back to All Cards.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () => setState(() => _scope = 'all'),
            child: const Text('View All Cards'),
          ),
        ],
      ),
    );
  }
}
