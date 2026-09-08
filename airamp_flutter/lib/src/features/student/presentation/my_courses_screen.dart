import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../data/student_repository.dart';

class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen> {
  bool _showAvailable = false;

  void _handleUnenroll(int subjectId, String subjectName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Unenroll from Subject', style: TextStyle(color: AppTheme.text)),
        content: Text('Remove "$subjectName" from your courses?\n\nYour progress will be preserved.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(studentCoursesProvider.notifier).unenrollCourse(subjectId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unenrolled from $subjectName'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            child: Text('Unenroll', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  void _handleEnroll(int subjectId, String subjectName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Enroll in Subject', style: TextStyle(color: AppTheme.text)),
        content: Text('Add "$subjectName" to your enrolled courses?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(studentCoursesProvider.notifier).enrollCourse(subjectId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Enrolled in $subjectName successfully!'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            child: Text('Enroll', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final courses = ref.watch(studentCoursesProvider);
    final available = ref.watch(availableCoursesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(studentCoursesProvider.notifier).reload(),
              ref.read(availableCoursesProvider.notifier).reload(),
            ]);
          },
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Courses',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your enrolled subjects and curriculum',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),

                // Enrolled Courses from provider
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
                          Icon(Icons.menu_book, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text('No courses enrolled yet.', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Tap "Add More Subjects" below to browse available courses.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else
                  ...courses.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildCourseCard(
                      id: c['id'] as int,
                      title: c['name']?.toString() ?? '',
                      code: c['subject_code']?.toString() ?? '',
                      progress: (c['progress'] as int?) ?? 0,
                      unlockType: c['unlock_type']?.toString() ?? 'Flexible',
                      completedLos: (c['completed_los'] as int?) ?? 0,
                      totalLos: (c['total_los'] as int?) ?? 0,
                      cocs: (c['cocs'] as int?) ?? 0,
                    ),
                  )),

                const SizedBox(height: 16),

                // Add More Subjects Button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAvailable = !_showAvailable;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showAvailable ? Icons.remove_circle_outline : Icons.add_circle_outline,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _showAvailable ? 'Hide Available Subjects' : 'Add More Subjects (${available.length} Available)',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showAvailable) ...[
                  const SizedBox(height: 16),
                  if (available.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Center(
                        child: Text(
                          'You are enrolled in all available subjects!',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ...available.map((sub) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildAvailableCourseCard(
                        id: sub['id'] as int,
                        title: sub['name']?.toString() ?? '',
                        code: sub['subject_code']?.toString() ?? '',
                        description: sub['description']?.toString() ?? '',
                        unlockType: sub['unlock_type']?.toString() ?? 'Flexible',
                      ),
                    )),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard({
    required int id,
    required String title,
    required String code,
    required int progress,
    required String unlockType,
    required int completedLos,
    required int totalLos,
    required int cocs,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => context.push('/student/course/$id'),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.menu_book,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              code,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    unlockType == 'Sequential' ? Icons.lock : Icons.lock_open,
                                    size: 10,
                                    color: unlockType == 'Sequential' ? AppTheme.warning : AppTheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    unlockType,
                                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: totalLos > 0 ? (completedLos / totalLos) : 0,
                          backgroundColor: AppTheme.border,
                          color: AppTheme.primary,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$completedLos/$totalLos LOs · $cocs Topics',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            Text(
                              '$progress%',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
          InkWell(
            onTap: () => _handleUnenroll(id, title),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 16),
                  const SizedBox(width: 6),
                  Text('Unenroll', style: TextStyle(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableCourseCard({
    required int id,
    required String title,
    required String code,
    required String description,
    required String unlockType,
  }) {
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.class_, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          code,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                unlockType == 'Sequential' ? Icons.lock : Icons.lock_open,
                                size: 10,
                                color: unlockType == 'Sequential' ? AppTheme.warning : AppTheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                unlockType,
                                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handleEnroll(id, title),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Enroll Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
