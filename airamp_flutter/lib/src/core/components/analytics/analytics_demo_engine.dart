import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'analytics_bar_chart.dart';
import 'analytics_trend_chart.dart';
import 'analytics_multi_line_chart.dart';

/// Available Demo Scenarios that the client can manipulate to validate visualization behavior.
enum DemoScenario {
  standard('Standard Academic Benchmark', 'Normal operational metrics across all institutional scopes.'),
  highPerforming('High Performing (Honor Cohort)', '92%+ pass rates, high subject mastery, and low intervention rates.'),
  atRisk('At-Risk / Capacity Alert', 'Significant drop in pass rates, strained faculty ratios, and urgent interventions.'),
  midtermPeak('Midterm Examination Peak', 'Heavy attempt spikes, high server/node load, and score distribution shifts.');

  final String label;
  final String description;
  const DemoScenario(this.label, this.description);
}

class AnalyticsDemoFilterState {
  final bool isDemoMode;
  final DemoScenario scenario;
  final String academicYear;
  final String month;
  final String campusId;
  final String section;
  final String subject;

  const AnalyticsDemoFilterState({
    this.isDemoMode = true,
    this.scenario = DemoScenario.standard,
    this.academicYear = 'AY 2025-2026',
    this.month = 'All Months',
    this.campusId = 'all',
    this.section = 'All Handled Sections',
    this.subject = 'All Subjects',
  });

  AnalyticsDemoFilterState copyWith({
    bool? isDemoMode,
    DemoScenario? scenario,
    String? academicYear,
    String? month,
    String? campusId,
    String? section,
    String? subject,
  }) {
    return AnalyticsDemoFilterState(
      isDemoMode: isDemoMode ?? this.isDemoMode,
      scenario: scenario ?? this.scenario,
      academicYear: academicYear ?? this.academicYear,
      month: month ?? this.month,
      campusId: campusId ?? this.campusId,
      section: section ?? this.section,
      subject: subject ?? this.subject,
    );
  }
}

class AnalyticsDemoFilterNotifier extends Notifier<AnalyticsDemoFilterState> {
  @override
  AnalyticsDemoFilterState build() => const AnalyticsDemoFilterState();

  void setScenario(DemoScenario scenario) => state = state.copyWith(scenario: scenario);
  void setYear(String year) => state = state.copyWith(academicYear: year);
  void setMonth(String month) => state = state.copyWith(month: month);
  void setCampus(String campusId) => state = state.copyWith(campusId: campusId);
  void setSection(String section) => state = state.copyWith(section: section);
  void setSubject(String subject) => state = state.copyWith(subject: subject);
  void toggleDemoMode(bool enabled) => state = state.copyWith(isDemoMode: enabled);
  void reset() => state = const AnalyticsDemoFilterState();
}

final analyticsDemoFilterProvider =
    NotifierProvider<AnalyticsDemoFilterNotifier, AnalyticsDemoFilterState>(AnalyticsDemoFilterNotifier.new);

// ── SUPER ADMIN DATA MODEL & COMPUTATION ────────────────────────────────────

class SuperAdminDemoAnalytics {
  final int totalStudents;
  final int totalTeachers;
  final int totalAdmins;
  final int totalCampuses;
  final int totalHubNodes;
  final String studentTeacherRatio;
  final int overallPassRate;
  final List<BarChartItem> campusComparisonBars;
  final List<LineSeries> networkGrowthSeries;

  const SuperAdminDemoAnalytics({
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalAdmins,
    required this.totalCampuses,
    required this.totalHubNodes,
    required this.studentTeacherRatio,
    required this.overallPassRate,
    required this.campusComparisonBars,
    required this.networkGrowthSeries,
  });
}

final superAdminDemoAnalyticsProvider = Provider<SuperAdminDemoAnalytics>((ref) {
  final filter = ref.watch(analyticsDemoFilterProvider);
  final yearMult = filter.academicYear == 'AY 2025-2026' ? 1.15 : (filter.academicYear == 'AY 2024-2025' ? 1.0 : 0.85);

  double scenarioMult = 1.0;
  int passRate = 84;
  int facultyDeficit = 0;

  switch (filter.scenario) {
    case DemoScenario.highPerforming:
      scenarioMult = 1.25;
      passRate = 93;
      break;
    case DemoScenario.atRisk:
      scenarioMult = 0.82;
      passRate = 62;
      facultyDeficit = -14;
      break;
    case DemoScenario.midtermPeak:
      scenarioMult = 1.10;
      passRate = 79;
      break;
    case DemoScenario.standard:
      scenarioMult = 1.0;
      passRate = 84;
      break;
  }

  final campuses = [
    {
      'id': 'sch_main',
      'name': 'Main Campus',
      'students': (960 * yearMult * scenarioMult).round(),
      'teachers': 48 + facultyDeficit,
      'admins': 12,
    },
    {
      'id': 'sch_north',
      'name': 'North Campus',
      'students': (620 * yearMult * scenarioMult).round(),
      'teachers': 32 + (facultyDeficit ~/ 2),
      'admins': 8,
    },
    {
      'id': 'sch_west',
      'name': 'West Branch',
      'students': (480 * yearMult * scenarioMult).round(),
      'teachers': 24 + facultyDeficit,
      'admins': 6,
    },
    {
      'id': 'sch_south',
      'name': 'South Extension',
      'students': (340 * yearMult * scenarioMult).round(),
      'teachers': 18,
      'admins': 5,
    },
  ];

  final filteredCampuses = filter.campusId == 'all'
      ? campuses
      : campuses.where((c) => c['id'] == filter.campusId).toList();

  final totStudents = filteredCampuses.fold<int>(0, (sum, c) => sum + (c['students'] as int));
  final totTeachers = filteredCampuses.fold<int>(0, (sum, c) => sum + (c['teachers'] as int));
  final totAdmins = filteredCampuses.fold<int>(0, (sum, c) => sum + (c['admins'] as int));
  final ratioStr = totTeachers > 0 ? (totStudents / totTeachers).toStringAsFixed(1) : '0';

  // Multi-campus comparison bars (Triple grouped: Students, Teachers, Admins)
  final comparisonBars = filteredCampuses.map((c) {
    final sCount = (c['students'] as int).toDouble();
    final tCount = (c['teachers'] as int).toDouble();
    final aCount = (c['admins'] as int).toDouble();
    return BarChartItem(
      label: c['name'] as String,
      value: sCount,
      secondaryValue: tCount,
      tertiaryValue: aCount,
      color: const Color(0xFF0D9488), // Teal = Students
      secondaryColor: const Color(0xFF0284C7), // Blue = Faculty
      tertiaryColor: const Color(0xFF8B5CF6), // Purple = Admins
      tooltip: '${c['name']}: ${sCount.toInt()} Students, ${tCount.toInt()} Faculty, ${aCount.toInt()} Admins',
    );
  }).toList();

  // Multi-line monthly user growth over time
  final months = ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May'];
  final studentPoints = <TrendPoint>[];
  final teacherPoints = <TrendPoint>[];
  final attemptPoints = <TrendPoint>[];

  double baseSt = 1600 * yearMult;
  double baseTc = 95;
  double baseAtt = 2400;

  for (int i = 0; i < months.length; i++) {
    final m = months[i];
    if (m == 'Aug') baseSt += 400 * scenarioMult;
    if (m == 'Sep') baseSt += 150 * scenarioMult;
    if (m == 'Jan') baseSt += 80 * scenarioMult;

    if (m == 'Aug') baseTc += 15;
    if (m == 'Jan') baseTc += 5;

    double attFactor = 1.0;
    if (filter.scenario == DemoScenario.midtermPeak && (m == 'Oct' || m == 'Mar')) {
      attFactor = 2.4; // Midterm exam surge!
    } else if (m == 'Oct' || m == 'Mar') {
      attFactor = 1.8;
    } else if (m == 'Dec') {
      attFactor = 0.6; // Holiday break
    }

    studentPoints.add(TrendPoint(label: m, value: (baseSt * (1 + (i * 0.015))).roundToDouble()));
    teacherPoints.add(TrendPoint(label: m, value: baseTc));
    attemptPoints.add(TrendPoint(label: m, value: (baseAtt * attFactor * scenarioMult).roundToDouble()));
  }

  // Filter by single month if requested
  List<LineSeries> networkGrowthSeries;
  if (filter.month != 'All Months') {
    final targetMonth = filter.month.substring(0, 3);
    final sP = studentPoints.where((p) => p.label == targetMonth).toList();
    final tP = teacherPoints.where((p) => p.label == targetMonth).toList();
    final aP = attemptPoints.where((p) => p.label == targetMonth).toList();
    networkGrowthSeries = [
      LineSeries(name: 'Enrolled Students', color: const Color(0xFF0D9488), points: sP.isNotEmpty ? sP : studentPoints, showArea: true),
      LineSeries(name: 'Active Faculty', color: const Color(0xFF0284C7), points: tP.isNotEmpty ? tP : teacherPoints),
      LineSeries(name: 'Monthly Attempts (÷10)', color: const Color(0xFFF59E0B), points: (aP.isNotEmpty ? aP : attemptPoints).map((p) => TrendPoint(label: p.label, value: p.value / 10)).toList()),
    ];
  } else {
    networkGrowthSeries = [
      LineSeries(name: 'Enrolled Students', color: const Color(0xFF0D9488), points: studentPoints, showArea: true),
      LineSeries(name: 'Active Faculty', color: const Color(0xFF0284C7), points: teacherPoints),
      LineSeries(name: 'Monthly Attempts (÷10)', color: const Color(0xFFF59E0B), points: attemptPoints.map((p) => TrendPoint(label: p.label, value: p.value / 10)).toList()),
    ];
  }

  return SuperAdminDemoAnalytics(
    totalStudents: totStudents,
    totalTeachers: totTeachers,
    totalAdmins: totAdmins,
    totalCampuses: filteredCampuses.length,
    totalHubNodes: filteredCampuses.length * 3 + 2,
    studentTeacherRatio: ratioStr,
    overallPassRate: passRate,
    campusComparisonBars: comparisonBars,
    networkGrowthSeries: networkGrowthSeries,
  );
});

// ── CAMPUS ADMIN DATA MODEL & COMPUTATION ───────────────────────────────────

class CampusAdminDemoAnalytics {
  final int totalStudents;
  final int totalTeachers;
  final int totalEnrollments;
  final int overallPassRate;
  final int averageScore;
  final List<BarChartItem> sectionComparisonBars;
  final List<LineSeries> monthlyAttemptSeries;
  final List<BarChartItem> gradeDistributionBars;
  final Map<String, int> demographics;

  const CampusAdminDemoAnalytics({
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalEnrollments,
    required this.overallPassRate,
    required this.averageScore,
    required this.sectionComparisonBars,
    required this.monthlyAttemptSeries,
    required this.gradeDistributionBars,
    required this.demographics,
  });
}

final campusAdminDemoAnalyticsProvider = Provider<CampusAdminDemoAnalytics>((ref) {
  final filter = ref.watch(analyticsDemoFilterProvider);

  double scenarioMult = 1.0;
  int basePassRate = 82;
  int baseAvgScore = 81;

  switch (filter.scenario) {
    case DemoScenario.highPerforming:
      scenarioMult = 1.15;
      basePassRate = 94;
      baseAvgScore = 89;
      break;
    case DemoScenario.atRisk:
      scenarioMult = 0.85;
      basePassRate = 64;
      baseAvgScore = 67;
      break;
    case DemoScenario.midtermPeak:
      scenarioMult = 1.30;
      basePassRate = 78;
      baseAvgScore = 77;
      break;
    case DemoScenario.standard:
      scenarioMult = 1.0;
      basePassRate = 82;
      baseAvgScore = 81;
      break;
  }

  // Section comparison breakdown
  final sections = [
    {'name': '10-Einstein', 'students': 42, 'score': (88.0 * (baseAvgScore / 81)).clamp(50.0, 98.0), 'passRate': (95.0 * (basePassRate / 82)).clamp(45.0, 100.0)},
    {'name': '10-Newton', 'students': 39, 'score': (82.0 * (baseAvgScore / 81)).clamp(50.0, 98.0), 'passRate': (86.0 * (basePassRate / 82)).clamp(45.0, 100.0)},
    {'name': '10-Curie', 'students': 41, 'score': (76.0 * (baseAvgScore / 81)).clamp(50.0, 98.0), 'passRate': (78.0 * (basePassRate / 82)).clamp(45.0, 100.0)},
    {'name': '10-Tesla', 'students': 38, 'score': (84.0 * (baseAvgScore / 81)).clamp(50.0, 98.0), 'passRate': (89.0 * (basePassRate / 82)).clamp(45.0, 100.0)},
    {'name': '10-Darwin', 'students': 40, 'score': (68.0 * (baseAvgScore / 81)).clamp(50.0, 98.0), 'passRate': (65.0 * (basePassRate / 82)).clamp(45.0, 100.0)},
  ];

  final filteredSections = filter.section == 'All Handled Sections' || filter.section == 'All Sections'
      ? sections
      : sections.where((s) => (s['name'] as String).contains(filter.section.replaceAll(' ', ''))).toList();

  final effectiveSections = filteredSections.isNotEmpty ? filteredSections : sections;

  final sectionBars = effectiveSections.map((s) {
    final name = s['name'] as String;
    final sc = (s['score'] as double);
    final pr = (s['passRate'] as double);
    return BarChartItem(
      label: name.replaceAll('10-', ''),
      value: sc,
      secondaryValue: pr,
      color: const Color(0xFF0D9488),
      secondaryColor: const Color(0xFF0284C7),
      tooltip: '$name: Avg Score ${sc.toStringAsFixed(1)}%, Pass Rate ${pr.toStringAsFixed(0)}%',
    );
  }).toList();

  // Monthly activity trajectory
  final months = ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May'];
  final attemptPoints = <TrendPoint>[];
  final activeStudentPoints = <TrendPoint>[];

  for (int i = 0; i < months.length; i++) {
    final m = months[i];
    double peak = 1.0;
    if (m == 'Oct' || m == 'Mar') peak = 1.7 * scenarioMult;
    if (m == 'Dec') peak = 0.55;

    attemptPoints.add(TrendPoint(label: m, value: (680 * peak).roundToDouble()));
    activeStudentPoints.add(TrendPoint(label: m, value: (195 + (i * 2.5)).roundToDouble()));
  }

  // Grade Distribution Histogram
  final gradeBars = [
    BarChartItem(label: '90-100%', value: filter.scenario == DemoScenario.highPerforming ? 42 : (filter.scenario == DemoScenario.atRisk ? 12 : 28), color: const Color(0xFF10B981)),
    BarChartItem(label: '80-89%', value: filter.scenario == DemoScenario.highPerforming ? 44 : (filter.scenario == DemoScenario.atRisk ? 28 : 42), color: const Color(0xFF0EA5E9)),
    BarChartItem(label: '75-79%', value: filter.scenario == DemoScenario.atRisk ? 32 : 18, color: const Color(0xFFF59E0B)),
    BarChartItem(label: '<75%', value: filter.scenario == DemoScenario.atRisk ? 28 : (filter.scenario == DemoScenario.highPerforming ? 2 : 12), color: const Color(0xFFEF4444)),
  ];

  return CampusAdminDemoAnalytics(
    totalStudents: (860 * scenarioMult).round(),
    totalTeachers: 42,
    totalEnrollments: (1240 * scenarioMult).round(),
    overallPassRate: basePassRate,
    averageScore: baseAvgScore,
    sectionComparisonBars: sectionBars,
    monthlyAttemptSeries: [
      LineSeries(name: 'Quiz Attempts', color: const Color(0xFF0D9488), points: attemptPoints, showArea: true),
      LineSeries(name: 'Active Learners', color: const Color(0xFF0284C7), points: activeStudentPoints),
    ],
    gradeDistributionBars: gradeBars,
    demographics: {
      'regular': (710 * scenarioMult).round(),
      'irregular': 82,
      'transferee': 45,
      'sped': 23,
      'unassigned': 0,
    },
  );
});

// ── TEACHER DATA MODEL & COMPUTATION ────────────────────────────────────────

class TeacherDemoAnalytics {
  final int totalStudents;
  final int classAverage;
  final int classPassRate;
  final List<LineSeries> classAssessmentTrajectory;
  final List<BarChartItem> topicMasteryBars;
  final List<Map<String, dynamic>> atRiskStudents;
  final List<Map<String, dynamic>> actionRecommendations;

  const TeacherDemoAnalytics({
    required this.totalStudents,
    required this.classAverage,
    required this.classPassRate,
    required this.classAssessmentTrajectory,
    required this.topicMasteryBars,
    required this.atRiskStudents,
    required this.actionRecommendations,
  });
}

final teacherDemoAnalyticsProvider = Provider<TeacherDemoAnalytics>((ref) {
  final filter = ref.watch(analyticsDemoFilterProvider);

  int avg = 82;
  int pass = 86;
  if (filter.scenario == DemoScenario.highPerforming) {
    avg = 91;
    pass = 96;
  } else if (filter.scenario == DemoScenario.atRisk) {
    avg = 65;
    pass = 61;
  }

  // Quiz-by-quiz performance line
  final assessments = [
    TrendPoint(label: 'Diag', value: (avg - 14.0).clamp(40.0, 95.0)),
    TrendPoint(label: 'Quiz 1', value: (avg - 6.0).clamp(45.0, 96.0)),
    TrendPoint(label: 'Quiz 2', value: (avg - 2.0).clamp(45.0, 98.0)),
    TrendPoint(label: 'Midterm', value: (avg + 4.0).clamp(50.0, 99.0)),
    TrendPoint(label: 'Quiz 3', value: (avg - 3.0).clamp(45.0, 97.0)),
    TrendPoint(label: 'Quiz 4', value: (avg + 5.0).clamp(50.0, 100.0)),
  ];

  // Topic mastery bar items
  final topicBars = [
    BarChartItem(label: 'Algebra', value: (avg + 6.0).clamp(45.0, 98.0), color: const Color(0xFF10B981)),
    BarChartItem(label: 'Equations', value: (avg + 2.0).clamp(45.0, 96.0), color: const Color(0xFF0EA5E9)),
    BarChartItem(label: 'Functions', value: (avg - 8.0).clamp(35.0, 92.0), color: const Color(0xFFF59E0B)),
    BarChartItem(label: 'Polynomials', value: (avg - 12.0).clamp(30.0, 90.0), color: const Color(0xFFEF4444)),
    BarChartItem(label: 'Word Probs', value: (avg - 2.0).clamp(40.0, 95.0), color: const Color(0xFF8B5CF6)),
  ];

  final atRiskList = filter.scenario == DemoScenario.atRisk
      ? [
          {'name': 'Marcus Vance', 'grade': '58%', 'gap': 'Polynomials & Functions', 'missed': 3},
          {'name': 'Sophia Reyes', 'grade': '64%', 'gap': 'Word Problem Application', 'missed': 2},
          {'name': 'Liam Santos', 'grade': '68%', 'gap': 'Quadratic Formulations', 'missed': 1},
          {'name': 'Chloe Bautista', 'grade': '71%', 'gap': 'Quiz 3 Retake Required', 'missed': 1},
        ]
      : [
          {'name': 'Marcus Vance', 'grade': '68%', 'gap': 'Polynomials Review', 'missed': 1},
          {'name': 'Liam Santos', 'grade': '72%', 'gap': 'Functions Homework Pending', 'missed': 0},
        ];

  final actions = [
    {
      'title': 'Schedule Remedial Workshop: Polynomials',
      'subtitle': '${filter.scenario == DemoScenario.atRisk ? "14" : "5"} students scored below 70% in factoring polynomials.',
      'urgency': 'High Priority',
      'color': const Color(0xFFEF4444),
      'icon': Icons.warning_amber_rounded,
    },
    {
      'title': 'Re-Open Quiz 3 for Retake Window',
      'subtitle': 'Allow 4 students with verified absences to complete their assessment.',
      'urgency': 'Action Needed',
      'color': const Color(0xFFF59E0B),
      'icon': Icons.replay_circle_filled_rounded,
    },
    {
      'title': 'Distribute Topic 4 Advanced Extension',
      'subtitle': '78% of the class mastered Quadratic Formulations ahead of schedule.',
      'urgency': 'Enrichment',
      'color': const Color(0xFF10B981),
      'icon': Icons.stars_rounded,
    },
  ];

  return TeacherDemoAnalytics(
    totalStudents: 42,
    classAverage: avg,
    classPassRate: pass,
    classAssessmentTrajectory: [
      LineSeries(name: 'Class Average', color: const Color(0xFF0D9488), points: assessments, showArea: true),
    ],
    topicMasteryBars: topicBars,
    atRiskStudents: atRiskList,
    actionRecommendations: actions,
  );
});

// ── STUDENT DATA MODEL & COMPUTATION ────────────────────────────────────────

class StudentDemoAnalytics {
  final int overallGrade;
  final int completedQuizzes;
  final int activeCourses;
  final List<TrendPoint> myScoreHistory;
  final List<BarChartItem> subjectMasteryBars;
  final List<Map<String, dynamic>> myNextSteps;

  const StudentDemoAnalytics({
    required this.overallGrade,
    required this.completedQuizzes,
    required this.activeCourses,
    required this.myScoreHistory,
    required this.subjectMasteryBars,
    required this.myNextSteps,
  });
}

final studentDemoAnalyticsProvider = Provider<StudentDemoAnalytics>((ref) {
  final filter = ref.watch(analyticsDemoFilterProvider);

  int myGrade = 84;
  if (filter.scenario == DemoScenario.highPerforming) {
    myGrade = 93;
  } else if (filter.scenario == DemoScenario.atRisk) {
    myGrade = 68;
  }

  final history = [
    TrendPoint(label: 'Q1', value: (myGrade - 8.0).clamp(50.0, 98.0)),
    TrendPoint(label: 'Q2', value: (myGrade - 3.0).clamp(50.0, 99.0)),
    TrendPoint(label: 'Midterm', value: (myGrade + 5.0).clamp(55.0, 100.0)),
    TrendPoint(label: 'Q3', value: (myGrade - 4.0).clamp(50.0, 98.0)),
    TrendPoint(label: 'Q4', value: (myGrade + 2.0).clamp(55.0, 100.0)),
  ];

  final subjectBars = [
    BarChartItem(label: 'Math', value: (myGrade + 4.0).clamp(40.0, 99.0), color: const Color(0xFF0D9488)),
    BarChartItem(label: 'Science', value: (myGrade - 6.0).clamp(40.0, 96.0), color: const Color(0xFF0284C7)),
    BarChartItem(label: 'English', value: (myGrade + 8.0).clamp(40.0, 100.0), color: const Color(0xFF10B981)),
    BarChartItem(label: 'History', value: (myGrade - 10.0).clamp(35.0, 92.0), color: const Color(0xFFF59E0B)),
  ];

  final steps = [
    {
      'title': 'Upcoming: Science Quiz on Ecosystems',
      'detail': 'Scheduled for Friday • 15 questions • Estimated 20 mins',
      'tag': '⚡ Due Friday',
      'color': const Color(0xFF0284C7),
      'icon': Icons.quiz_outlined,
    },
    {
      'title': 'Practice Topic: Factoring Polynomials',
      'detail': 'Your last score was 64%. Review the flashcards to boost your average above 80%!',
      'tag': '🎯 Recommended Practice',
      'color': const Color(0xFFF59E0B),
      'icon': Icons.menu_book_rounded,
    },
    {
      'title': 'Great Job in English Grammar!',
      'detail': 'You scored 96% on the Midterm Assessment. You are in the top 5% of the class!',
      'tag': '🏆 Achievement',
      'color': const Color(0xFF10B981),
      'icon': Icons.emoji_events_outlined,
    },
  ];

  return StudentDemoAnalytics(
    overallGrade: myGrade,
    completedQuizzes: 12,
    activeCourses: 4,
    myScoreHistory: history,
    subjectMasteryBars: subjectBars,
    myNextSteps: steps,
  );
});
