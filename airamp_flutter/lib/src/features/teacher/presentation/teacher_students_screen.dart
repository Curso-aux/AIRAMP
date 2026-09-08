import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../admin/data/admin_repository.dart';
import '../../chat/application/chat_provider.dart';
import '../data/teacher_repository.dart';

class TeacherStudentsScreen extends ConsumerStatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  ConsumerState<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends ConsumerState<TeacherStudentsScreen> {
  final _searchController = TextEditingController();
  String _selectedSection = 'All Sections';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    ref.read(teacherStudentsProvider.notifier).reload(
          section: _selectedSection == 'All Sections' ? null : _selectedSection,
          query: _searchController.text.trim(),
        );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final students = ref.watch(teacherStudentsProvider);
    final sectionsAsync = ref.watch(availableSectionsProvider);

    final sectionOptions = ['All Sections', ...sectionsAsync.value ?? []];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(teacherStudentsProvider.notifier).reload(
                  section: _selectedSection == 'All Sections' ? null : _selectedSection,
                  query: _searchController.text.trim(),
                );
          },
          child: Column(
            children: [
              // Header & Search Area
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.people_alt, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enrolled Students',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${students.length} students enrolled in your subjects',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search input
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: AppTheme.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search by student name or email...',
                        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: AppTheme.textMuted, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Section filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: sectionOptions.map((sec) {
                          final isSelected = _selectedSection == sec;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(sec),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedSection = sec;
                                });
                                ref.read(teacherStudentsProvider.notifier).reload(
                                      section: sec == 'All Sections' ? null : sec,
                                      query: _searchController.text.trim(),
                                    );
                              },
                              backgroundColor: AppTheme.surface,
                              selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppTheme.primary : AppTheme.text,
                              ),
                              side: BorderSide(
                                color: isSelected ? AppTheme.primary : AppTheme.border,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTheme.border),

              // Student list
              Expanded(
                child: students.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_outlined, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'No students found',
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No enrolled students match the active search or section filter.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        final studentId = student['id'] as String? ?? '';
                        final name = student['full_name']?.toString() ?? 'Student';
                        final email = student['email']?.toString() ?? '';
                        final section = student['section']?.toString() ?? 'Unassigned';
                        final grade = student['grade']?.toString() ?? '';
                        final completedLos = student['completed_los'] as int? ?? 0;
                        final enrolledSubjects = student['enrolled_subjects'] as int? ?? 1;

                        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
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
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppTheme.text,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.border.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            grade.isNotEmpty ? '$section · $grade' : section,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.text,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      email,
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 14, color: AppTheme.success),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$completedLos LOs Completed',
                                          style: TextStyle(fontSize: 11, color: AppTheme.text),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(Icons.book_outlined, size: 14, color: AppTheme.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$enrolledSubjects Subjects',
                                          style: TextStyle(fontSize: 11, color: AppTheme.text),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.chat_bubble_outline, color: AppTheme.primary, size: 20),
                                tooltip: 'Consult / Message',
                                onPressed: () async {
                                  if (studentId.isNotEmpty) {
                                    final conv = await ref
                                        .read(chatProvider.notifier)
                                        .getOrCreateConversation(studentId);
                                    if (conv != null && context.mounted) {
                                      context.push('/chat/${conv.id}');
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
