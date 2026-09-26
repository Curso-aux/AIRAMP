import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/animations/app_transitions.dart';
import '../../../core/animations/animated_pressable.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../admin/data/admin_repository.dart';
import '../../auth/application/auth_provider.dart';
import '../../student/data/student_repository.dart';
import '../../teacher/data/teacher_repository.dart';

class ScoresScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final String? initialSection;
  final List<String>? sections;

  const ScoresScreen({
    super.key,
    this.isEmbedded = false,
    this.initialSection,
    this.sections,
  });

  @override
  ConsumerState<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends ConsumerState<ScoresScreen> {
  final _searchController = TextEditingController();
  late String _activeSection;
  static const int _pageSize = 20;
  int _displayLimit = _pageSize;

  void _openSectionFilterBottomSheet(BuildContext context, List<String> sectionOptions) {
    AppModalTransitions.showSmoothBottomSheet(
      context: context,
      builder: (sheetContext) {
        return _SectionFilterBottomSheet(
          sectionOptions: sectionOptions,
          activeSection: _activeSection,
          onSectionSelected: (selectedSection) {
            setState(() {
              _activeSection = selectedSection;
              _displayLimit = _pageSize;
            });
            ref.read(teacherScoresProvider.notifier).loadScores(section: selectedSection);
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _activeSection = (widget.initialSection != null && widget.initialSection!.isNotEmpty)
        ? widget.initialSection!
        : 'All Sections';
    _searchController.addListener(_onSearchChanged);

    if (_activeSection != 'All Sections') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(teacherScoresProvider.notifier).loadScores(section: _activeSection);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ScoresScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSection != null &&
        widget.initialSection != oldWidget.initialSection &&
        widget.initialSection != _activeSection) {
      setState(() {
        _activeSection = widget.initialSection!;
        _displayLimit = _pageSize;
      });
      ref.read(teacherScoresProvider.notifier).loadScores(section: _activeSection);
    }
  }

  void _onSearchChanged() {
    setState(() {
      _displayLimit = _pageSize;
    });
    ref.read(teacherScoresProvider.notifier).loadScores(
          query: _searchController.text.trim(),
        );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(isoString);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    } catch (_) {
      return 'Recent';
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $ampm';
    } catch (_) {
      return '';
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '< 1m';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final scores = ref.watch(teacherScoresProvider);

    // Resolve dynamic section options for the filter
    final List<String> sectionOptions;
    if (widget.sections != null && widget.sections!.isNotEmpty) {
      sectionOptions = <String>{'All Sections', ...widget.sections!}.toList();
    } else {
      final user = ref.watch(authProvider);
      final isTeacher = user?.role.toLowerCase() == 'teacher';

      if (isTeacher) {
        final sectionsDetails = ref.watch(teacherHandledSectionsDetailsProvider).value ?? [];
        final teacherSections = ref.watch(teacherHandledSectionsProvider).value ?? [];
        final fallbackSections = ref.watch(availableSectionsProvider).value ?? [];

        final handledNames = sectionsDetails
            .map((s) => s['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toList();

        final options = handledNames.isNotEmpty
            ? handledNames
            : (teacherSections.isNotEmpty ? teacherSections : fallbackSections);

        sectionOptions = <String>{'All Sections', ...options}.toList();
      } else {
        final allSections = ref.watch(availableSectionsProvider).value ?? [];
        sectionOptions = <String>{'All Sections', ...allSections}.toList();
      }
    }

    // Compute stats
    final totalAttempts = scores.length;
    final uniqueStudents = scores.map((s) => s['student_id']).toSet().length;
    final passedAttempts = scores.where((s) => s['is_passed'] == 1 || s['is_passed'] == true).length;
    final passRate = totalAttempts > 0 ? '${((passedAttempts / totalAttempts) * 100).toStringAsFixed(0)}%' : '0%';
    final avgScore = totalAttempts > 0
        ? '${((scores.map((s) => (s['percentage'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b)) / totalAttempts).toStringAsFixed(0)}%'
        : '0%';

    final content = RefreshIndicator(
      onRefresh: () async {
        await ref.read(teacherScoresProvider.notifier).loadScores();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.assignment_turned_in, color: Theme.of(context).colorScheme.primary, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Student Quiz Scores',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$uniqueStudents active students · $totalAttempts total attempts',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Stats Bar
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 600) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildTeacherStatCard('Records', '$totalAttempts', Icons.receipt_long, AppTheme.primary)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildTeacherStatCard('Students', '$uniqueStudents', Icons.people, AppTheme.accent)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildTeacherStatCard('Pass Rate', passRate, Icons.check_circle, AppTheme.success)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildTeacherStatCard('Avg Score', avgScore, Icons.trending_up, AppTheme.warning)),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: _buildTeacherStatCard('Records', '$totalAttempts', Icons.receipt_long, AppTheme.primary)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTeacherStatCard('Students', '$uniqueStudents', Icons.people, AppTheme.accent)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTeacherStatCard('Pass Rate', passRate, Icons.check_circle, AppTheme.success)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTeacherStatCard('Avg Score', avgScore, Icons.trending_up, AppTheme.warning)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Search Bar
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: AppTheme.text),
                  decoration: InputDecoration(
                    hintText: 'Search student, subject, or quiz...',
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(teacherScoresProvider.notifier).loadScores(query: '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Compact Filter Bar (Opens Bottom Sheet Modal)
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openSectionFilterBottomSheet(context, sectionOptions),
                      icon: Icon(
                        _activeSection == 'All Sections' ? Icons.filter_list_rounded : Icons.layers_rounded,
                        size: 16,
                        color: _activeSection == 'All Sections' ? AppTheme.text : AppTheme.primary,
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _activeSection == 'All Sections' ? 'Filters' : 'Filter: $_activeSection',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _activeSection == 'All Sections' ? FontWeight.w500 : FontWeight.bold,
                              color: _activeSection == 'All Sections' ? AppTheme.text : AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: _activeSection == 'All Sections' ? AppTheme.textSecondary : AppTheme.primary,
                          ),
                        ],
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _activeSection == 'All Sections'
                            ? Theme.of(context).colorScheme.surface
                            : AppTheme.primary.withValues(alpha: 0.12),
                        side: BorderSide(
                          color: _activeSection == 'All Sections' ? AppTheme.border : AppTheme.primary.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                    if (_activeSection != 'All Sections') ...[
                      const SizedBox(width: 8),
                      AnimatedPressable(
                        onTap: () {
                          setState(() => _activeSection = 'All Sections');
                          ref.read(teacherScoresProvider.notifier).loadScores(section: 'All Sections');
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.border.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Clear',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.close_rounded, size: 13, color: AppTheme.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // Scores List or Empty State
                if (scores.isEmpty)
                  _searchController.text.isNotEmpty
                      ? AppEmptyState.search(
                          query: _searchController.text,
                          onClearSearch: () => _searchController.clear(),
                        )
                      : (_activeSection != 'All Sections')
                          ? AppEmptyState(
                              icon: Icons.filter_alt_off_outlined,
                              title: 'No Scores in Section $_activeSection',
                              message: 'No quiz attempts have been recorded for section "$_activeSection" yet. Tap below to view all sections or clear your filter.',
                              actionLabel: 'View All Sections',
                              actionIcon: Icons.clear_all_rounded,
                              onAction: () {
                                setState(() => _activeSection = 'All Sections');
                                ref.read(teacherScoresProvider.notifier).loadScores(section: 'All Sections');
                              },
                            )
                          : AppEmptyState(
                              icon: Icons.assignment_outlined,
                              title: 'No Quiz Scores Found',
                              message: 'No quiz attempts have been recorded yet. Scores will appear here automatically once students complete quizzes.',
                              actionLabel: 'Refresh Scores',
                              actionIcon: Icons.refresh_rounded,
                              onAction: () {
                                ref.read(teacherScoresProvider.notifier).loadScores();
                              },
                            )
                else ...[
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: scores.take(_displayLimit).length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = scores[index];
                      final isPassed = item['is_passed'] == 1 || item['is_passed'] == true;
                      final score = (item['score'] as num?)?.toInt() ?? 0;
                      final total = (item['total_questions'] as num?)?.toInt() ?? 0;
                      final percentage = (item['percentage'] as num?)?.toDouble() ?? 0.0;
                      final studentName = item['student_name'] as String? ?? 'Student';
                      final studentSection = item['student_section'] as String? ?? 'Section';
                      final studentGrade = item['student_grade'] as String? ?? '';
                      final subjectName = (item['subject_code'] as String?)?.isNotEmpty == true
                          ? '${item['subject_code']} · ${item['subject_name'] ?? ''}'
                          : (item['subject_name'] as String? ?? 'Subject');
                      final loTitle = item['lo_title'] as String? ?? 'Learning Outcome';
                      final completedAt = item['completed_at'] as String?;
                      final duration = _formatDuration((item['duration_seconds'] as num?)?.toInt());

                      return _buildScoreCard(
                        item: item,
                        studentName: studentName,
                        studentSection: studentSection,
                        studentGrade: studentGrade,
                        subjectName: subjectName,
                        loTitle: loTitle,
                        score: score,
                        total: total,
                        percentage: percentage,
                        isPassed: isPassed,
                        date: _formatDate(completedAt),
                        time: _formatTime(completedAt),
                        duration: duration,
                      );
                    },
                  ),
                  if (scores.length > _displayLimit) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: AnimatedPressable(
                        onTap: () {
                          setState(() {
                            _displayLimit += _pageSize;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.expand_more_rounded, size: 18, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Load More Attempts (${scores.length - _displayLimit} remaining)',
                                style: TextStyle(
                                  color: AppTheme.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: content,
      ),
    );
  }

  Widget _buildTeacherStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard({
    required Map<String, dynamic> item,
    required String studentName,
    required String studentSection,
    required String studentGrade,
    required String subjectName,
    required String loTitle,
    required int score,
    required int total,
    required double percentage,
    required bool isPassed,
    required String date,
    required String time,
    required String duration,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: InkWell(
        onTap: () => _showScoreDetailModal(item, studentName, studentSection, studentGrade, subjectName, loTitle, score, total, percentage, isPassed, date, time, duration),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top student info row
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primarySoft,
                    child: Text(
                      studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        Text(
                          studentGrade.isNotEmpty ? '$studentSection · $studentGrade' : studentSection,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPassed ? AppTheme.success.withValues(alpha: 0.12) : AppTheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPassed ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPassed ? Icons.check_circle : Icons.cancel,
                          size: 12,
                          color: isPassed ? AppTheme.success : AppTheme.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPassed ? 'PASSED' : 'FAILED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isPassed ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: 12),

              // Subject and LO info
              Text(
                subjectName,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
              ),
              const SizedBox(height: 2),
              Text(
                loTitle,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              const SizedBox(height: 10),

              // Score and timing bar
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score/$total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPassed ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${percentage.toStringAsFixed(0)}%)',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(date, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(width: 10),
                      Icon(Icons.schedule, size: 12, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(duration, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScoreDetailModal(
    Map<String, dynamic> item,
    String studentName,
    String studentSection,
    String studentGrade,
    String subjectName,
    String loTitle,
    int score,
    int total,
    double percentage,
    bool isPassed,
    String date,
    String time,
    String duration,
  ) {
    final email = item['student_email'] as String? ?? 'No email';

    AppModalTransitions.showSmoothBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxWidth: 540,
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(ctx).padding.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Student Attempt Record',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPassed ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPassed ? 'PASSED' : 'FAILED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isPassed ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      _buildModalRow('Student Name', studentName),
                      const Divider(height: 14),
                      _buildModalRow('Email', email),
                      const Divider(height: 14),
                      _buildModalRow('Section & Grade', '$studentSection · $studentGrade'),
                      const Divider(height: 14),
                      _buildModalRow('Subject', subjectName),
                      const Divider(height: 14),
                      _buildModalRow('Quiz / LO', loTitle),
                      const Divider(height: 14),
                      _buildModalRow('Score', '$score / $total (${percentage.toStringAsFixed(0)}%)'),
                      const Divider(height: 14),
                      _buildModalRow('Completed', '$date at $time'),
                      const Divider(height: 14),
                      _buildModalRow('Duration', duration),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// An elegant modal bottom sheet allowing teachers to select sections without cluttering the screen.
class _SectionFilterBottomSheet extends StatefulWidget {
  final List<String> sectionOptions;
  final String activeSection;
  final ValueChanged<String> onSectionSelected;

  const _SectionFilterBottomSheet({
    required this.sectionOptions,
    required this.activeSection,
    required this.onSectionSelected,
  });

  @override
  State<_SectionFilterBottomSheet> createState() => _SectionFilterBottomSheetState();
}

class _SectionFilterBottomSheetState extends State<_SectionFilterBottomSheet> {
  final _searchController = TextEditingController();
  late String _selectedSection;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.activeSection;
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredSections = widget.sectionOptions.where((sec) {
      if (_searchQuery.isEmpty) return true;
      return sec.toLowerCase().contains(_searchQuery);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 14, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.layers_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filter by Section',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.sectionOptions.length - 1} handled sections available',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (_selectedSection != 'All Sections')
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onSectionSelected('All Sections');
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      'Reset to All',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: AppTheme.textMuted),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: AppTheme.border.withValues(alpha: 0.5)),

          // Search Bar inside modal if multiple sections
          if (widget.sectionOptions.length > 4) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontSize: 13, color: AppTheme.text),
                decoration: InputDecoration(
                  hintText: 'Search section name...',
                  hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                  prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.border.withValues(alpha: 0.6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.border.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ),
          ],

          // Section List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              itemCount: filteredSections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final section = filteredSections[index];
                final isSelected = _selectedSection.toLowerCase() == section.toLowerCase();
                final isAll = section == 'All Sections';

                return Material(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onSectionSelected(section);
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.5)
                              : AppTheme.border.withValues(alpha: 0.4),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withValues(alpha: 0.20)
                                  : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              isAll ? Icons.apps_rounded : Icons.school_outlined,
                              size: 18,
                              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              section,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppTheme.primary : AppTheme.text,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            )
                          else
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.border, width: 1.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
