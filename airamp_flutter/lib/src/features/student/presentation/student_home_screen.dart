import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_provider.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  String _subjectSearch = '';

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    if (currentUser == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(seconds: 1));
          },
          color: AppTheme.primary,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                          ),
                          Text(
                            currentUser.fullName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _buildBellButton(),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            ref.read(authProvider.notifier).logout();
                          },
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: AppTheme.primary,
                            child: Text(
                              currentUser.fullName.isNotEmpty ? currentUser.fullName[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // My Subjects Section Header
                Row(
                  children: [
                    const Icon(Icons.menu_book, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'My Subjects',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Box
                TextField(
                  onChanged: (val) => setState(() => _subjectSearch = val),
                  style: const TextStyle(color: AppTheme.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search subjects...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                    suffixIcon: _subjectSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppTheme.textMuted, size: 20),
                            onPressed: () {
                              setState(() => _subjectSearch = '');
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Mock Subject List
                _buildSubjectCard(
                  name: 'Introduction to Flutter',
                  teacher: 'Prof. Dart',
                  code: 'CS101',
                  status: '10 topics · 2 quizzes done',
                ),
                const SizedBox(height: 12),
                _buildSubjectCard(
                  name: 'Advanced State Management',
                  teacher: 'Dr. Riverpod',
                  code: 'CS202',
                  status: '8 topics · 0 quizzes done',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBellButton() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.border),
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.notifications_none, color: AppTheme.text, size: 22),
          Positioned(
            top: 8,
            right: 10,
            child: CircleAvatar(
              radius: 4,
              backgroundColor: AppTheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard({
    required String name,
    required String teacher,
    required String code,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.successSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.text),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  teacher,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}
