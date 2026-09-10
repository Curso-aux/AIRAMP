import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../teacher/data/teacher_repository.dart';
import 'package:airamp_flutter/src/features/quiz/presentation/quiz_screen.dart';
import 'components/create_quiz_dialog.dart';
import 'components/quiz_roster_dialog.dart';

class TeacherSubjectDetailScreen extends ConsumerStatefulWidget {
  final String subjectId;
  const TeacherSubjectDetailScreen({super.key, required this.subjectId});

  @override
  ConsumerState<TeacherSubjectDetailScreen> createState() => _TeacherSubjectDetailScreenState();
}

class _TeacherSubjectDetailScreenState extends ConsumerState<TeacherSubjectDetailScreen> {
  int _selectedTab = 1; // 0 = Curriculum, 1 = My Quizzes
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _subject?['name']?.toString() ?? 'Subject',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selectedTab == 1)
            IconButton(
              icon: const Icon(Icons.assignment_add),
              tooltip: 'Create Quiz',
              onPressed: () async {
                final created = await Navigator.of(context, rootNavigator: true).push<bool>(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (ctx) => CreateQuizDialog(
                      initialSubjectId: int.parse(widget.subjectId),
                      subjectName: _subject?['name']?.toString() ?? 'Subject',
                    ),
                  ),
                );
                if (created == true && context.mounted) {
                  ref.invalidate(subjectQuizzesProvider(int.parse(widget.subjectId)));
                  ref.invalidate(teacherDashboardProvider);
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Subject info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _subject?['name']?.toString() ?? '',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      Text(
                        _subject?['description']?.toString() ?? '',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tab selector
          Container(
            color: AppTheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(0),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Curriculum',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 0 ? Colors.black : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(0),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'My Quizzes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 1 ? Colors.black : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: _selectedTab == 0
                ? _buildCurriculumTab()
                : _buildQuizzesTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculumTab() {
    // Placeholder — teachers can view the curriculum structure
    // Full curriculum editing is admin-only; teachers can view
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            'Curriculum view',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),
          const SizedBox(height: 8),
          Text(
            'Curriculum content is managed by administrators.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to admin subject detail if needed
              context.push('/admin/subjects/${widget.subjectId}');
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in Admin View'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
          ),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 64, color: AppTheme.textMuted),
                const SizedBox(height: 16),
                Text(
                  'No quizzes yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first quiz to get started!',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.quiz, color: AppTheme.primary, size: 20),
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
                        icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
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
                          if (edited == true && context.mounted) {
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => QuizRosterDialog(quizId: qId, quizTitle: title),
                              ),
                            );
                          },
                          icon: const Icon(Icons.people, size: 16),
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
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => QuizScreen(quizId: qId.toString()),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow, size: 16),
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
              if (!mounted) return;
              Navigator.pop(context);
              ref.invalidate(subjectQuizzesProvider(subjectId));
              ref.invalidate(teacherDashboardProvider);
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
