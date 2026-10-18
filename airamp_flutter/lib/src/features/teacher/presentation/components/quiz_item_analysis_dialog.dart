import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/teacher_repository.dart';
import '../../domain/item_analysis_model.dart';

/// Modal dialog that presents automated psychometric Item Analysis per quiz.
/// Includes a dropdown at the top to switch between quizzes smoothly.
class QuizItemAnalysisDialog extends ConsumerStatefulWidget {
  final int? initialQuizId;
  final int? subjectId;

  const QuizItemAnalysisDialog({
    super.key,
    this.initialQuizId,
    this.subjectId,
  });

  /// Static helper to display the modal from any screen.
  static Future<void> show(
    BuildContext context, {
    int? initialQuizId,
    int? subjectId,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QuizItemAnalysisDialog(
        initialQuizId: initialQuizId,
        subjectId: subjectId,
      ),
    );
  }

  @override
  ConsumerState<QuizItemAnalysisDialog> createState() => _QuizItemAnalysisDialogState();
}

class _QuizItemAnalysisDialogState extends ConsumerState<QuizItemAnalysisDialog> {
  int? _selectedQuizId;
  int _activeFilter = 0; // 0: All, 1: Needs Attention, 2: Retained
  final Set<int> _expandedQuestions = {};

  @override
  void initState() {
    super.initState();
    _selectedQuizId = widget.initialQuizId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_selectedQuizId != null) {
          ref.invalidate(quizItemAnalysisProvider(_selectedQuizId!));
        }
        ref.invalidate(teacherQuizzesForAnalysisProvider(widget.subjectId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final quizzesAsync = ref.watch(teacherQuizzesForAnalysisProvider(widget.subjectId));

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth > 900 ? 40 : 16,
        vertical: 24,
      ),
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: screenWidth > 950 ? 900 : double.infinity,
        height: screenHeight * 0.88,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Modal Header
            _buildModalHeader(context),
            const Divider(height: 24),

            // Dropdown Selector Bar
            quizzesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Error loading quizzes: $err', style: TextStyle(color: AppTheme.error)),
              ),
              data: (quizList) {
                if (quizList.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.textMuted, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'No quizzes available for analysis yet.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                // If no quiz is selected yet, select the first one
                if (_selectedQuizId == null && quizList.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _selectedQuizId = quizList.first['id'] as int;
                      });
                    }
                  });
                }

                return _buildQuizDropdown(quizList);
              },
            ),

            const SizedBox(height: 14),

            // Main Content: Psychometric Report for selected quiz
            Expanded(
              child: _selectedQuizId == null
                  ? _buildSelectQuizPrompt()
                  : _buildReportBody(_selectedQuizId!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.analytics_outlined, color: AppTheme.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quiz Item Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
              Text(
                'Automated difficulty, discrimination, and distractor efficiency calculations',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh Analysis',
          onPressed: () {
            if (_selectedQuizId != null) {
              ref.invalidate(quizItemAnalysisProvider(_selectedQuizId!));
            }
            ref.invalidate(teacherQuizzesForAnalysisProvider(widget.subjectId));
          },
          icon: Icon(Icons.refresh_rounded, color: AppTheme.primary),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close, color: AppTheme.textMuted),
          tooltip: 'Close Modal',
        ),
      ],
    );
  }

  Widget _buildQuizDropdown(List<Map<String, dynamic>> quizList) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedQuizId,
          hint: Row(
            children: [
              Icon(Icons.quiz_outlined, size: 18, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text('Choose a Quiz to view Item Analysis...', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary),
          dropdownColor: AppTheme.surface,
          items: quizList.map((q) {
            final qId = q['id'] as int;
            final title = q['title']?.toString() ?? 'Quiz #$qId';
            final subject = q['subject_name']?.toString() ?? '';
            final code = q['subject_code']?.toString() ?? '';
            final questions = q['question_count'] ?? 0;
            final attempts = q['attempt_count'] ?? 0;

            final subtitle = [
              if (code.isNotEmpty) code else if (subject.isNotEmpty) subject,
              '$questions items',
              '$attempts attempts',
            ].join(' · ');

            return DropdownMenuItem<int>(
              value: qId,
              child: Row(
                children: [
                  Icon(Icons.quiz_outlined, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: attempts > 0
                          ? AppTheme.success.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      attempts > 0 ? '$attempts Submissions' : 'No Attempts',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: attempts > 0 ? AppTheme.success : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (newId) {
            if (newId != null) {
              setState(() {
                _selectedQuizId = newId;
                _expandedQuestions.clear();
                _activeFilter = 0;
              });
              ref.invalidate(quizItemAnalysisProvider(newId));
            }
          },
        ),
      ),
    );
  }

  Widget _buildSelectQuizPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(
            'Select a Quiz from the dropdown above',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.text),
          ),
          const SizedBox(height: 4),
          Text(
            'Item analysis metrics and distractor statistics will compute automatically.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildReportBody(int quizId) {
    final reportAsync = ref.watch(quizItemAnalysisProvider(quizId));

    return reportAsync.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(
              'Computing psychometric item analysis...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
      error: (e, st) => Center(
        child: Text('Failed to calculate item analysis: $e', style: TextStyle(color: AppTheme.error)),
      ),
      data: (report) {
        if (!report.hasAttempts) {
          return _buildZeroAttemptsState(report);
        }

        return Column(
          children: [
            // Top action bar with Export and Sample info
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${report.quizTitle} (${report.totalAttempts} students · ${report.totalQuestions} questions)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _exportCsvReport(context, report),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Export CSV', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

            // Small sample size warning if N < 5
            if (report.isSmallSample)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Preliminary Analysis (N = ${report.totalAttempts}): As more students take the quiz, discrimination index ($report.meanDiscrimination) will gain higher statistical precision.',
                        style: TextStyle(fontSize: 11, color: AppTheme.text),
                      ),
                    ),
                  ],
                ),
              ),

            // Summary KPI Cards
            _buildKpiCards(report),
            const SizedBox(height: 12),

            // Filter Tabs
            _buildFilterPills(report),
            const SizedBox(height: 10),

            // Questions List
            Expanded(
              child: _buildQuestionsList(report),
            ),
          ],
        );
      },
    );
  }

  Widget _buildZeroAttemptsState(ItemAnalysisReport report) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assessment_outlined, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 14),
            Text(
              'No Student Submissions Yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
            const SizedBox(height: 6),
            Text(
              'Item analysis calculates automatically once students attempt "${report.quizTitle}".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                if (_selectedQuizId != null) {
                  ref.invalidate(quizItemAnalysisProvider(_selectedQuizId!));
                }
                ref.invalidate(teacherQuizzesForAnalysisProvider(widget.subjectId));
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh Submissions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCards(ItemAnalysisReport report) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        final card1 = _buildKpiCard(
          title: 'Class Average',
          value: '${report.meanScore.toStringAsFixed(1)} pts',
          subtitle: 'Pass Rate: ${report.passRate.toStringAsFixed(0)}%',
          icon: Icons.score_outlined,
          color: AppTheme.primary,
        );

        final card2 = _buildKpiCard(
          title: 'KR-20 Reliability',
          value: report.kr20Reliability != null ? report.kr20Reliability!.toStringAsFixed(2) : 'N/A',
          subtitle: 'Rating: ${report.reliabilityRating}',
          icon: Icons.verified_outlined,
          color: report.kr20Reliability != null && report.kr20Reliability! >= 0.70 ? AppTheme.success : Colors.orange,
        );

        final card3 = _buildKpiCard(
          title: 'Mean Difficulty (p)',
          value: report.meanDifficulty.toStringAsFixed(2),
          subtitle: _getDifficultySummaryLabel(report.meanDifficulty),
          icon: Icons.speed_outlined,
          color: AppTheme.accent,
        );

        final card4 = _buildKpiCard(
          title: 'Quality Breakdown',
          value: '${report.retainCount} Retain',
          subtitle: '${report.reviseCount} Revise · ${report.discardCount + report.checkKeyCount} Discard/Key',
          icon: Icons.inventory_2_outlined,
          color: report.checkKeyCount > 0 ? Colors.red : AppTheme.success,
        );

        if (isCompact) {
          return Column(
            children: [
              Row(children: [Expanded(child: card1), const SizedBox(width: 8), Expanded(child: card2)]),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: card3), const SizedBox(width: 8), Expanded(child: card4)]),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: 8),
            Expanded(child: card2),
            const SizedBox(width: 8),
            Expanded(child: card3),
            const SizedBox(width: 8),
            Expanded(child: card4),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPills(ItemAnalysisReport report) {
    final needsAttentionCount = report.reviseCount + report.discardCount + report.checkKeyCount;

    return Row(
      children: [
        _buildFilterChip('All (${report.questions.length})', 0),
        const SizedBox(width: 6),
        _buildFilterChip(
          'Needs Attention ($needsAttentionCount)',
          1,
          badgeColor: needsAttentionCount > 0 ? Colors.orange : null,
        ),
        const SizedBox(width: 6),
        _buildFilterChip('Retained (${report.retainCount})', 2),
      ],
    );
  }

  Widget _buildFilterChip(String label, int index, {Color? badgeColor}) {
    final isActive = _activeFilter == index;
    return InkWell(
      onTap: () => setState(() => _activeFilter = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primary : (badgeColor ?? AppTheme.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.black : (badgeColor ?? AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionsList(ItemAnalysisReport report) {
    final filtered = report.questions.where((q) {
      if (_activeFilter == 1) return q.isNeedsAttention;
      if (_activeFilter == 2) return q.recommendation == ItemAction.retain;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No questions in this filter.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final q = filtered[i];
        final isExpanded = _expandedQuestions.contains(q.questionId);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: q.recommendation == ItemAction.checkKey
                  ? Colors.red.withValues(alpha: 0.5)
                  : q.isNeedsAttention
                      ? Colors.orange.withValues(alpha: 0.4)
                      : AppTheme.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question Header Bar
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedQuestions.remove(q.questionId);
                    } else {
                      _expandedQuestions.add(q.questionId);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question Number Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          '#${q.index}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.text),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Stem and Metrics
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q.questionText,
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.text),
                              maxLines: isExpanded ? null : 2,
                              overflow: isExpanded ? null : TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _buildBadge('Key: ${q.correctOption}', AppTheme.success),
                                _buildBadge(
                                  'p: ${q.difficultyIndex.toStringAsFixed(2)} (${q.difficultyLabel})',
                                  _getDifficultyColor(q.difficultyIndex),
                                ),
                                _buildBadge(
                                  'D: ${q.discriminationIndex.toStringAsFixed(2)} (${q.discriminationLabel})',
                                  _getDiscriminationColor(q.discriminationIndex),
                                ),
                                _buildActionBadge(q.recommendation, q.recommendationLabel),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded Deep Dive Content
              if (isExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Distractor Distribution Chart
                      Text(
                        'Option Choice Distribution:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.text),
                      ),
                      const SizedBox(height: 8),
                      ...['A', 'B', 'C', 'D'].map((opt) => _buildOptionRow(q, opt)),
                      const SizedBox(height: 12),

                      // Upper vs Lower Group Mini Table
                      _buildUpperLowerTable(q),
                      const SizedBox(height: 12),

                      // Warnings
                      if (q.distractorWarnings.isNotEmpty) ...[
                        ...q.distractorWarnings.map((w) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      w,
                                      style: const TextStyle(fontSize: 11, color: Colors.orange),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 8),
                      ],

                      // Pedagogical Advice Callout
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getActionBgColor(q.recommendation),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _getActionBorderColor(q.recommendation)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline, size: 16, color: _getActionColor(q.recommendation)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                q.pedagogicalAdvice,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.text,
                                ),
                              ),
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
        );
      },
    );
  }

  Widget _buildOptionRow(QuestionItemAnalysis q, String opt) {
    final text = q.optionTexts[opt] ?? '';
    final count = q.totalSelections[opt] ?? 0;
    final pct = q.selectionPercentages[opt] ?? 0.0;
    final isCorrect = opt == q.correctOption;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isCorrect ? AppTheme.success : AppTheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: isCorrect ? AppTheme.success : AppTheme.border),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? Colors.black : AppTheme.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text.isNotEmpty ? text : '(Empty Option)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isCorrect ? AppTheme.success : AppTheme.textSecondary,
                    fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count (${pct.toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? AppTheme.success : AppTheme.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              minHeight: 5,
              backgroundColor: AppTheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCorrect ? AppTheme.success : AppTheme.primary.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpperLowerTable(QuestionItemAnalysis q) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upper vs Lower Group Choice Comparison:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildGroupCell('Group', isHeader: true),
              _buildGroupCell('A', isHeader: true, isKey: q.correctOption == 'A'),
              _buildGroupCell('B', isHeader: true, isKey: q.correctOption == 'B'),
              _buildGroupCell('C', isHeader: true, isKey: q.correctOption == 'C'),
              _buildGroupCell('D', isHeader: true, isKey: q.correctOption == 'D'),
            ],
          ),
          const Divider(height: 8),
          Row(
            children: [
              _buildGroupCell('Upper Group'),
              _buildGroupCell('${q.upperGroupSelections['A'] ?? 0}', isKey: q.correctOption == 'A'),
              _buildGroupCell('${q.upperGroupSelections['B'] ?? 0}', isKey: q.correctOption == 'B'),
              _buildGroupCell('${q.upperGroupSelections['C'] ?? 0}', isKey: q.correctOption == 'C'),
              _buildGroupCell('${q.upperGroupSelections['D'] ?? 0}', isKey: q.correctOption == 'D'),
            ],
          ),
          Row(
            children: [
              _buildGroupCell('Lower Group'),
              _buildGroupCell('${q.lowerGroupSelections['A'] ?? 0}', isKey: q.correctOption == 'A'),
              _buildGroupCell('${q.lowerGroupSelections['B'] ?? 0}', isKey: q.correctOption == 'B'),
              _buildGroupCell('${q.lowerGroupSelections['C'] ?? 0}', isKey: q.correctOption == 'C'),
              _buildGroupCell('${q.lowerGroupSelections['D'] ?? 0}', isKey: q.correctOption == 'D'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCell(String text, {bool isHeader = false, bool isKey = false}) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isHeader || isKey ? FontWeight.bold : FontWeight.normal,
          color: isKey ? AppTheme.success : (isHeader ? AppTheme.textSecondary : AppTheme.text),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildActionBadge(ItemAction action, String label) {
    final color = _getActionColor(action);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            action == ItemAction.retain
                ? Icons.check_circle_outline
                : action == ItemAction.checkKey
                    ? Icons.key_off_outlined
                    : Icons.edit_note,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(double p) {
    if (p < 0.20 || p > 0.80) return Colors.red;
    if (p >= 0.40 && p <= 0.60) return AppTheme.success;
    return Colors.orange;
  }

  Color _getDiscriminationColor(double d) {
    if (d < 0.0) return Colors.red;
    if (d >= 0.30) return AppTheme.success;
    if (d >= 0.20) return Colors.orange;
    return Colors.red;
  }

  Color _getActionColor(ItemAction action) {
    switch (action) {
      case ItemAction.retain:
        return AppTheme.success;
      case ItemAction.reviseDistractor:
      case ItemAction.reviseStem:
        return Colors.orange;
      case ItemAction.checkKey:
      case ItemAction.discard:
        return Colors.red;
    }
  }

  Color _getActionBgColor(ItemAction action) {
    return _getActionColor(action).withValues(alpha: 0.1);
  }

  Color _getActionBorderColor(ItemAction action) {
    return _getActionColor(action).withValues(alpha: 0.3);
  }

  String _getDifficultySummaryLabel(double meanDiff) {
    if (meanDiff <= 0.20) return 'Very Difficult';
    if (meanDiff <= 0.40) return 'Difficult';
    if (meanDiff <= 0.60) return 'Moderate (Ideal)';
    if (meanDiff <= 0.80) return 'Easy';
    return 'Very Easy';
  }

  void _exportCsvReport(BuildContext context, ItemAnalysisReport report) {
    final buffer = StringBuffer();
    buffer.writeln('AIRAMP Quiz Item Analysis Report');
    buffer.writeln('Quiz Title,"${report.quizTitle}"');
    buffer.writeln('Subject,"${report.subjectName} (${report.subjectCode})"');
    buffer.writeln('Total Students,${report.totalAttempts}');
    buffer.writeln('Total Questions,${report.totalQuestions}');
    buffer.writeln('Class Mean Score,${report.meanScore.toStringAsFixed(2)}');
    buffer.writeln('Class Pass Rate,${report.passRate.toStringAsFixed(1)}%');
    buffer.writeln('KR-20 Reliability,${report.kr20Reliability?.toStringAsFixed(3) ?? "N/A"} (${report.reliabilityRating})');
    buffer.writeln('Mean Difficulty (p),${report.meanDifficulty.toStringAsFixed(3)}');
    buffer.writeln('Mean Discrimination (D),${report.meanDiscrimination.toStringAsFixed(3)}');
    buffer.writeln('');

    // DepEd standard matrix table
    buffer.writeln('Item #,Question Stem,Key,Difficulty Index (p),Difficulty Interpretation,Discrimination Index (D),Discrimination Interpretation,Action Taken,Option A %,Option B %,Option C %,Option D %,Pedagogical Advice');
    for (final q in report.questions) {
      final cleanStem = q.questionText.replaceAll('"', '""').replaceAll('\n', ' ');
      final cleanAdvice = q.pedagogicalAdvice.replaceAll('"', '""');
      buffer.writeln('${q.index},"$cleanStem",${q.correctOption},${q.difficultyIndex.toStringAsFixed(3)},"${q.difficultyLabel}",${q.discriminationIndex.toStringAsFixed(3)},"${q.discriminationLabel}","${q.recommendationLabel}",${(q.selectionPercentages['A'] ?? 0).toStringAsFixed(1)}%,${(q.selectionPercentages['B'] ?? 0).toStringAsFixed(1)}%,${(q.selectionPercentages['C'] ?? 0).toStringAsFixed(1)}%,${(q.selectionPercentages['D'] ?? 0).toStringAsFixed(1)}%,"$cleanAdvice"');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.success,
        content: Text('Item Analysis matrix copied to clipboard in CSV format! You can paste it directly into Excel or Google Sheets.'),
      ),
    );
  }
}
