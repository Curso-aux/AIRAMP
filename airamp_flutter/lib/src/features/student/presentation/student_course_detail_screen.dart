import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/components/skeleton_loader.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../admin/data/admin_repository.dart';
import '../../auth/application/auth_provider.dart';
import '../../curriculum/presentation/curriculum_content_sheet.dart';
import '../data/student_repository.dart';

class StudentCourseDetailScreen extends ConsumerStatefulWidget {
  final String courseId;

  const StudentCourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<StudentCourseDetailScreen> createState() =>
      _StudentCourseDetailScreenState();
}

class _StudentCourseDetailScreenState
    extends ConsumerState<StudentCourseDetailScreen> {
  Map<String, dynamic>? _subject;
  bool _loading = true;
  List<Map<String, dynamic>> _completedLos = [];
  List<Map<String, dynamic>> _assignedQuizzes = [];
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final id = int.tryParse(widget.courseId);
    if (id == null) return;

    final subject = await ref
        .read(subjectsProvider.notifier)
        .getSubjectById(id);
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

    final assignedQuizzes = await DatabaseHelper().getAssignedQuizzesForStudent(
      studentId,
      subjectId: id,
    );
    final assignments = await DatabaseHelper().getAssignmentsForStudent(
      studentId,
      subjectId: id,
    );

    if (mounted) {
      setState(() {
        _subject = subject;
        _completedLos = progressRows;
        _assignedQuizzes = assignedQuizzes;
        _assignments = assignments;
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

    // Dynamically react to quiz attempts or resets
    ref.listen(studentQuizAssignmentsProvider, (prev, next) {
      _loadData();
    });
    ref.listen(studentProgressProvider, (prev, next) {
      _loadData();
    });

    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 200, height: 26),
                SizedBox(height: 10),
                SkeletonLoader(width: 280, height: 16),
                SizedBox(height: 24),
                Expanded(child: SkeletonListView(itemCount: 4)),
              ],
            ),
          ),
        ),
      );
    }

    if (_subject == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: AppErrorState(
            title: 'Subject Not Found',
            message: 'This course is unavailable or you may not be enrolled in it.',
            retryLabel: 'Back to Courses',
            onRetry: () => context.pop(),
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

    final progressPct = totalLos > 0
        ? ((completedCount / totalLos) * 100).round()
        : 0;

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
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            subjectCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSequential
                                    ? Icons.lock_outline
                                    : Icons.lock_open_outlined,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                unlockType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
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
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                    ),
                    if (_subject!['teacher_name'] != null &&
                        _subject!['teacher_name'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Colors.black.withValues(alpha: 0.8),
                          ),
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
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '$progressPct%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
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
                        Icon(
                          Icons.quiz_outlined,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Assigned Quizzes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${_assignedQuizzes.length} Quizzes',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_assignedQuizzes.length >= 3)
                  // Scaffold layout for 3+ quizzes: ListView with separators
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _assignedQuizzes.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _buildCourseQuizCard(_assignedQuizzes[index]),
                    ),
                  )
                else
                  ..._assignedQuizzes.map((q) => _buildCourseQuizCard(q)),
                const SizedBox(height: 24),
              ],

              // Assignments & Projects Section
              if (_assignments.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Assignments & Projects',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${_assignments.length} Tasks',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._assignments.map((a) => _buildCourseAssignmentCard(a)),
                const SizedBox(height: 24),
              ],

              // Gizmo Flashcard & Practice Studio Banner
              if (topics.isNotEmpty) _buildGizmoPracticeHeroBanner(topics),

              // Curriculum Header
              Row(
                children: [
                  Icon(
                    Icons.layers_outlined,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Course Curriculum',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
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
                        Icon(
                          Icons.menu_book_outlined,
                          size: 48,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No topics published yet by the instructor.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
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

  Widget _buildGizmoPracticeHeroBanner(List<Map<String, dynamic>> topics) {
    int? targetLoId;
    String? targetLoTitle;
    int totalModulesCount = 0;

    for (final topic in topics) {
      final los = (topic['learning_outcomes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      totalModulesCount += los.length;
      if (targetLoId == null && los.isNotEmpty) {
        targetLoId = los.first['id'] as int?;
        targetLoTitle = los.first['title']?.toString();
      }
    }

    if (totalModulesCount == 0) return const SizedBox.shrink();

    final subjectName = _subject?['name']?.toString() ?? 'Course';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.22),
            const Color(0xFF06B6D4).withValues(alpha: 0.15),
            AppTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF818CF8).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 28,
                    ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'GIZMO REVIEW STUDIO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFA78BFA),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome, size: 11, color: AppTheme.success),
                                const SizedBox(width: 3),
                                Text(
                                  'AI Scanned',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Practice Quiz & Flashcards',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review this course with interactive multiple-choice questions & spaced-repetition flashcards automatically generated from your module lessons!',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildStudioFeatureChip(Icons.quiz_outlined, 'Multiple Choice (A, B, C, D)'),
                _buildStudioFeatureChip(Icons.check_circle_outline, 'Instant Answer Feedback'),
                _buildStudioFeatureChip(Icons.style_outlined, '3D Active Recall'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.play_circle_fill, size: 18),
                label: Text(
                  targetLoTitle != null
                      ? 'Practice First Module: $targetLoTitle'
                      : 'Start Practice Review',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onPressed: () {
                  if (targetLoId != null) {
                    final title = Uri.encodeComponent(targetLoTitle ?? 'Module');
                    final subject = Uri.encodeComponent(subjectName);
                    context.push('/module-review/$targetLoId?title=$title&subject=$subject');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTopicsList(
    List<Map<String, dynamic>> topics,
    bool isSequential,
  ) {
    final List<Widget> widgets = [];
    bool previousLoCompleted = true; // For sequential unlocking

    for (int tIdx = 0; tIdx < topics.length; tIdx++) {
      final topic = topics[tIdx];
      final los =
          (topic['learning_outcomes'] as List?)?.cast<Map<String, dynamic>>() ??
          [];

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
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                              ),
                            ),
                            if (topic['description'] != null &&
                                topic['description'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                topic['description'].toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (los.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Review Topic with Flashcards',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                final firstLoId = los.first['id'] as int;
                                final title = Uri.encodeComponent(
                                  topic['title']?.toString() ?? 'Topic',
                                );
                                final subjectName = Uri.encodeComponent(
                                  _subject?['name']?.toString() ?? 'Subject',
                                );
                                context.push(
                                  '/module-review/$firstLoId?title=$title&subject=$subjectName',
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.psychology,
                                      size: 16,
                                      color: AppTheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Topic Flashcards',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(height: 1, color: AppTheme.border),

                // LOs List
                if (los.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No learning outcomes in this topic yet.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
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
                  content: Text(
                    'Complete previous learning outcomes and assessments to unlock this lesson.',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)),
          ),
          color: isUnlocked
              ? Colors.transparent
              : AppTheme.background.withValues(alpha: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (passingScore > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '· Pass: $passingScore%',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.primary,
                              ),
                            ),
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.success,
                      ),
                    ),
                  )
                else if (isUnlocked)
                  Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20)
                else
                  Icon(Icons.lock, color: AppTheme.textMuted, size: 16),
              ],
            ),

            // Dedicated, Prominent Flashcard & Quiz Action Strip
            if (isUnlocked) ...[
              const SizedBox(height: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final loId = lo['id'] as int? ?? 0;
                    final title = Uri.encodeComponent(
                      lo['title']?.toString() ?? 'Module',
                    );
                    final subjectName = Uri.encodeComponent(
                      _subject?['name']?.toString() ?? 'Subject',
                    );
                    context.push(
                      '/module-review/$loId?title=$title&subject=$subjectName',
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.16),
                          const Color(0xFF6366F1).withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.psychology,
                            size: 16,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🧠 Practice Quiz & Flashcards',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primary,
                                ),
                              ),
                              Text(
                                'Multiple-choice questions & active recall cards',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Practice',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 10,
                                color: AppTheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showLoDetailsSheet(
    Map<String, dynamic> lo,
    bool isCompleted,
    int? score,
  ) {
    final contents =
        (lo['contents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final questions =
        (lo['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lo['title']?.toString() ?? 'Learning Outcome',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                            ),
                          ),
                          if (lo['description'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              lo['description'].toString(),
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                      ),
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
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ...contents.map((c) {
                        final type = c['content_type']?.toString() ?? 'Text';
                        final icon = getIconForType(type);
                        final color = getColorForType(type);
                        final fileInfo = MaterialFileInfo.tryParse(
                          c['content_data'],
                        );

                        return Container(
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
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(icon, size: 18, color: color),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c['title']?.toString() ?? 'Material',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.text,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (fileInfo != null)
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(
                                                    alpha: 0.15,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  fileInfo.fileExtension
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: color,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                formatFileSize(
                                                  fileInfo.fileSize,
                                                ),
                                                style: TextStyle(
                                                  color: AppTheme.textMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (fileInfo != null) ...[
                                if (fileInfo.description != null &&
                                    fileInfo.description!.isNotEmpty)
                                  Text(
                                    fileInfo.description!,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.attach_file,
                                        size: 14,
                                        color: AppTheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          fileInfo.fileName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.text,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else
                                Text(
                                  c['content_data']?.toString() ?? '',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 24),
                    // ── Gizmo Review Flashcards Banner ──
                    Row(
                      children: [
                        Icon(
                          Icons.psychology,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Practice & Active Recall',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primary.withValues(alpha: 0.12),
                            AppTheme.surfaceElevated,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.psychology,
                                  color: AppTheme.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gizmo Review & Practice Quiz',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.text,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Smart flashcards & mini-quizzes automatically scanned from this module',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.psychology, size: 20),
                              label: const Text(
                                '🧠 Practice Quiz & Flashcards (Choices)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                final title = Uri.encodeComponent(
                                  lo['title']?.toString() ?? 'Module',
                                );
                                final subjectName = Uri.encodeComponent(
                                  _subject?['name']?.toString() ?? 'Subject',
                                );
                                context.push(
                                  '/module-review/$loId?title=$title&subject=$subjectName',
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'Assessment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                      ),
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
                          Icon(
                            Icons.quiz_outlined,
                            size: 24,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Multiple Choice Assessment',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${questions.length} questions · Passing: ${lo['passing_score'] ?? 70}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Passed',
                                style: TextStyle(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      isCompleted ? Icons.refresh : Icons.play_arrow,
                      color: Colors.black,
                    ),
                    label: Text(
                      isCompleted ? 'Retake Quiz' : 'Take Quiz',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
              ? (isPassed
                    ? AppTheme.success.withValues(alpha: 0.4)
                    : AppTheme.error.withValues(alpha: 0.4))
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? (isPassed
                            ? AppTheme.success.withValues(alpha: 0.15)
                            : AppTheme.error.withValues(alpha: 0.15))
                      : AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCompleted
                      ? (isPassed ? 'PASSED' : 'RETAKE REQUIRED')
                      : 'PENDING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCompleted
                        ? (isPassed ? AppTheme.success : AppTheme.error)
                        : AppTheme.warning,
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
              Text(
                '$qCount questions',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
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
              icon: Icon(
                isCompleted ? Icons.replay : Icons.play_arrow,
                size: 16,
              ),
              label: Text(
                isCompleted ? 'Retake Quiz' : 'Start Quiz',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCompleted
                    ? AppTheme.surface
                    : AppTheme.primary,
                foregroundColor: isCompleted ? AppTheme.text : Colors.black,
                side: isCompleted ? BorderSide(color: AppTheme.border) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseAssignmentCard(Map<String, dynamic> assignment) {
    final id = assignment['id'];
    final title = assignment['title']?.toString() ?? 'Assignment';
    final points = assignment['total_points'] ?? 100;
    final dueDateStr = assignment['due_date']?.toString();
    final submissionStatus = assignment['submission_status']?.toString();
    final isSubmitted = submissionStatus != null;
    final isGraded = submissionStatus == 'graded';
    final grade = assignment['grade'];

    String formattedDue = 'No due date';
    bool isOverdue = false;
    if (dueDateStr != null && dueDateStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(dueDateStr);
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        formattedDue = 'Due: ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
        isOverdue = DateTime.now().isAfter(dt);
      } catch (_) {
        formattedDue = 'Due: $dueDateStr';
      }
    }

    Color statusColor = AppTheme.warning;
    String statusLabel = 'PENDING';
    if (isGraded) {
      statusColor = AppTheme.success;
      statusLabel =
          'GRADED: ${grade is num ? grade.toStringAsFixed(0) : grade}/$points';
    } else if (isSubmitted) {
      statusColor = AppTheme.primary;
      statusLabel = 'SUBMITTED';
    } else if (isOverdue) {
      statusColor = AppTheme.error;
      statusLabel = 'OVERDUE';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: (isOverdue && !isSubmitted)
                    ? AppTheme.error
                    : AppTheme.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                formattedDue,
                style: TextStyle(
                  fontSize: 12,
                  color: (isOverdue && !isSubmitted)
                      ? AppTheme.error
                      : AppTheme.textSecondary,
                  fontWeight: (isOverdue && !isSubmitted)
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 14),
              Icon(
                Icons.military_tech_outlined,
                size: 14,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '$points points',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (id != null) {
                  context.push('/submissions/$id').then((_) => _loadData());
                }
              },
              icon: Icon(
                isSubmitted
                    ? Icons.visibility_outlined
                    : Icons.upload_file_outlined,
                size: 16,
              ),
              label: Text(
                isSubmitted ? 'View Submission' : 'Submit Assignment',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSubmitted
                    ? AppTheme.surface
                    : AppTheme.primary,
                foregroundColor: isSubmitted ? AppTheme.text : Colors.black,
                side: isSubmitted ? BorderSide(color: AppTheme.border) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
