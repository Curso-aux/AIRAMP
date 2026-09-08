import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../student/data/student_repository.dart';

class ScoresScreen extends ConsumerStatefulWidget {
  const ScoresScreen({super.key});

  @override
  ConsumerState<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends ConsumerState<ScoresScreen> {
  final _searchController = TextEditingController();
  bool _showFilters = false;
  String _activeSection = 'All Sections';
  final List<String> _sectionOptions = ['All Sections', 'STEM A', 'STEM B', 'STEM C', 'ABM A', 'HUMSS A'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
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

    // Compute stats
    final totalAttempts = scores.length;
    final uniqueStudents = scores.map((s) => s['student_id']).toSet().length;
    final passedAttempts = scores.where((s) => s['is_passed'] == 1 || s['is_passed'] == true).length;
    final passRate = totalAttempts > 0 ? '${((passedAttempts / totalAttempts) * 100).toStringAsFixed(0)}%' : '0%';
    final avgScore = totalAttempts > 0
        ? '${((scores.map((s) => (s['percentage'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b)) / totalAttempts).toStringAsFixed(0)}%'
        : '0%';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
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
                    Column(
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
                  ],
                ),
                const SizedBox(height: 20),

                // Stats Bar
                Row(
                  children: [
                    Expanded(child: _buildTeacherStatCard('Records', '$totalAttempts', Icons.receipt_long, AppTheme.primary)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTeacherStatCard('Students', '$uniqueStudents', Icons.people, AppTheme.accent)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTeacherStatCard('Pass Rate', passRate, Icons.check_circle, AppTheme.success)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTeacherStatCard('Avg Score', avgScore, Icons.trending_up, AppTheme.warning)),
                  ],
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

                // Filters Button
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _showFilters = !_showFilters);
                  },
                  icon: Icon(Icons.filter_list, size: 16, color: AppTheme.text),
                  label: Text(
                    _activeSection == 'All Sections' ? 'Filters' : 'Filter: $_activeSection',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.text,
                    side: BorderSide(color: _activeSection == 'All Sections' ? AppTheme.border : AppTheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),

                if (_showFilters) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Filter by Section', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _sectionOptions.map((section) {
                            final isSelected = _activeSection == section;
                            return ChoiceChip(
                              label: Text(section),
                              selected: isSelected,
                              selectedColor: Theme.of(context).colorScheme.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onSelected: (_) {
                                setState(() => _activeSection = section);
                                ref.read(teacherScoresProvider.notifier).loadScores(section: section);
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Scores List or Empty State
                if (scores.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.assignment_turned_in_outlined, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No Quiz Scores Found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              _searchController.text.isNotEmpty
                                  ? 'No quiz scores matching "${_searchController.text}". Try a different search keyword.'
                                  : 'No quiz attempts have been recorded for the selected filter. Scores will appear here once students complete quizzes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: scores.length,
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
              ],
            ),
          ),
        ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
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
