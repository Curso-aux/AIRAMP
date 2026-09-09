import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../admin/data/admin_repository.dart';
import '../../auth/application/auth_provider.dart';

class StudentCourseDetailScreen extends ConsumerStatefulWidget {
  final String courseId;

  const StudentCourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<StudentCourseDetailScreen> createState() => _StudentCourseDetailScreenState();
}

class _StudentCourseDetailScreenState extends ConsumerState<StudentCourseDetailScreen> {
  Map<String, dynamic>? _subject;
  bool _loading = true;
  List<Map<String, dynamic>> _completedLos = [];
  List<Map<String, dynamic>> _assignedQuizzes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final id = int.tryParse(widget.courseId);
    if (id == null) return;

    final subject = await ref.read(subjectsProvider.notifier).getSubjectById(id);
    await ref.read(subjectDetailProvider.notifier).loadHierarchy(id);

    final user = ref.read(authProvider);
    final studentId = user?.id;
    if (studentId == null) {
      if (mounted) {
        setState(() {
          _subject = subject;
          _loading = false;
        });
      }
      return;
    }

    final db = await DatabaseHelper().database;
    final progressRows = await db.query(
      'student_progress',
      where: 'student_id = ? AND subject_id = ? AND is_completed = 1',
      whereArgs: [studentId, id],
    );

    final assignedQuizzes = await DatabaseHelper().getAssignedQuizzesForStudent(studentId, subjectId: id);

    if (mounted) {
      setState(() {
        _subject = subject;
        _completedLos = progressRows;
        _assignedQuizzes = assignedQuizzes;
        _loading = false;
      });
    }
  }

  bool _isLoCompleted(int loId) {
    return _completedLos.any((p) => (p['lo_id'] as int?) == loId);
  }

  int? _getLoScore(int loId) {
    final match = _completedLos.where((p) => (p['lo_id'] as int?) == loId);
    if (match.isNotEmpty) {
      return match.first['score'] as int?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final topics = ref.watch(subjectDetailProvider);

    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_subject == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Subject not found', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text('Back to Courses', style: TextStyle(color: AppTheme.primary)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final subjectName = _subject!['name']?.toString() ?? 'Subject';
    final subjectCode = _subject!['subject_code']?.toString() ?? '';
    final unlockType = _subject!['unlock_type']?.toString() ?? 'Sequential';
    final isSequential = unlockType.toLowerCase() == 'sequential';

    // Calculate total and completed LOs
    int totalLos = 0;
    int completedCount = 0;
    for (final topic in topics) {
      final los = (topic['learning_outcomes'] as List?) ?? [];
      for (final lo in los) {
        totalLos++;
        if (_isLoCompleted(lo['id'] as int)) {
          completedCount++;
        }
      }
    }

    final progressPct = totalLos > 0 ? ((completedCount / totalLos) * 100).round() : 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back link
              GestureDetector(
                onTap: () => context.pop(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Back to My Courses',
                      style: TextStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Course Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, const Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            subjectCode,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSequential ? Icons.lock_outline : Icons.lock_open_outlined,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                unlockType,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subjectName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subject!['description']?.toString() ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.75), height: 1.4),
                    ),
                    if (_subject!['teacher_name'] != null && _subject!['teacher_name'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.black.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text(
                            'Instructor: ${_subject!['teacher_name']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Progress inside banner
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalLos > 0 ? (completedCount / totalLos) : 0,
                        backgroundColor: Colors.black.withValues(alpha: 0.15),
                        color: Colors.black,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$completedCount of $totalLos Learning Outcomes Completed',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                        Text(
                          '$progressPct%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Assigned Quizzes Section
              if (_assignedQuizzes.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.quiz_outlined, color: AppTheme.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Assigned Quizzes',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${_assignedQuizzes.length} Quizzes',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._assignedQuizzes.map((q) => _buildCourseQuizCard(q)),
                const SizedBox(height: 24),
              ],

              // Curriculum Header
              Row(
                children: [
                  Icon(Icons.layers_outlined, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Course Curriculum',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (topics.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.menu_book_outlined, size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        Text('No topics published yet by the instructor.', style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                )
              else
                ..._buildTopicsList(topics, isSequential),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTopicsList(List<Map<String, dynamic>> topics, bool isSequential) {
    final List<Widget> widgets = [];
    bool previousLoCompleted = true; // For sequential unlocking

    for (int tIdx = 0; tIdx < topics.length; tIdx++) {
      final topic = topics[tIdx];
      final los = (topic['learning_outcomes'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Topic Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${tIdx + 1}',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic['title']?.toString() ?? 'Topic',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                            ),
                            if (topic['description'] != null && topic['description'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                topic['description'].toString(),
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppTheme.border),

                // LOs List
                if (los.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No learning outcomes in this topic yet.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  )
                else
                  ...los.asMap().entries.map((entry) {
                    final loIdx = entry.key;
                    final lo = entry.value;
                    final loId = lo['id'] as int;
                    final isCompleted = _isLoCompleted(loId);
                    final score = _getLoScore(loId);
                    final passingScore = (lo['passing_score'] as int?) ?? 70;
                    final questions = (lo['questions'] as List?) ?? [];
                    final contents = (lo['contents'] as List?) ?? [];

                    // Sequential unlock logic
                    final isUnlocked = !isSequential || previousLoCompleted;
                    if (!isCompleted) {
                      previousLoCompleted = false;
                    }

                    return _buildLoItem(
                      loIndex: loIdx + 1,
                      lo: lo,
                      isCompleted: isCompleted,
                      isUnlocked: isUnlocked,
                      score: score,
                      passingScore: passingScore,
                      questionCount: questions.length,
                      contentCount: contents.length,
                    );
                  }),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildLoItem({
    required int loIndex,
    required Map<String, dynamic> lo,
    required bool isCompleted,
    required bool isUnlocked,
    required int? score,
    required int passingScore,
    required int questionCount,
    required int contentCount,
  }) {
    return InkWell(
      onTap: isUnlocked
          ? () {
              _showLoDetailsSheet(lo, isCompleted, score);
            }
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Complete previous learning outcomes and assessments to unlock this lesson.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
          color: isUnlocked ? Colors.transparent : AppTheme.background.withValues(alpha: 0.5),
        ),
        child: Row(
          children: [
            // Status indicator icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppTheme.success.withValues(alpha: 0.15)
                    : isUnlocked
                        ? AppTheme.primary.withValues(alpha: 0.1)
                        : AppTheme.border.withValues(alpha: 0.3),
              ),
              child: Icon(
                isCompleted
                    ? Icons.check
                    : isUnlocked
                        ? Icons.play_arrow
                        : Icons.lock_outline,
                size: 16,
                color: isCompleted
                    ? AppTheme.success
                    : isUnlocked
                        ? AppTheme.primary
                        : AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 12),

            // Title & subtext
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LO $loIndex: ${lo['title']}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isUnlocked ? AppTheme.text : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$contentCount lessons · $questionCount questions',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      if (passingScore > 0) ...[
                        const SizedBox(width: 6),
                        Text('· Pass: $passingScore%', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Badge / Action
            if (isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  score != null ? 'Passed ($score)' : 'Passed',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success),
                ),
              )
            else if (isUnlocked)
              Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20)
            else
              Icon(Icons.lock, color: AppTheme.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  void _showLoDetailsSheet(Map<String, dynamic> lo, bool isCompleted, int? score) {
    final contents = (lo['contents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final questions = (lo['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final loId = lo['id'] as int;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sheet Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lo['title']?.toString() ?? 'Learning Outcome',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text),
                          ),
                          if (lo['description'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              lo['description'].toString(),
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.text),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTheme.border),

              // Contents & Materials List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Study Materials',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                    const SizedBox(height: 12),

                    if (contents.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          'No reading materials uploaded for this lesson yet.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      )
                    else
                      ...contents.map((c) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.menu_book, size: 18, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    c['title']?.toString() ?? 'Material',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              c['content_data']?.toString() ?? '',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                            ),
                          ],
                        ),
                      )),

                    const SizedBox(height: 24),
                    Text(
                      'Assessment',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.quiz_outlined, size: 24, color: AppTheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Multiple Choice Assessment',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${questions.length} questions · Passing: ${lo['passing_score'] ?? 70}%',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('Passed', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Launch Quiz Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(isCompleted ? Icons.refresh : Icons.play_arrow, color: Colors.black),
                    label: Text(
                      isCompleted ? 'Retake Quiz' : 'Take Quiz',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/quiz/$loId').then((_) => _loadData());
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseQuizCard(Map<String, dynamic> q) {
    final isCompleted = q['status'] == 'completed';
    final title = q['title']?.toString() ?? 'Quiz';
    final qCount = q['question_count'] ?? 0;
    final timeLimit = q['time_limit_minutes'] ?? 0;
    final score = q['score'] ?? 0;
    final totalQ = q['total_questions'] ?? qCount;
    final pct = (q['percentage'] as num?)?.toDouble() ?? 0.0;
    final passingScore = (q['passing_score'] as int?) ?? 70;
    final isPassed = pct >= passingScore;
    final quizId = q['quiz_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? (isPassed ? AppTheme.success.withValues(alpha: 0.4) : AppTheme.error.withValues(alpha: 0.4))
              : AppTheme.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? (isPassed ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.error.withValues(alpha: 0.15))
                      : AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCompleted ? (isPassed ? 'PASSED' : 'RETAKE REQUIRED') : 'PENDING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? (isPassed ? AppTheme.success : AppTheme.error) : AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.help_outline, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text('$qCount questions', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(width: 14),
              Icon(Icons.timer_outlined, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                timeLimit > 0 ? '${timeLimit}m limit' : 'Untimed',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              if (isCompleted) ...[
                const SizedBox(width: 14),
                Icon(Icons.grade_outlined, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Score: $score/$totalQ (${pct.toStringAsFixed(0)}%)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPassed ? AppTheme.success : AppTheme.error,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (quizId != null) {
                  context.push('/quiz/$quizId').then((_) => _loadData());
                }
              },
              icon: Icon(isCompleted ? Icons.replay : Icons.play_arrow, size: 16),
              label: Text(isCompleted ? 'Retake Quiz' : 'Start Quiz', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCompleted ? AppTheme.surface : AppTheme.primary,
                foregroundColor: isCompleted ? AppTheme.text : Colors.black,
                side: isCompleted ? BorderSide(color: AppTheme.border) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
