import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/components/analytics/analytics_components.dart';
import '../../data/student_repository.dart';

class StudentFourTierAnalyticsWidget extends ConsumerStatefulWidget {
  const StudentFourTierAnalyticsWidget({super.key});

  @override
  ConsumerState<StudentFourTierAnalyticsWidget> createState() =>
      _StudentFourTierAnalyticsWidgetState();
}

class _StudentFourTierAnalyticsWidgetState
    extends ConsumerState<StudentFourTierAnalyticsWidget> {
  int _diagnosticView =
      0; // 0: Subject Attainment Lollipop Bars, 1: Cognitive Bloom Radar

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analytics = ref.watch(studentFourTierAnalyticsProvider);
    final demoStudent = ref.watch(studentDemoAnalyticsProvider);

    final rawPassRate = (analytics['passRate'] as num?)?.toDouble() ?? 0.0;
    final passRate = rawPassRate > 0 ? rawPassRate : demoStudent.overallGrade.toDouble();
    final rawAvgScore = (analytics['avgScore'] as num?)?.toDouble() ?? 0.0;
    final avgScore = rawAvgScore > 0 ? rawAvgScore : demoStudent.overallGrade.toDouble();
    final rawTotalAttempts = (analytics['totalAttempts'] as num?)?.toInt() ?? 0;
    final totalAttempts = rawTotalAttempts > 0 ? rawTotalAttempts : demoStudent.completedQuizzes;
    final rawPassedAttempts = (analytics['passedAttempts'] as num?)?.toInt() ?? 0;
    final passedAttempts = rawPassedAttempts > 0 ? rawPassedAttempts : (totalAttempts * (passRate / 100)).round();
    final totalLos = (analytics['totalLos'] as num?)?.toInt() ?? 4;
    final completedLos = (analytics['completedLos'] as num?)?.toInt() ?? (passRate >= 75 ? 3 : 2);
    final loCompletionRate =
        (analytics['loCompletionRate'] as num?)?.toInt() ??
        (totalLos > 0 ? ((completedLos / totalLos) * 100).round() : 75);
    final onTimeSubs = (analytics['onTimeSubmissions'] as num?)?.toInt() ?? (passRate >= 75 ? 8 : 4);
    final totalSubs = (analytics['totalSubmissions'] as num?)?.toInt() ?? (passRate >= 75 ? 9 : 7);

    final subjectAttainments =
        (analytics['subjectAttainments'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final bloomsProfile =
        (analytics['bloomsProfile'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final trajectoryPoints =
        (analytics['trajectoryPoints'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final rawRecommendations =
        (analytics['recommendations'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    final rawProjected = (analytics['projectedScore'] as num?)?.toDouble() ?? 0.0;
    final projectedScore = rawProjected > 0 ? rawProjected : demoStudent.overallGrade.toDouble();
    final gradeLetter = analytics['gradeLetter'] as String? ?? (projectedScore >= 90 ? 'A' : (projectedScore >= 80 ? 'B' : (projectedScore >= 75 ? 'C' : 'D')));
    final riskLevel = analytics['riskLevel'] as String? ?? (projectedScore >= 75 ? 'Low Risk' : 'High Risk');

    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    // Palette inspired by reference image telemetry aesthetics
    const cyanColor = Color(0xFF06B6D4);
    const pinkColor = Color(0xFFF43F5E);
    const goldColor = Color(0xFFF59E0B);
    const emeraldColor = Color(0xFF10B981);

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactScreen = screenWidth < 480;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompactScreen ? 12 : 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompactScreen ? 6 : 8),
                decoration: BoxDecoration(
                  color: cyanColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  color: cyanColor,
                  size: isCompactScreen ? 18 : 20,
                ),
              ),
              SizedBox(width: isCompactScreen ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Learning Progress & Scores',
                      style: TextStyle(
                        fontSize: isCompactScreen ? 14.5 : 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.darkTextBright
                            : AppTheme.lightTextBright,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Check your quiz scores, subject strengths, expected final grade, and study tips',
                      style: TextStyle(
                        fontSize: isCompactScreen ? 11 : 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                      maxLines: isCompactScreen ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isCompactScreen ? 14 : 20),

          // Interactive Client Demo Sandbox Control Bar
          const AnalyticsDemoControlBar(
            showCampusFilter: false,
            showSectionFilter: false,
            showSubjectFilter: true,
          ),

          // Student Study Streak & Upcoming Milestone Callout
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cyanColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cyanColor.withValues(alpha: 0.25)),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      '3 Quizzes Passed in a row!',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextBright : AppTheme.lightTextBright,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📅', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'Next: General Math Quiz on Friday • 80% prepared',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 4-Tier Grid ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 780;

              // ── TIER 1: DESCRIPTIVE ──
              final tier1Card = _buildTierCard(
                isDark: isDark,
                isWide: isWide,
                tierBadge: 'Step 1: My Record',
                tierColor: cyanColor,
                title: 'How I\'m Doing So Far',
                icon: Icons.history_edu_rounded,
                child: AnalyticsConcentricDonut(
                  outerValue: passRate > 0
                      ? passRate
                      : (totalAttempts > 0 ? 0.0 : 80.0),
                  innerValue: loCompletionRate.toDouble() > 0
                      ? loCompletionRate.toDouble()
                      : 45.0,
                  outerColor: cyanColor,
                  innerColor: goldColor,
                  centerValue:
                      '${passRate > 0 ? passRate.round() : (totalAttempts > 0 ? 0 : 80)}%',
                  centerLabel: 'Overall',
                  size: isWide ? 150 : 105,
                  isDark: isDark,
                  stats: [
                    ConcentricStat(
                      label: 'Quizzes Passed',
                      value: '${passRate.round()}%',
                      color: cyanColor,
                      subtitle: '$passedAttempts of $totalAttempts passed',
                    ),
                    ConcentricStat(
                      label: 'Quiz Average',
                      value: '${avgScore.round()}%',
                      color: pinkColor,
                      subtitle: 'Average quiz score',
                    ),
                    ConcentricStat(
                      label: 'Lessons Done',
                      value: '$completedLos/$totalLos',
                      color: goldColor,
                      subtitle: '$completedLos of $totalLos mastered',
                    ),
                    ConcentricStat(
                      label: 'On-Time Work',
                      value: '$onTimeSubs/${totalSubs > 0 ? totalSubs : 0}',
                      color: emeraldColor,
                      subtitle: 'Submitted on time',
                    ),
                  ],
                ),
              );

              // ── TIER 2: DIAGNOSTIC ──
              final lollipopColors = [
                cyanColor,
                pinkColor,
                goldColor,
                emeraldColor,
                const Color(0xFF8B5CF6),
                const Color(0xFF84CC16),
              ];

              final gradeFactor = demoStudent.overallGrade / 82.0;

              final defaultCurriculum = [
                {
                  'name': 'Oral Communication in Context',
                  'code': 'CORE-01',
                  'avgScore': (82.0 * gradeFactor).clamp(40.0, 98.0),
                  'totalLos': 4,
                  'completedLos': (3 * gradeFactor).round().clamp(1, 4),
                },
                {
                  'name': 'Reading and Writing Skills',
                  'code': 'CORE-02',
                  'avgScore': (86.0 * gradeFactor).clamp(40.0, 99.0),
                  'totalLos': 4,
                  'completedLos': (4 * gradeFactor).round().clamp(1, 4),
                },
                {
                  'name': 'General Mathematics',
                  'code': 'CORE-03',
                  'avgScore': (74.0 * gradeFactor).clamp(35.0, 96.0),
                  'totalLos': 4,
                  'completedLos': (2 * gradeFactor).round().clamp(1, 4),
                },
                {
                  'name': 'Earth and Life Science',
                  'code': 'CORE-04',
                  'avgScore': (88.0 * gradeFactor).clamp(40.0, 99.0),
                  'totalLos': 4,
                  'completedLos': (3 * gradeFactor).round().clamp(1, 4),
                },
                {
                  'name': 'Physical Science & Inquiry',
                  'code': 'CORE-05',
                  'avgScore': (78.0 * gradeFactor).clamp(38.0, 95.0),
                  'totalLos': 4,
                  'completedLos': (2 * gradeFactor).round().clamp(1, 4),
                },
              ];

              final effectiveSubjects = subjectAttainments.length >= 4
                  ? subjectAttainments
                  : [
                      ...subjectAttainments,
                      ...defaultCurriculum.where((d) => !subjectAttainments.any((s) => (s['code'] ?? '') == d['code'])).take(5 - subjectAttainments.length),
                    ];

              final lollipopItems = effectiveSubjects
                  .asMap()
                  .entries
                  .map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    final name = (s['name'] as String? ?? 'Subject').trim();
                    final code = (s['code'] as String? ?? '').trim();
                    final score =
                        (s['avgScore'] as num?)?.toDouble() ?? 75.0;
                    final color =
                        lollipopColors[idx % lollipopColors.length];
                    final compL = s['completedLos'] ?? 0;
                    final totL = s['totalLos'] ?? 4;
                    final badge = score >= 85
                        ? '⭐ Mastered'
                        : (score >= 75 ? '✅ Passing' : '🔄 Needs Practice');

                    return LollipopItem(
                      label: code.isNotEmpty ? '$code • $name' : name,
                      subtitle:
                          '$compL of $totL Lessons completed',
                      value: score,
                      color: color,
                      badgeText: badge,
                    );
                  })
                  .toList();

              final radarDims =
                  (bloomsProfile.isNotEmpty
                          ? bloomsProfile
                          : [
                              {'label': 'Recalling Facts', 'value': (80.0 * gradeFactor).clamp(40.0, 98.0)},
                              {'label': 'Understanding Lessons', 'value': (75.0 * gradeFactor).clamp(40.0, 96.0)},
                              {'label': 'Solving Problems', 'value': (70.0 * gradeFactor).clamp(35.0, 95.0)},
                              {'label': 'Connecting Ideas', 'value': (65.0 * gradeFactor).clamp(35.0, 92.0)},
                              {'label': 'Checking & Judging', 'value': (60.0 * gradeFactor).clamp(30.0, 90.0)},
                              {'label': 'Creative Projects', 'value': (58.0 * gradeFactor).clamp(30.0, 88.0)},
                            ])
                      .map((b) {
                        return RadarDimension(
                          label: b['label'] as String? ?? '',
                          value: (b['value'] as num?)?.toDouble() ?? 70.0,
                        );
                      })
                      .toList();

              final tier2Card = _buildTierCard(
                isDark: isDark,
                isWide: isWide,
                tierBadge: 'Step 2: Strengths',
                tierColor: goldColor,
                title: 'Subject Strengths & Skills Check',
                icon: Icons.troubleshoot_rounded,
                action: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _diagnosticView = 0),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _diagnosticView == 0
                                ? (isDark
                                      ? const Color(0xFF334155)
                                      : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: _diagnosticView == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            '📚 Subjects',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: _diagnosticView == 0
                                  ? (isDark
                                        ? Colors.white
                                        : AppTheme.lightTextBright)
                                  : (isDark
                                        ? AppTheme.darkTextMuted
                                        : AppTheme.lightTextMuted),
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _diagnosticView = 1),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _diagnosticView == 1
                                ? (isDark
                                      ? const Color(0xFF334155)
                                      : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: _diagnosticView == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            '🧠 Thinking Skills',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: _diagnosticView == 1
                                  ? (isDark
                                        ? Colors.white
                                        : AppTheme.lightTextBright)
                                  : (isDark
                                        ? AppTheme.darkTextMuted
                                        : AppTheme.lightTextMuted),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                child: _diagnosticView == 0
                    ? AnalyticsLollipopChart(
                        items: lollipopItems.take(isWide ? 5 : 3).toList(),
                        maxValue: 100.0,
                        baselineValue: 75.0,
                        baselineLabel: 'Passing Mark (75%)',
                        isDark: isDark,
                      )
                    : AnalyticsRadarChart(
                        dimensions: radarDims,
                        secondaryDimensions: const [
                          RadarDimension(label: 'Recalling Facts', value: 75.0),
                          RadarDimension(label: 'Understanding Lessons', value: 75.0),
                          RadarDimension(label: 'Solving Problems', value: 75.0),
                          RadarDimension(label: 'Connecting Ideas', value: 75.0),
                          RadarDimension(label: 'Checking & Judging', value: 75.0),
                          RadarDimension(label: 'Creative Projects', value: 75.0),
                        ],
                        size: isWide ? 210 : 160,
                        isDark: isDark,
                        color: goldColor,
                        secondaryColor: cyanColor,
                        showBreakdownList: isWide,
                        primaryLegend: 'My Score',
                        secondaryLegend: 'Passing Mark (75%)',
                      ),
              );

              // ── TIER 3: PREDICTIVE ──
              final trendPoints = (trajectoryPoints.isNotEmpty
                      ? trajectoryPoints
                      : demoStudent.myScoreHistory.map((p) => {'label': p.label, 'value': p.value}).toList())
                  .map((tp) {
                    return TrendPoint(
                      label: tp['label'] as String? ?? '',
                      value: (tp['value'] as num?)?.toDouble() ?? 75.0,
                    );
                  })
                  .toList();

              final friendlyRiskStatus = riskLevel.contains('Low')
                  ? 'Safe to Pass ✅'
                  : (riskLevel.contains('Moderate')
                      ? 'Needs Attention ⚠️'
                      : 'At Risk of Failing 🚨');

              final tier3Card = _buildTierCard(
                isDark: isDark,
                isWide: isWide,
                tierBadge: 'Step 3: Expected Grade',
                tierColor: pinkColor,
                title: 'Expected Final Grade & Passing Outlook',
                icon: Icons.trending_up_rounded,
                child: isWide
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AnalyticsGaugeMeter(
                                value: projectedScore,
                                label: 'Expected: $gradeLetter',
                                statusText: friendlyRiskStatus,
                                size: 155,
                                isDark: isDark,
                                customColor: projectedScore >= 80
                                    ? emeraldColor
                                    : (projectedScore >= 70 ? goldColor : pinkColor),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: AnalyticsTrendChart(
                                  points: trendPoints,
                                  height: 190,
                                  baselineY: 75.0,
                                  baselineLabel: 'Passing Mark (75%)',
                                  isDark: isDark,
                                  lineColor: cyanColor,
                                  showDots: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildMetricChip(
                                isDark,
                                'Expected Grade',
                                '${projectedScore.round()}% ($gradeLetter)',
                                emeraldColor,
                              ),
                              _buildMetricChip(
                                isDark,
                                'Passing Status',
                                friendlyRiskStatus,
                                riskLevel.contains('Low') ? emeraldColor : pinkColor,
                              ),
                              _buildMetricChip(
                                isDark,
                                'Term Outlook',
                                'On Track to Pass (75%+)',
                                cyanColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildMasteryPaceBanner(isDark, projectedScore, cyanColor),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Mobile Layout: Gauge on left, 3 compact metric rows on right
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AnalyticsGaugeMeter(
                                value: projectedScore,
                                label: 'Expected: $gradeLetter',
                                statusText: friendlyRiskStatus,
                                size: 105,
                                isDark: isDark,
                                customColor: projectedScore >= 80
                                    ? emeraldColor
                                    : (projectedScore >= 70 ? goldColor : pinkColor),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildCompactMetricRow(
                                      isDark: isDark,
                                      label: 'Expected Grade',
                                      value: '${projectedScore.round()}% ($gradeLetter)',
                                      color: emeraldColor,
                                    ),
                                    const SizedBox(height: 5),
                                    _buildCompactMetricRow(
                                      isDark: isDark,
                                      label: 'Passing Status',
                                      value: friendlyRiskStatus,
                                      color: riskLevel.contains('Low') ? emeraldColor : pinkColor,
                                    ),
                                    const SizedBox(height: 5),
                                    _buildCompactMetricRow(
                                      isDark: isDark,
                                      label: 'Term Outlook',
                                      value: 'On Track to Pass',
                                      color: cyanColor,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Full-Width Trend Chart: curves have full card width, 0 collision, 0 overflow
                          AnalyticsTrendChart(
                            points: trendPoints,
                            height: 125,
                            baselineY: 75.0,
                            baselineLabel: 'Passing Mark (75%)',
                            isDark: isDark,
                            lineColor: cyanColor,
                            showDots: true,
                          ),
                          const SizedBox(height: 10),
                          _buildMasteryPaceBanner(isDark, projectedScore, cyanColor, isCompact: true),
                        ],
                      ),
              );

              // ── TIER 4: PRESCRIPTIVE ──
              final fallbackDirectives = demoStudent.overallGrade < 75
                  ? [
                      {
                        'title': '🚨 Urgent: Retake General Mathematics Quiz',
                        'description':
                            'Your average in General Math is below the 75% passing threshold. Take the remedial quiz window to lift your standing.',
                        'badge': '⚡ High Priority',
                        'priority': 'critical',
                        'actionLabel': 'Start Retake',
                        'actionType': 'start_quiz',
                      },
                      {
                        'title': '📖 Review Polynomial Factoring Flashcards',
                        'description':
                            'Study the Topic 3 summary cards downloaded from your classroom hub node.',
                        'badge': '📖 Flashcards',
                        'priority': 'warning',
                        'actionLabel': 'Open Flashcards',
                        'actionType': 'open_modules',
                      },
                      {
                        'title': '💾 Synchronize Offline Study Pack',
                        'description':
                            'Connect to your classroom ESP32 hub box to get updated practice worksheets.',
                        'badge': '💾 Offline Hub',
                        'priority': 'routine',
                        'actionLabel': 'Download Files',
                        'actionType': 'open_hub',
                      },
                    ]
                  : [
                      {
                        'title': '📝 Take Waiting Quiz',
                        'description':
                            'You have quizzes ready in your class section. Complete them now to raise your expected grade!',
                        'badge': '⚡ Due Soon',
                        'priority': 'critical',
                        'actionLabel': 'Start Quiz',
                        'actionType': 'start_quiz',
                      },
                      {
                        'title': '📖 Read Next Lesson Modules',
                        'description':
                            'Advance your lesson topics to prepare for upcoming tests and quarterly exams.',
                        'badge': '📖 Lessons',
                        'priority': 'recommended',
                        'actionLabel': 'Open Lessons',
                        'actionType': 'open_modules',
                      },
                      {
                        'title': '💾 Download Offline Study Packs',
                        'description':
                            'Save lesson flashcards and study packs from your classroom hub box so you can study offline at home.',
                        'badge': '💾 Offline',
                        'priority': 'routine',
                        'actionLabel': 'Download Files',
                        'actionType': 'open_hub',
                      },
                    ];

              final effectiveRecommendations = rawRecommendations.isNotEmpty
                  ? rawRecommendations
                  : fallbackDirectives;

              final tier4Card = _buildTierCard(
                isDark: isDark,
                isWide: isWide,
                tierBadge: 'Step 4: What To Do Next',
                tierColor: emeraldColor,
                title: 'Recommended Steps to Improve',
                icon: Icons.lightbulb_outline_rounded,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: effectiveRecommendations.take(3).map((rec) {
                    final priorityStr =
                        rec['priority'] as String? ?? 'recommended';
                    PrescriptionPriority priority = PrescriptionPriority.recommended;
                    if (priorityStr == 'warning') {
                      priority = PrescriptionPriority.warning;
                    } else if (priorityStr == 'critical') {
                      priority = PrescriptionPriority.critical;
                    } else if (priorityStr == 'routine') {
                      priority = PrescriptionPriority.routine;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PrescriptiveActionCard(
                        title: rec['title'] as String? ?? 'Action Directive',
                        description: rec['description'] as String? ?? '',
                        badgeText: rec['badge'] as String? ?? 'Directive',
                        actionLabel: rec['actionLabel'] as String? ?? 'Open',
                        priority: priority,
                        isDark: isDark,
                        onAction: () {
                          final type = rec['actionType'] as String?;
                          if (type == 'start_quiz') {
                            context.go('/student/quizzes');
                          } else if (type == 'open_course') {
                            final sId = rec['subjectId'];
                            if (sId != null) {
                              context.go('/student/courses/$sId');
                            } else {
                              context.go('/student/courses');
                            }
                          } else if (type == 'open_modules') {
                            context.go('/student/courses');
                          } else if (type == 'open_hub') {
                            context.go('/student');
                          } else {
                            context.go('/student/courses');
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              );

              if (isWide) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: tier1Card),
                        const SizedBox(width: 16),
                        Expanded(child: tier2Card),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: tier3Card),
                        const SizedBox(width: 16),
                        Expanded(child: tier4Card),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  tier1Card,
                  const SizedBox(height: 14),
                  tier2Card,
                  const SizedBox(height: 14),
                  tier3Card,
                  const SizedBox(height: 14),
                  tier4Card,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required bool isDark,
    required bool isWide,
    required String tierBadge,
    required Color tierColor,
    required String title,
    required IconData icon,
    Widget? action,
    required Widget child,
  }) {
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF1E293B) : AppTheme.lightBorder;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: isWide ? 250 : 130),
      padding: EdgeInsets.all(isWide ? 16 : 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tierBadge.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: tierColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 16, color: tierColor),
                ],
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: isWide ? 13.5 : 12.5,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppTheme.darkTextBright
                  : AppTheme.lightTextBright,
            ),
          ),
          SizedBox(height: isWide ? 12 : 10),
          child,
        ],
      ),
    );
  }

  Widget _buildCompactMetricRow({
    required bool isDark,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryPaceBanner(bool isDark, double projectedScore, Color cyanColor, {bool isCompact = false}) {
    final diff = projectedScore - 75;
    final diffStr = diff >= 0 ? '+${diff.toStringAsFixed(1)}%' : '${diff.toStringAsFixed(1)}%';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: isCompact ? 7 : 8),
      decoration: BoxDecoration(
        color: cyanColor.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cyanColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_graph_rounded, size: isCompact ? 15 : 16, color: cyanColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isCompact
                  ? 'Great job! You are $diffStr relative to passing. Keep answering quizzes to stay ahead!'
                  : 'Great job! You are $diffStr relative to the 75% passing mark. Consistent quiz completion keeps you safe to pass.',
              style: TextStyle(
                fontSize: isCompact ? 10.5 : 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : AppTheme.lightTextSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    bool isDark,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
