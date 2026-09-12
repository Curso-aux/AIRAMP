import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../admin/data/admin_repository.dart';
import '../../curriculum/presentation/curriculum_hierarchy_widgets.dart';
import '../../teacher/data/teacher_repository.dart';
import 'package:airamp_flutter/src/features/quiz/presentation/quiz_screen.dart';
import 'components/create_quiz_dialog.dart';
import 'components/quiz_roster_dialog.dart';
import 'components/create_assignment_dialog.dart';
import 'components/assignment_roster_dialog.dart';
import '../../submissions/data/submissions_repository.dart';

class TeacherSubjectDetailScreen extends ConsumerStatefulWidget {
  final String subjectId;
  const TeacherSubjectDetailScreen({super.key, required this.subjectId});

  @override
  ConsumerState<TeacherSubjectDetailScreen> createState() => _TeacherSubjectDetailScreenState();
}

class _TeacherSubjectDetailScreenState extends ConsumerState<TeacherSubjectDetailScreen> {
  int _selectedTab = 0; // 0 = Curriculum, 1 = My Quizzes
  Map<String, dynamic>? _subject;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSubject();
  }

  Future<void> _loadSubject() async {
    final id = int.tryParse(widget.subjectId);
    if (id == null) return;
    final subject = await ref.read(teacherSubjectsProvider.notifier).getSubjectById(id);
    if (mounted) {
      setState(() {
        _subject = subject;
        _loading = false;
      });
      ref.read(subjectDetailProvider.notifier).loadHierarchy(id);
    }
  }

  Future<void> _openCreateQuiz() async {
    final created = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => CreateQuizDialog(
          initialSubjectId: int.parse(widget.subjectId),
          subjectName: _subject?['name']?.toString() ?? 'Subject',
        ),
      ),
    );
    if (created == true && mounted) {
      ref.invalidate(subjectQuizzesProvider(int.parse(widget.subjectId)));
      ref.invalidate(teacherDashboardProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_subject == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text('Subject not found', style: TextStyle(fontSize: 18, color: AppTheme.text)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final subjectName = _subject?['name']?.toString() ?? 'Subject';
    final subjectDescription = _subject?['description']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          subjectName,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.text),
        ),
        actions: [
          if (_selectedTab == 1)
            IconButton(
              icon: Icon(Icons.assignment_add, color: AppTheme.primary),
              tooltip: 'Create Quiz',
              onPressed: _openCreateQuiz,
            )
          else if (_selectedTab == 2)
            IconButton(
              icon: Icon(Icons.add_task, color: AppTheme.primary),
              tooltip: 'Create Assignment',
              onPressed: _openCreateAssignment,
            )
          else
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: AppTheme.primary),
              tooltip: 'Add Topic',
              onPressed: _openAddTopic,
            ),
        ],
      ),
      body: Column(
        children: [
          // Course Info Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.menu_book_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Course Overview',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                                color: AppTheme.primary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Teacher Console',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subjectDescription.isNotEmpty
                              ? subjectDescription
                              : 'Manage classroom quizzes, track student evaluations, and review curriculum.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Segmented Floating Tab Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  _buildTabPill(
                    index: 0,
                    label: 'Curriculum',
                    icon: Icons.menu_book_outlined,
                  ),
                  _buildTabPill(
                    index: 1,
                    label: 'Quizzes',
                    icon: Icons.quiz_outlined,
                  ),
                  _buildTabPill(
                    index: 2,
                    label: 'Assignments',
                    icon: Icons.assignment_outlined,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Tab content
          Expanded(
            child: _selectedTab == 0
                ? _buildCurriculumTab()
                : _selectedTab == 1
                    ? _buildQuizzesTab()
                    : _buildAssignmentsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({required int index, required String label, required IconData icon}) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.black : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.black : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddTopic() {
    final subjectId = int.tryParse(widget.subjectId);
    if (subjectId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTopicSheet(subjectId: subjectId),
    );
  }

  Widget _buildCurriculumTab() {
    final subjectId = int.tryParse(widget.subjectId);
    if (subjectId == null) return const SizedBox.shrink();

    final topics = ref.watch(subjectDetailProvider);

    if (topics.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.menu_book_outlined, size: 40, color: AppTheme.primary),
              ),
              const SizedBox(height: 20),
              Text(
                'No Curriculum Topics Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              const SizedBox(height: 8),
              Text(
                'Create course topics, define learning outcomes, and upload real lecture materials (PDF, PPT, Word, Video).',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _openAddTopic,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add First Topic', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        await ref.read(subjectDetailProvider.notifier).loadHierarchy(subjectId);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Top action bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.layers_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Course Curriculum',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      Text(
                        '${topics.length} Topic${topics.length == 1 ? '' : 's'} · Topics, Outcomes & Materials',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openAddTopic,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Topic', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          // Topic cards
          ...topics.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final topic = entry.value;
            return TopicCard(
              topic: topic,
              topicIndex: index,
              subjectId: subjectId,
              canEdit: true,
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuizzesTab() {
    final subjectId = int.parse(widget.subjectId);
    final quizzesAsync = ref.watch(subjectQuizzesProvider(subjectId));

    return quizzesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (quizzes) {
        if (quizzes.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.assignment_outlined, size: 44, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No quizzes yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first quiz to assess students, automate grading, and track subject performance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _openCreateQuiz,
                    icon: const Icon(Icons.add_task_rounded, size: 18),
                    label: const Text('Create First Quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: quizzes.length,
          itemBuilder: (context, index) {
            final quiz = quizzes[index];
            final qId = quiz['id'] as int;
            final title = quiz['title']?.toString() ?? 'Quiz';
            final qCount = quiz['question_count'] ?? 0;
            final assignedCount = quiz['assigned_count'] ?? 0;
            final compCount = quiz['completed_count'] ?? 0;
            final timeLimit = quiz['time_limit_minutes'] ?? 0;
            final passingScore = quiz['passing_score'] ?? 70;
            final status = quiz['status']?.toString() ?? 'published';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.quiz_outlined, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.text)),
                            const SizedBox(height: 2),
                            Text(
                              '$qCount Questions · Pass: $passingScore% · ${timeLimit > 0 ? '$timeLimit mins' : 'No time limit'}',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (status == 'draft')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Draft', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                        tooltip: 'Edit Quiz',
                        onPressed: () async {
                          final edited = await Navigator.of(context, rootNavigator: true).push<bool>(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (ctx) => CreateQuizDialog(
                                initialSubjectId: int.parse(widget.subjectId),
                                subjectName: _subject?['name']?.toString() ?? 'Subject',
                                quizId: qId,
                              ),
                            ),
                          );
                          if (edited == true && mounted) {
                            ref.invalidate(subjectQuizzesProvider(int.parse(widget.subjectId)));
                            ref.invalidate(teacherDashboardProvider);
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                        onPressed: () => _confirmDeleteQuiz(context, qId, title, subjectId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: assignedCount > 0 ? (compCount / assignedCount) : 0,
                            backgroundColor: AppTheme.border,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.success),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$compCount / $assignedCount completed',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => QuizRosterDialog(quizId: qId, quizTitle: title),
                              ),
                            );
                          },
                          icon: const Icon(Icons.people_outline, size: 16),
                          label: const Text('Roster'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: BorderSide(color: AppTheme.primary),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => QuizScreen(quizId: qId.toString()),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow_outlined, size: 16),
                          label: const Text('Take Quiz'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteQuiz(BuildContext context, int quizId, String title, int subjectId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Delete Quiz'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper().deleteQuiz(quizId);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ref.invalidate(subjectQuizzesProvider(subjectId));
                ref.invalidate(teacherDashboardProvider);
              }
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateAssignment() async {
    final subId = int.tryParse(widget.subjectId);
    if (subId == null) return;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => CreateAssignmentDialog(
        subjectId: subId,
        subjectName: _subject?['name']?.toString() ?? 'Subject',
      ),
    );

    if (created == true && mounted) {
      ref.invalidate(subjectAssignmentsProvider(subId));
    }
  }

  void _confirmDeleteAssignment(BuildContext context, int assignmentId, String title, int subjectId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Assignment'),
        content: Text('Are you sure you want to delete "$title" and all student submissions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await DatabaseHelper().deleteAssignment(assignmentId);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ref.invalidate(subjectAssignmentsProvider(subjectId));
                messenger.showSnackBar(
                  const SnackBar(content: Text('Assignment deleted')),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab() {
    final subjectId = int.tryParse(widget.subjectId);
    if (subjectId == null) {
      return const Center(child: Text('Invalid subject'));
    }

    final assignmentsAsync = ref.watch(subjectAssignmentsProvider(subjectId));

    return assignmentsAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (err, stack) => Center(child: Text('Error loading assignments: $err', style: TextStyle(color: AppTheme.error))),
      data: (assignments) {
        if (assignments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 56, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'No Assignments Created',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create assignments and projects for your students to submit files or project links.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _openCreateAssignment,
                    icon: const Icon(Icons.add, color: Colors.black),
                    label: const Text('Create First Assignment', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(subjectAssignmentsProvider(subjectId));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final a = assignments[index];
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.assignment_outlined, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.text),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${a.totalPoints} pts · Format: ${a.submissionType.toUpperCase()}',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                          tooltip: 'Delete Assignment',
                          onPressed: () => _confirmDeleteAssignment(context, a.id, a.title, subjectId),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.people_alt_outlined, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${a.submissionCount} submissions · ${a.gradedCount} graded',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const Spacer(),
                        if (a.dueDate != null && a.dueDate!.isNotEmpty) ...[
                          Icon(Icons.calendar_today_outlined, size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Due: ${a.dueDate!.substring(0, 10)}',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AssignmentRosterDialog(
                              assignmentId: a.id,
                              assignmentTitle: a.title,
                              totalPoints: a.totalPoints,
                              dueDate: a.dueDate,
                            ),
                          ).then((_) {
                            ref.invalidate(subjectAssignmentsProvider(subjectId));
                          });
                        },
                        icon: const Icon(Icons.rate_review_outlined, size: 16),
                        label: Text(
                          a.submissionCount > 0 ? 'Review Submissions (${a.submissionCount})' : 'Review Submissions',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
