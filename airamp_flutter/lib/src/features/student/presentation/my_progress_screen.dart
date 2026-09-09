import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../admin/data/admin_repository.dart';
import '../../auth/application/auth_provider.dart';
import '../data/student_repository.dart';

class MyProgressScreen extends ConsumerStatefulWidget {
  const MyProgressScreen({super.key});

  @override
  ConsumerState<MyProgressScreen> createState() => _MyProgressScreenState();
}

class _MyProgressScreenState extends ConsumerState<MyProgressScreen> {
  int _selectedSubjectIndex = 0;
  List<Map<String, dynamic>> _completedLos = [];
  bool _loadingHierarchy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadSelectedHierarchy());
  }

  Future<void> _loadSelectedHierarchy() async {
    final courses = ref.read(studentCoursesProvider);
    if (courses.isEmpty) return;

    final safeIndex = _selectedSubjectIndex.clamp(0, courses.length - 1);
    final subjectId = courses[safeIndex]['id'] as int;

    setState(() => _loadingHierarchy = true);

    await ref.read(subjectDetailProvider.notifier).loadHierarchy(subjectId);

    final user = ref.read(authProvider);
    final studentId = user?.id;
    if (studentId == null) {
      if (mounted) {
        setState(() => _loadingHierarchy = false);
      }
      return;
    }

    final db = await DatabaseHelper().database;
    final progressRows = await db.query(
      'student_progress',
      where: 'student_id = ? AND subject_id = ? AND is_completed = 1',
      whereArgs: [studentId, subjectId],
    );

    if (mounted) {
      setState(() {
        _completedLos = progressRows;
        _loadingHierarchy = false;
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
    final courses = ref.watch(studentCoursesProvider);
    final topics = ref.watch(subjectDetailProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(studentCoursesProvider.notifier).reload();
            await _loadSelectedHierarchy();
          },
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your learning journey and quiz milestones',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),

                if (courses.isEmpty)
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
                          Icon(Icons.bar_chart_outlined, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text('No enrolled courses yet.', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Enroll in a course from My Courses to view your progress here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.go('/student/courses'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Go to My Courses', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Subject Chips
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: courses.length,
                      itemBuilder: (context, index) {
                        final isActive = _selectedSubjectIndex == index;
                        final sub = courses[index];
                        final label = sub['subject_code']?.toString() ?? sub['name']?.toString() ?? 'Course';
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedSubjectIndex = index);
                            _loadSelectedHierarchy();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive ? AppTheme.primary : AppTheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isActive ? AppTheme.primary : AppTheme.border),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isActive ? Colors.black : AppTheme.textSecondary,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Selected Subject Overview
                  _buildSelectedOverview(courses),

                  const SizedBox(height: 24),

                  // COC / Topic Cards
                  if (_loadingHierarchy)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                    )
                  else if (topics.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Center(
                        child: Text(
                          'No topics added for this subject yet.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ..._buildDynamicTopicCards(topics, courses[_selectedSubjectIndex.clamp(0, courses.length - 1)]['id'] as int),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedOverview(List<Map<String, dynamic>> courses) {
    final safeIndex = _selectedSubjectIndex.clamp(0, courses.length - 1);
    final selectedSubject = courses[safeIndex];
    final name = selectedSubject['name']?.toString() ?? '';
    final code = selectedSubject['subject_code']?.toString() ?? '';
    final grade = selectedSubject['grade_level']?.toString() ?? 'Grade 10';
    final semester = selectedSubject['semester']?.toString() ?? '1st Semester';
    final totalLos = (selectedSubject['total_los'] as int?) ?? 0;
    final completedLos = (selectedSubject['completed_los'] as int?) ?? 0;
    final progress = (selectedSubject['progress'] as int?) ?? 0;
    final unlockType = selectedSubject['unlock_type']?.toString() ?? 'Sequential';

    return _buildOverviewCard(
      name: '$code: $name',
      meta: '$grade · $semester',
      progress: progress.toDouble(),
      completed: completedLos,
      total: totalLos,
      unlockType: unlockType.toLowerCase(),
    );
  }

  List<Widget> _buildDynamicTopicCards(List<Map<String, dynamic>> topics, int subjectId) {
    return topics.asMap().entries.map((entry) {
      final tIdx = entry.key;
      final topic = entry.value;
      final los = (topic['learning_outcomes'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      int topicCompleted = 0;
      for (final lo in los) {
        if (_isLoCompleted(lo['id'] as int)) {
          topicCompleted++;
        }
      }
      final topicTotal = los.length;
      final topicPct = topicTotal > 0 ? (topicCompleted / topicTotal) * 100 : 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildCocCard(
          title: 'Topic ${tIdx + 1}: ${topic['title'] ?? ''}',
          completed: topicCompleted,
          total: topicTotal,
          progress: topicPct,
          items: los.asMap().entries.map((loEntry) {
            final loIdx = loEntry.key;
            final lo = loEntry.value;
            final loId = lo['id'] as int;
            final isCompleted = _isLoCompleted(loId);
            final score = _getLoScore(loId);
            final questions = (lo['questions'] as List?) ?? [];

            String? scoreText;
            if (isCompleted) {
              scoreText = score != null ? 'Score: $score / ${questions.length} (Passed)' : 'Completed (Passed)';
            } else {
              scoreText = questions.isNotEmpty ? 'Assessment: ${questions.length} questions' : 'Reading material only';
            }

            return InkWell(
              onTap: () => context.push('/student/course/$subjectId'),
              child: _buildLoItem(
                '${loIdx + 1}',
                lo['title']?.toString() ?? '',
                isCompleted,
                scoreText,
                isCompleted,
              ),
            );
          }).toList(),
        ),
      );
    }).toList();
  }

  Widget _buildOverviewCard({
    required String name,
    required String meta,
    required double progress,
    required int completed,
    required int total,
    required String unlockType,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.bar_chart, color: AppTheme.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(meta, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: AppTheme.border,
            color: AppTheme.primary,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 12),
          Text(
            '$completed of $total learning outcomes completed (${progress.toInt()}%)',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.text),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  unlockType == 'sequential' ? Icons.lock : Icons.lock_open,
                  size: 16,
                  color: unlockType == 'sequential' ? AppTheme.warning : AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    unlockType == 'sequential'
                        ? 'Sequential: Each LO unlocks after passing the preceding assessment'
                        : 'Flexible: All lessons and assessments are accessible anytime',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCocCard({
    required String title,
    required int completed,
    required int total,
    required double progress,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.text),
                      ),
                    ),
                    Text(
                      '$completed/$total',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: total > 0 ? (progress / 100) : 0,
                  backgroundColor: AppTheme.border,
                  color: progress == 100 ? AppTheme.success : AppTheme.primary,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No learning outcomes in this topic.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            )
          else
            ...items,
        ],
      ),
    );
  }

  Widget _buildLoItem(String number, String title, bool hasProgress, String? scoreText, bool isPassed) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isPassed ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPassed ? AppTheme.success : AppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                if (scoreText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    scoreText,
                    style: TextStyle(fontSize: 12, color: isPassed ? AppTheme.success : AppTheme.textSecondary),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPassed ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPassed ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 12,
                        color: isPassed ? AppTheme.success : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPassed ? 'Passed' : 'Incomplete',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPassed ? AppTheme.success : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isPassed ? Icons.check_box : Icons.check_box_outline_blank,
            color: isPassed ? AppTheme.success : AppTheme.border,
            size: 24,
          ),
        ],
      ),
    );
  }
}

