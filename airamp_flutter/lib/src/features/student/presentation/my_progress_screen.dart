import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class MyProgressScreen extends ConsumerStatefulWidget {
  const MyProgressScreen({super.key});

  @override
  ConsumerState<MyProgressScreen> createState() => _MyProgressScreenState();
}

class _MyProgressScreenState extends ConsumerState<MyProgressScreen> {
  int _selectedSubjectIndex = 0;

  final List<String> _mockSubjects = ['CS101', 'CS202'];

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
              const Text(
                'Progress',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              const SizedBox(height: 4),
              const Text(
                'Track your learning journey',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),

              // Subject Chips
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

              // Overview Card
              _buildOverviewCard(
                name: _selectedSubjectIndex == 0 ? 'Introduction to Flutter' : 'Advanced State Management',
                meta: 'Grade 10 · 1st Semester',
                progress: _selectedSubjectIndex == 0 ? 45 : 10,
                completed: _selectedSubjectIndex == 0 ? 4 : 1,
                total: _selectedSubjectIndex == 0 ? 9 : 10,
                unlockType: _selectedSubjectIndex == 0 ? 'flexible' : 'sequential',
              ),

              const SizedBox(height: 24),

              // COC / Topic Cards
              _buildCocCard(
                title: 'Topic 1: Dart Basics',
                completed: 2,
                total: 2,
                progress: 100,
                items: [
                  _buildLoItem('1', 'Variables & Types', true, 'Score: 10/10', true),
                  _buildLoItem('2', 'Functions & Classes', true, 'Score: 9/10', true),
                ],
              ),
              const SizedBox(height: 16),
              _buildCocCard(
                title: 'Topic 2: Widgets',
                completed: 1,
                total: 3,
                progress: 33,
                items: [
                  _buildLoItem('1', 'Stateless vs Stateful', true, 'Score: 10/10', true),
                  _buildLoItem('2', 'Layouts & Flex', false, 'Attempts: 1', false),
                  _buildLoItem('3', 'Interactivity', false, null, false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
              const Icon(Icons.bar_chart, color: AppTheme.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(meta, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
            '$completed of $total topics completed (${progress.toInt()}%)',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.text),
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
                        ? 'Sequential: Progress checks require admin validation'
                        : 'Flexible: Progress reflects automatically',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.text),
                      ),
                    ),
                    Text(
                      '$completed/$total',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: AppTheme.border,
                  color: progress == 100 ? AppTheme.success : AppTheme.primary,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          ...items,
        ],
      ),
    );
  }

  Widget _buildLoItem(String number, String title, bool hasProgress, String? scoreText, bool isPassed) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                if (hasProgress && scoreText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    scoreText,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
                if (hasProgress) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPassed ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPassed ? Icons.check_circle : Icons.error_outline,
                          size: 12,
                          color: isPassed ? AppTheme.success : AppTheme.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPassed ? 'Passed' : 'Pending',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isPassed ? AppTheme.success : AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
