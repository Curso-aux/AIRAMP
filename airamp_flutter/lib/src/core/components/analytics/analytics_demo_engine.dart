import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'analytics_bar_chart.dart';
import 'analytics_trend_chart.dart';
import 'analytics_multi_line_chart.dart';

/// Available Demo Scenarios that the client can manipulate to validate visualization behavior.
enum DemoScenario {
  standard('Standard Academic Benchmark', 'Normal passing rates and steady student performance across all campuses.'),
  highPerforming('High Performing (Honor Cohort)', '92%+ pass rates, high subject mastery, and top student performance.'),
  atRisk('At-Risk / Needs Extra Support', 'Noticeable drop in quiz scores, higher student-teacher ratios, and remedial review needed.'),
  midtermPeak('Midterm Examination Peak', 'High exam attempt volume, grade distribution shifts, and active quiz completions.');

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
  final attemptPoints = <TrendPoint>[];

  // Base enrollment progression matching totalStudents
  final targetMayStudents = totStudents.toDouble();
  final enrollmentCurve = [0.68, 0.74, 0.88, 0.94, 0.96, 0.97, 0.97, 0.99, 1.0, 1.0, 1.0, 1.0];

  // Monthly quiz attempt volumes (peaking in Oct midterms & Mar finals)
  // Base volume scales proportionally with total enrolled students
  final quizVolumeMultiplier = (totStudents / 2760.0).clamp(0.1, 3.0);
  final monthlyQuizBase = [
    850.0,   // Jun: Orientation / Diagnostic quizzes
    1450.0,  // Jul: First unit practice
    2300.0,  // Aug: First graded formative quizzes
    2950.0,  // Sep: Prelim period
    4200.0,  // Oct: Midterm Examination Surge
    3250.0,  // Nov: 2nd Quarter assessments
    1400.0,  // Dec: Holiday break / review
    2950.0,  // Jan: 2nd Semester restart
    3400.0,  // Feb: Pre-finals prep
    4450.0,  // Mar: Final Examination Peak
    2800.0,  // Apr: Remedial & performance tasks
    1650.0,  // May: Year-end completion
  ];

  for (int i = 0; i < months.length; i++) {
    final m = months[i];
    final stVal = (targetMayStudents * enrollmentCurve[i]).roundToDouble();

    double examSurge = 1.0;
    if (filter.scenario == DemoScenario.midtermPeak && (m == 'Oct' || m == 'Mar')) {
      examSurge = 1.35; // Dramatic midterm/final exam surge
    } else if (filter.scenario == DemoScenario.highPerforming) {
      examSurge = 1.20; // High cohort completes 20% more practice quizzes
    } else if (filter.scenario == DemoScenario.atRisk) {
      examSurge = 0.82; // At-risk cohort takes fewer optional review quizzes
    }

    final attVal = (monthlyQuizBase[i] * quizVolumeMultiplier * examSurge).roundToDouble();

    studentPoints.add(TrendPoint(label: m, value: stVal));
    attemptPoints.add(TrendPoint(label: m, value: attVal));
  }

  // Filter by single month if requested: generate weekly breakdown so the line chart always has 4 points
  List<LineSeries> networkGrowthSeries;
  if (filter.month != 'All Months') {
    final targetMonth = filter.month.length >= 3 ? filter.month.substring(0, 3) : filter.month;
    final mIndex = months.indexOf(targetMonth);
    final safeIdx = mIndex >= 0 ? mIndex : 5; // Default to November (index 5)
    final mSt = studentPoints[safeIdx].value;
    final mAtt = attemptPoints[safeIdx].value;

    final weeklyStudents = [
      TrendPoint(label: '$targetMonth W1', value: (mSt * 0.985).roundToDouble()),
      TrendPoint(label: '$targetMonth W2', value: (mSt * 0.992).roundToDouble()),
      TrendPoint(label: '$targetMonth W3', value: (mSt * 0.998).roundToDouble()),
      TrendPoint(label: '$targetMonth W4', value: (mSt * 1.002).roundToDouble()),
    ];

    final weeklyAttempts = [
      TrendPoint(label: '$targetMonth W1', value: (mAtt * 0.22).roundToDouble()),
      TrendPoint(label: '$targetMonth W2', value: (mAtt * 0.28).roundToDouble()),
      TrendPoint(label: '$targetMonth W3', value: (mAtt * 0.31).roundToDouble()),
      TrendPoint(label: '$targetMonth W4', value: (mAtt * 0.19).roundToDouble()),
    ];

    networkGrowthSeries = [
      LineSeries(
        name: 'Enrolled Students',
        color: const Color(0xFF0D9488),
        points: weeklyStudents,
        showArea: true,
      ),
      LineSeries(
        name: 'Quizzes Taken',
        color: const Color(0xFFF59E0B),
        points: weeklyAttempts,
      ),
    ];
  } else {
    networkGrowthSeries = [
      LineSeries(
        name: 'Enrolled Students',
        color: const Color(0xFF0D9488),
        points: studentPoints,
        showArea: true,
      ),
      LineSeries(
        name: 'Quizzes Taken',
        color: const Color(0xFFF59E0B),
        points: attemptPoints,
      ),
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

  final campusStudentCount = (860 * scenarioMult).round();
  final campusQuizBase = (1240 * scenarioMult).round();

  for (int i = 0; i < months.length; i++) {
    final m = months[i];
    double peak = 1.0;
    if (m == 'Oct' || m == 'Mar') peak = 1.7 * scenarioMult;
    if (m == 'Dec') peak = 0.55;

    attemptPoints.add(TrendPoint(label: m, value: (campusQuizBase * 0.55 * peak).roundToDouble()));
    activeStudentPoints.add(TrendPoint(label: m, value: (campusStudentCount * (0.80 + (i * 0.018))).clamp(50.0, campusStudentCount.toDouble()).roundToDouble()));
  }

  List<LineSeries> monthlyAttemptSeries;
  if (filter.month != 'All Months') {
    final targetMonth = filter.month.length >= 3 ? filter.month.substring(0, 3) : filter.month;
    final mIndex = months.indexOf(targetMonth);
    final safeIdx = mIndex >= 0 ? mIndex : 5;
    final mAtt = attemptPoints[safeIdx].value;
    final mSt = activeStudentPoints[safeIdx].value;

    final weeklyAttempts = [
      TrendPoint(label: '$targetMonth W1', value: (mAtt * 0.22).roundToDouble()),
      TrendPoint(label: '$targetMonth W2', value: (mAtt * 0.28).roundToDouble()),
      TrendPoint(label: '$targetMonth W3', value: (mAtt * 0.31).roundToDouble()),
      TrendPoint(label: '$targetMonth W4', value: (mAtt * 0.19).roundToDouble()),
    ];
    final weeklyStudents = [
      TrendPoint(label: '$targetMonth W1', value: (mSt * 0.98).roundToDouble()),
      TrendPoint(label: '$targetMonth W2', value: (mSt * 0.99).roundToDouble()),
      TrendPoint(label: '$targetMonth W3', value: (mSt * 1.00).roundToDouble()),
      TrendPoint(label: '$targetMonth W4', value: (mSt * 1.01).roundToDouble()),
    ];
    monthlyAttemptSeries = [
      LineSeries(name: 'Quiz Attempts', color: const Color(0xFF0D9488), points: weeklyAttempts, showArea: true),
      LineSeries(name: 'Active Learners', color: const Color(0xFF0284C7), points: weeklyStudents),
    ];
  } else {
    monthlyAttemptSeries = [
      LineSeries(name: 'Quiz Attempts', color: const Color(0xFF0D9488), points: attemptPoints, showArea: true),
      LineSeries(name: 'Active Learners', color: const Color(0xFF0284C7), points: activeStudentPoints),
    ];
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
    monthlyAttemptSeries: monthlyAttemptSeries,
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
