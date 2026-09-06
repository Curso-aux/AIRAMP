import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class QuizHistoryScreen extends ConsumerStatefulWidget {
  const QuizHistoryScreen({super.key});

  @override
  ConsumerState<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends ConsumerState<QuizHistoryScreen> {
  int _selectedSubjectIndex = 0;
  final List<String> _mockSubjects = ['All', 'CS101', 'CS202'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'Quiz History',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Complete record of all your quiz attempts',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),

              // Stats Row
              Row(
                children: [
                  Expanded(child: _buildStatCard('Attempts', '4', Icons.assignment, AppTheme.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard('Passed', '3', Icons.check_circle, AppTheme.success)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard('Avg Score', '85%', Icons.trending_up, AppTheme.accent)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard('Best', '100%', Icons.emoji_events, AppTheme.warning)),
                ],
              ),
              const SizedBox(height: 24),

              // Subject Filter
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mockSubjects.length,
                  itemBuilder: (context, index) {
                    final isActive = _selectedSubjectIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSubjectIndex = index),
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
                          _mockSubjects[index],
                          style: TextStyle(
                            color: isActive ? Colors.white : AppTheme.textSecondary,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Mock History List
              _buildHistoryCard(
                subject: 'CS101',
                loTitle: 'LO 1: Dart Basics',
                quizTitle: 'Dart Basics Quiz',
                score: 10,
                total: 10,
                date: 'Sep 06, 2026',
                time: '10:00 AM',
                duration: '4m 12s',
                isPassed: true,
              ),
              const SizedBox(height: 12),
              _buildHistoryCard(
                subject: 'CS101',
                loTitle: 'LO 2: Functions & Classes',
                quizTitle: 'Functions Quiz',
                score: 9,
                total: 10,
                date: 'Sep 05, 2026',
                time: '02:30 PM',
                duration: '5m 0s',
                isPassed: true,
              ),
              const SizedBox(height: 12),
              _buildHistoryCard(
                subject: 'CS202',
                loTitle: 'LO 1: Stateless vs Stateful',
                quizTitle: 'Widgets Quiz',
                score: 4,
                total: 10,
                date: 'Sep 04, 2026',
                time: '09:15 AM',
                duration: '3m 45s',
                isPassed: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard({
    required String subject,
    required String loTitle,
    required String quizTitle,
    required int score,
    required int total,
    required String date,
    required String time,
    required String duration,
    required bool isPassed,
  }) {
    final double percentage = total > 0 ? (score / total) * 100 : 0;
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            subject,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            loTitle,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        quizTitle,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text('$date at $time', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(width: 12),
                          const Icon(Icons.schedule, size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(duration, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isPassed ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isPassed ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.error.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPassed ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                      Text(
                        '/${total}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isPassed ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isPassed ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: isPassed ? AppTheme.success : AppTheme.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPassed ? 'Passed' : 'Failed',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isPassed ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${percentage.toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Text('Review', style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.primary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
