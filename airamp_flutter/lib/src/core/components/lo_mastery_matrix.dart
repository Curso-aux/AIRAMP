import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoMasteryItem {
  final String loCode;
  final String loTitle;
  final String subject;
  final String section;
  final double score; // 0.0 to 100.0
  final int assessedCount;
  final int masteredCount;
  final int developingCount;
  final int atRiskCount;
  final List<LoMissedQuestion> mostMissedItems;
  final String remediationAction;

  const LoMasteryItem({
    required this.loCode,
    required this.loTitle,
    required this.subject,
    required this.section,
    required this.score,
    required this.assessedCount,
    required this.masteredCount,
    required this.developingCount,
    required this.atRiskCount,
    required this.mostMissedItems,
    required this.remediationAction,
  });

  String get tier {
    if (score >= 80.0) return 'Proficient';
    if (score >= 60.0) return 'Developing';
    return 'Needs Help';
  }
}

class LoMissedQuestion {
  final String questionText;
  final int missedPercent;
  final String commonMistake;

  const LoMissedQuestion({
    required this.questionText,
    required this.missedPercent,
    required this.commonMistake,
  });
}

class LoMasteryMatrix extends StatefulWidget {
  final String? initialSubject;
  final bool compact;

  const LoMasteryMatrix({
    super.key,
    this.initialSubject,
    this.compact = false,
  });

  @override
  State<LoMasteryMatrix> createState() => _LoMasteryMatrixState();
}

class _LoMasteryMatrixState extends State<LoMasteryMatrix> {
  String _selectedSubject = 'All Subjects';
  String _searchQuery = '';

  // Standard curriculum mock database for matrix visualization
  late final List<LoMasteryItem> _masteryData;

  @override
  void initState() {
    super.initState();
    if (widget.initialSubject != null) {
      _selectedSubject = widget.initialSubject!;
    }
    _masteryData = _generateMasteryData();
  }

  List<LoMasteryItem> _generateMasteryData() {
    return const [
      // Empowerment Technologies
      LoMasteryItem(
        loCode: 'LO-01',
        loTitle: 'Advanced Productivity & Automation',
        subject: 'Empowerment Technologies',
        section: '11-STEM-A',
        score: 88.5,
        assessedCount: 42,
        masteredCount: 32,
        developingCount: 8,
        atRiskCount: 2,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Nested lookup formulas & dynamic references in spreadsheets',
            missedPercent: 45,
            commonMistake: 'Confused relative vs. absolute cell locking (\$A\$1)',
          ),
          LoMissedQuestion(
            questionText: 'Mail merge source connection security exceptions',
            missedPercent: 32,
            commonMistake: 'Overlooked file path permission headers',
          ),
        ],
        remediationAction: 'Provide short laboratory drill on absolute range anchoring and dynamic references.',
      ),
      LoMasteryItem(
        loCode: 'LO-01',
        loTitle: 'Advanced Productivity & Automation',
        subject: 'Empowerment Technologies',
        section: '11-STEM-B',
        score: 82.0,
        assessedCount: 40,
        masteredCount: 27,
        developingCount: 10,
        atRiskCount: 3,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Conditional formatting with custom formula criteria',
            missedPercent: 52,
            commonMistake: 'Omitted leading equals sign in boolean criteria',
          ),
        ],
        remediationAction: 'Assign peer review exercise covering conditional formatting rules.',
      ),
      LoMasteryItem(
        loCode: 'LO-01',
        loTitle: 'Advanced Productivity & Automation',
        subject: 'Empowerment Technologies',
        section: '11-ABM-A',
        score: 74.0,
        assessedCount: 38,
        masteredCount: 19,
        developingCount: 14,
        atRiskCount: 5,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Macro automation scripting syntax & event triggers',
            missedPercent: 64,
            commonMistake: 'Syntax errors in subroutine declarations',
          ),
        ],
        remediationAction: 'Schedule a 20-minute targeted review with guided worksheet walkthrough.',
      ),
      LoMasteryItem(
        loCode: 'LO-01',
        loTitle: 'Advanced Productivity & Automation',
        subject: 'Empowerment Technologies',
        section: '11-HUMSS-A',
        score: 68.5,
        assessedCount: 36,
        masteredCount: 16,
        developingCount: 14,
        atRiskCount: 6,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Data validation rules with custom input alerts',
            missedPercent: 60,
            commonMistake: 'Incorrect error alert stop vs warning settings',
          ),
        ],
        remediationAction: 'Deploy Gizmo interactive flashcard deck for spreadsheet validation concepts.',
      ),
      LoMasteryItem(
        loCode: 'LO-01',
        loTitle: 'Advanced Productivity & Automation',
        subject: 'Empowerment Technologies',
        section: '12-TVL-ICT',
        score: 91.0,
        assessedCount: 35,
        masteredCount: 30,
        developingCount: 4,
        atRiskCount: 1,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Cloud document collaboration conflict resolution',
            missedPercent: 28,
            commonMistake: 'Missed revision history restore branching',
          ),
        ],
        remediationAction: 'Advanced mastery demonstrated. Ready for practical capstone assessment.',
      ),

      // LO-02: Web Design & Principles
      LoMasteryItem(
        loCode: 'LO-02',
        loTitle: 'Web Principles & Responsive Design',
        subject: 'Empowerment Technologies',
        section: '11-STEM-A',
        score: 84.0,
        assessedCount: 42,
        masteredCount: 29,
        developingCount: 11,
        atRiskCount: 2,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'CSS Flexbox vs CSS Grid layout mechanics',
            missedPercent: 48,
            commonMistake: 'Misunderstanding cross-axis alignment parameters',
          ),
        ],
        remediationAction: 'Conduct visual CSS diagramming recap during laboratory session.',
      ),
      LoMasteryItem(
        loCode: 'LO-02',
        loTitle: 'Web Principles & Responsive Design',
        subject: 'Empowerment Technologies',
        section: '11-STEM-B',
        score: 78.5,
        assessedCount: 40,
        masteredCount: 23,
        developingCount: 13,
        atRiskCount: 4,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Mobile viewport meta tag configuration',
            missedPercent: 55,
            commonMistake: 'Omitted initial-scale=1.0 parameter',
          ),
        ],
        remediationAction: 'Provide responsive emulator test template in offline learning hub.',
      ),
      LoMasteryItem(
        loCode: 'LO-02',
        loTitle: 'Web Principles & Responsive Design',
        subject: 'Empowerment Technologies',
        section: '11-ABM-A',
        score: 63.0,
        assessedCount: 38,
        masteredCount: 14,
        developingCount: 15,
        atRiskCount: 9,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Semantic HTML5 structure & accessibility tags',
            missedPercent: 68,
            commonMistake: 'Overusing generic div tags instead of article and section',
          ),
        ],
        remediationAction: 'Deliver remediation mini-module on semantic web accessibility standards.',
      ),
      LoMasteryItem(
        loCode: 'LO-02',
        loTitle: 'Web Principles & Responsive Design',
        subject: 'Empowerment Technologies',
        section: '11-HUMSS-A',
        score: 58.0,
        assessedCount: 36,
        masteredCount: 11,
        developingCount: 14,
        atRiskCount: 11,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Color contrast ratio accessibility guidelines (WCAG)',
            missedPercent: 72,
            commonMistake: 'Failed to meet 4.5:1 minimum normal text contrast',
          ),
        ],
        remediationAction: 'High priority intervention: Schedule guided review and open quiz retake.',
      ),
      LoMasteryItem(
        loCode: 'LO-02',
        loTitle: 'Web Principles & Responsive Design',
        subject: 'Empowerment Technologies',
        section: '12-TVL-ICT',
        score: 87.5,
        assessedCount: 35,
        masteredCount: 28,
        developingCount: 6,
        atRiskCount: 1,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Media queries breakpoint strategy',
            missedPercent: 36,
            commonMistake: 'Desktop-first vs mobile-first query precedence',
          ),
        ],
        remediationAction: 'Section demonstrated strong practical mastery.',
      ),

      // General Mathematics: Functions & Rational Equations
      LoMasteryItem(
        loCode: 'LO-03',
        loTitle: 'Functions & Rational Expressions',
        subject: 'General Mathematics',
        section: '11-STEM-A',
        score: 86.0,
        assessedCount: 42,
        masteredCount: 30,
        developingCount: 10,
        atRiskCount: 2,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Vertical and horizontal asymptotes of rational functions',
            missedPercent: 44,
            commonMistake: 'Ignored degree equality rules for horizontal asymptote',
          ),
        ],
        remediationAction: 'Share asymptotic behavior summary cheatsheet.',
      ),
      LoMasteryItem(
        loCode: 'LO-03',
        loTitle: 'Functions & Rational Expressions',
        subject: 'General Mathematics',
        section: '11-STEM-B',
        score: 81.5,
        assessedCount: 40,
        masteredCount: 26,
        developingCount: 11,
        atRiskCount: 3,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Extraneous solutions in rational algebraic equations',
            missedPercent: 50,
            commonMistake: 'Did not check root against denominator zero restrictions',
          ),
        ],
        remediationAction: 'Practice domain restriction verification drills.',
      ),
      LoMasteryItem(
        loCode: 'LO-03',
        loTitle: 'Functions & Rational Expressions',
        subject: 'General Mathematics',
        section: '11-ABM-A',
        score: 66.0,
        assessedCount: 38,
        masteredCount: 15,
        developingCount: 16,
        atRiskCount: 7,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Inverse function algebraic derivation',
            missedPercent: 62,
            commonMistake: 'Algebraic slip during cross-multiplication isolation',
          ),
        ],
        remediationAction: 'Conduct small-group remediation on algebraic function operations.',
      ),
      LoMasteryItem(
        loCode: 'LO-03',
        loTitle: 'Functions & Rational Expressions',
        subject: 'General Mathematics',
        section: '11-HUMSS-A',
        score: 55.0,
        assessedCount: 36,
        masteredCount: 9,
        developingCount: 15,
        atRiskCount: 12,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Word problems involving combined work rates',
            missedPercent: 78,
            commonMistake: 'Set up sum of times rather than sum of reciprocal work rates',
          ),
        ],
        remediationAction: 'Urgent intervention: Deploy stepped problem solver and video tutorials.',
      ),
      LoMasteryItem(
        loCode: 'LO-03',
        loTitle: 'Functions & Rational Expressions',
        subject: 'General Mathematics',
        section: '12-TVL-ICT',
        score: 72.0,
        assessedCount: 35,
        masteredCount: 18,
        developingCount: 13,
        atRiskCount: 4,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Piecewise function interval evaluation',
            missedPercent: 56,
            commonMistake: 'Included boundary value in wrong interval segment',
          ),
        ],
        remediationAction: 'Reinforce boundary inequality signs with number line graphs.',
      ),

      // Oral Communication: Speech Acts & Delivery
      LoMasteryItem(
        loCode: 'LO-04',
        loTitle: 'Speech Acts & Communicative Competence',
        subject: 'Oral Communication',
        section: '11-STEM-A',
        score: 89.0,
        assessedCount: 42,
        masteredCount: 33,
        developingCount: 8,
        atRiskCount: 1,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Illocutionary vs perlocutionary speech act distinction',
            missedPercent: 35,
            commonMistake: 'Confused speaker intent with listener behavioral consequence',
          ),
        ],
        remediationAction: 'Maintain current instructional pace.',
      ),
      LoMasteryItem(
        loCode: 'LO-04',
        loTitle: 'Speech Acts & Communicative Competence',
        subject: 'Oral Communication',
        section: '11-HUMSS-A',
        score: 93.5,
        assessedCount: 36,
        masteredCount: 32,
        developingCount: 4,
        atRiskCount: 0,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Turn-taking and nomination repair strategies',
            missedPercent: 22,
            commonMistake: 'Overlapped topic control with abrupt termination',
          ),
        ],
        remediationAction: 'Exemplary cohort performance. Assign advanced debate seminar.',
      ),
      LoMasteryItem(
        loCode: 'LO-04',
        loTitle: 'Speech Acts & Communicative Competence',
        subject: 'Oral Communication',
        section: '11-ABM-A',
        score: 83.0,
        assessedCount: 38,
        masteredCount: 27,
        developingCount: 9,
        atRiskCount: 2,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Non-verbal kinesics and proxemics in business pitches',
            missedPercent: 40,
            commonMistake: 'Underestimated spatial distance impact on audience reception',
          ),
        ],
        remediationAction: 'Conduct mock presentation rehearsals.',
      ),
      LoMasteryItem(
        loCode: 'LO-04',
        loTitle: 'Speech Acts & Communicative Competence',
        subject: 'Oral Communication',
        section: '11-STEM-B',
        score: 85.0,
        assessedCount: 40,
        masteredCount: 29,
        developingCount: 9,
        atRiskCount: 2,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'J.L. Austin speech act classification taxonomy',
            missedPercent: 38,
            commonMistake: 'Swapped verdictives with exercitives',
          ),
        ],
        remediationAction: 'Reinforce classification mnemonic.',
      ),
      LoMasteryItem(
        loCode: 'LO-04',
        loTitle: 'Speech Acts & Communicative Competence',
        subject: 'Oral Communication',
        section: '12-TVL-ICT',
        score: 79.0,
        assessedCount: 35,
        masteredCount: 22,
        developingCount: 11,
        atRiskCount: 2,
        mostMissedItems: [
          LoMissedQuestion(
            questionText: 'Handling technical jargon in client communication',
            missedPercent: 48,
            commonMistake: 'Relied on acronyms without client contextualization',
          ),
        ],
        remediationAction: 'Practice plain-language technical translation drills.',
      ),
    ];
  }

  void _showDrillDownDialog(BuildContext context, LoMasteryItem item, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.all(24),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getTierColor(item.score).withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getTierColor(item.score).withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                item.score >= 80.0
                    ? Icons.check_circle_rounded
                    : item.score >= 60.0
                        ? Icons.trending_up_rounded
                        : Icons.warning_amber_rounded,
                color: _getTierColor(item.score),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.loCode,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.section,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkText : AppTheme.lightText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.loTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkText : AppTheme.lightText,
                    ),
                  ),
                  Text(
                    item.subject,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),

                // Overall Score Badge Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _getTierColor(item.score).withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getTierColor(item.score).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Average Student Score',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${item.score.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: _getTierColor(item.score),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _getTierColor(item.score),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.tier.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Students Assessed',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.assessedCount} total',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkText : AppTheme.lightText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Student Distribution Breakdown
                Text(
                  'Student Performance Distribution',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                  ),
                ),
                const SizedBox(height: 8),

                // Segmented distribution bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: item.masteredCount,
                        child: Container(
                          height: 10,
                          color: AppTheme.success,
                        ),
                      ),
                      Expanded(
                        flex: item.developingCount,
                        child: Container(
                          height: 10,
                          color: AppTheme.warning,
                        ),
                      ),
                      Expanded(
                        flex: item.atRiskCount,
                        child: Container(
                          height: 10,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Distribution Legend Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDistributionLegendItem(
                      label: 'Mastered (≥80%)',
                      count: item.masteredCount,
                      color: AppTheme.success,
                      isDark: isDark,
                    ),
                    _buildDistributionLegendItem(
                      label: 'Developing (60–79%)',
                      count: item.developingCount,
                      color: AppTheme.warning,
                      isDark: isDark,
                    ),
                    _buildDistributionLegendItem(
                      label: 'At-Risk (<60%)',
                      count: item.atRiskCount,
                      color: AppTheme.error,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Most-Missed Assessment Items
                Text(
                  'Most-Missed Assessment Items & Misconceptions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                  ),
                ),
                const SizedBox(height: 8),

                ...item.mostMissedItems.map((q) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${q.missedPercent}% missed',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.error,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                q.questionText,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.darkText : AppTheme.lightText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppTheme.warning),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Common Student Difficulty: ${q.commonMistake}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),

                // Targeted Remediation Recommendation
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Suggested Teaching Strategy',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.remediationAction,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkText : AppTheme.lightText,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Practice quiz assigned to ${item.section} (${item.loCode})!'),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.assignment_outlined, size: 15),
            label: const Text('Assign Review Quiz'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionLegendItem({
    required String label,
    required int count,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getTierColor(double score) {
    if (score >= 80.0) return AppTheme.success; // Emerald
    if (score >= 60.0) return AppTheme.warning; // Amber
    return AppTheme.error; // Rose
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final subjects = [
      'All Subjects',
      'Empowerment Technologies',
      'General Mathematics',
      'Oral Communication',
    ];

    // Filter data
    final filtered = _masteryData.where((item) {
      if (_selectedSubject != 'All Subjects' && item.subject != _selectedSubject) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = item.loCode.toLowerCase().contains(q) ||
            item.loTitle.toLowerCase().contains(q) ||
            item.section.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    // Collect unique sections and unique LOs
    final sections = ['11-STEM-A', '11-STEM-B', '11-ABM-A', '11-HUMSS-A', '12-TVL-ICT'];
    final loCodes = <String, String>{};
    for (final it in filtered) {
      loCodes[it.loCode] = it.loTitle;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title, Description, and Semantic Legend Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.table_chart_outlined, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Curriculum Competencies by Class Section',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkText : AppTheme.lightText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Overview of student performance across core competencies. Click any cell to view detailed assessment results and study topics.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Semantic Badges Legend & Controls Strip
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Legend: Proficient
              _buildSemanticBadge(
                label: 'Proficient (80%+)',
                bg: AppTheme.success.withValues(alpha: isDark ? 0.18 : 0.1),
                border: AppTheme.success.withValues(alpha: 0.35),
                textColor: AppTheme.success,
              ),
              // Legend: Developing
              _buildSemanticBadge(
                label: 'Developing (60% – 79%)',
                bg: AppTheme.warning.withValues(alpha: isDark ? 0.18 : 0.1),
                border: AppTheme.warning.withValues(alpha: 0.35),
                textColor: AppTheme.warning,
              ),
              // Legend: Needs Help
              _buildSemanticBadge(
                label: 'Needs Help (Below 60%)',
                bg: AppTheme.error.withValues(alpha: isDark ? 0.18 : 0.1),
                border: AppTheme.error.withValues(alpha: 0.35),
                textColor: AppTheme.error,
              ),

              const SizedBox(width: 10),

              // Subject Filter Dropdown
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSubject,
                      isDense: true,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(10),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkText : AppTheme.lightText,
                      ),
                      dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                      items: subjects.map((sub) {
                        return DropdownMenuItem(
                          value: sub,
                          child: Text(
                            sub,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSubject = val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Search Input
              Container(
                height: 34,
                width: 170,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkText : AppTheme.lightText,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search topic or class...',
                          hintStyle: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Interactive Heatmap Matrix Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
              ),
              horizontalMargin: 16,
              columnSpacing: 18,
              dataRowMinHeight: 60,
              dataRowMaxHeight: 68,
              border: TableBorder.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                borderRadius: BorderRadius.circular(10),
                width: 1,
              ),
              columns: [
                const DataColumn(
                  label: Text(
                    'LEARNING COMPETENCY',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                ...sections.map((sec) {
                  return DataColumn(
                    label: Text(
                      sec,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  );
                }),
                const DataColumn(
                  label: Text(
                    'Class Average',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: loCodes.keys.map((loKey) {
                final loTitle = loCodes[loKey] ?? '';

                // Calculate cohort average
                final itemsForLo = filtered.where((item) => item.loCode == loKey).toList();
                final avgScore = itemsForLo.isNotEmpty
                    ? itemsForLo.map((e) => e.score).reduce((a, b) => a + b) / itemsForLo.length
                    : 0.0;

                return DataRow(
                  cells: [
                    // LO Code & Title
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    loKey,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              loTitle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.darkText : AppTheme.lightText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Section Cells
                    ...sections.map((sec) {
                      final match = filtered.firstWhere(
                        (it) => it.loCode == loKey && it.section == sec,
                        orElse: () => LoMasteryItem(
                          loCode: loKey,
                          loTitle: loTitle,
                          subject: _selectedSubject,
                          section: sec,
                          score: 75.0,
                          assessedCount: 30,
                          masteredCount: 20,
                          developingCount: 7,
                          atRiskCount: 3,
                          mostMissedItems: [],
                          remediationAction: 'Standard review',
                        ),
                      );

                      final cellColor = _getTierColor(match.score);

                      return DataCell(
                        InkWell(
                          onTap: () => _showDrillDownDialog(context, match, isDark),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cellColor.withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: cellColor.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${match.score.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: cellColor,
                                  ),
                                ),
                                Text(
                                  match.tier,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: cellColor.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // Overall Cohort Average Cell
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getTierColor(avgScore).withValues(alpha: isDark ? 0.16 : 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getTierColor(avgScore).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${avgScore.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _getTierColor(avgScore),
                              ),
                            ),
                            Text(
                              avgScore >= 80 ? 'Mastered' : (avgScore >= 60 ? 'Developing' : 'At-Risk'),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: _getTierColor(avgScore),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemanticBadge({
    required String label,
    required Color bg,
    required Color border,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: textColor),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
