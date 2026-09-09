import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../admin/data/admin_repository.dart';
import '../../chat/application/chat_provider.dart';
import '../data/teacher_repository.dart';

class TeacherStudentsScreen extends ConsumerStatefulWidget {
  final String? initialSection;

  const TeacherStudentsScreen({super.key, this.initialSection});

  @override
  ConsumerState<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends ConsumerState<TeacherStudentsScreen> {
  final _searchController = TextEditingController();
  late String _selectedSection;

  @override
  void initState() {
    super.initState();
    _selectedSection = (widget.initialSection != null && widget.initialSection!.isNotEmpty)
        ? widget.initialSection!
        : 'All Sections';

    _searchController.addListener(_onSearchChanged);

    // Initial load with selected section if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherStudentsProvider.notifier).reload(
            section: _selectedSection == 'All Sections' ? null : _selectedSection,
            query: _searchController.text.trim(),
          );
    });
  }

  @override
  void didUpdateWidget(covariant TeacherStudentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSection != null &&
        widget.initialSection != oldWidget.initialSection &&
        widget.initialSection != _selectedSection) {
      setState(() {
        _selectedSection = widget.initialSection!;
      });
      ref.read(teacherStudentsProvider.notifier).reload(
            section: _selectedSection == 'All Sections' ? null : _selectedSection,
            query: _searchController.text.trim(),
          );
    }
  }

  void _onSearchChanged() {
    ref.read(teacherStudentsProvider.notifier).reload(
          section: _selectedSection == 'All Sections' ? null : _selectedSection,
          query: _searchController.text.trim(),
        );
  }

  void _onSelectSection(String section) {
    setState(() {
      _selectedSection = section;
    });
    ref.read(teacherStudentsProvider.notifier).reload(
          section: section == 'All Sections' ? null : section,
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
    final sectionsDetailsAsync = ref.watch(teacherHandledSectionsDetailsProvider);
    final sectionsListAsync = ref.watch(availableSectionsProvider);

    final handledSections = sectionsDetailsAsync.value ?? [];
    final fallbackSections = sectionsListAsync.value ?? [];

    // Construct filter chip options — only show sections the teacher handles
    final handledNames = handledSections.map((s) => s['name'] as String).toList();
    final sectionChipNames = handledNames.isNotEmpty ? handledNames : fallbackSections;
    final combinedSections = <String>{'All Sections', ...sectionChipNames}.toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(teacherStudentsProvider.notifier).reload(
                    section: _selectedSection == 'All Sections' ? null : _selectedSection,
                    query: _searchController.text.trim(),
                  ),
              ref.refresh(teacherHandledSectionsDetailsProvider.future),
              ref.refresh(teacherHandledSectionsProvider.future),
            ]);
          },
          child: Column(
            children: [
              // Header & Section Exploration Area
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header title & count
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Handled Sections & Roster',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedSection == 'All Sections'
                                    ? '${students.length} students across your handled sections'
                                    : '${students.length} students enrolled in Section $_selectedSection',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section Cards Overview (Handled Sections)
                    if (handledSections.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Handled Sections',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                            ),
                          ),
                          if (_selectedSection != 'All Sections')
                            GestureDetector(
                              onTap: () => _onSelectSection('All Sections'),
                              child: Text(
                                'View All',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 94,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          children: [
                            // "All Sections" Card
                            _buildSectionCard(
                              name: 'All Sections',
                              grade: 'All Levels',
                              studentCount: handledSections.fold<int>(
                                0,
                                (sum, s) => sum + (s['student_count'] as int? ?? 0),
                              ),
                              isSelected: _selectedSection == 'All Sections',
                              onTap: () => _onSelectSection('All Sections'),
                              isAllCard: true,
                            ),
                            // Individual Handled Section Cards
                            ...handledSections.map((sec) {
                              final name = sec['name'] as String? ?? 'Section';
                              final grade = sec['grade'] as String? ?? '';
                              final count = sec['student_count'] as int? ?? 0;
                              final isSelected = _selectedSection.toLowerCase() == name.toLowerCase();

                              return _buildSectionCard(
                                name: name,
                                grade: grade,
                                studentCount: count,
                                isSelected: isSelected,
                                onTap: () => _onSelectSection(name),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Search input
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: AppTheme.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _selectedSection == 'All Sections'
                            ? 'Search students across all sections...'
                            : 'Search students in $_selectedSection...',
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
                    const SizedBox(height: 10),

                    // Filter chips row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: combinedSections.map((sec) {
                          final isSelected = _selectedSection.toLowerCase() == sec.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(sec),
                              selected: isSelected,
                              onSelected: (_) => _onSelectSection(sec),
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

              // Active Section Banner (when a specific section is chosen)
              if (_selectedSection != 'All Sections')
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.layers, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Showing students in section: $_selectedSection',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text('Clear Filter', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _onSelectSection('All Sections'),
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
                              _selectedSection == 'All Sections'
                                  ? 'No students found'
                                  : 'No students in Section $_selectedSection',
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.text),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No students matched "${_searchController.text}". Try clearing the search.'
                                  : 'No enrolled students are currently assigned to this class section.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            if (_selectedSection != 'All Sections') ...[
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _onSelectSection('All Sections'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text('View All Sections', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          final studentId = student['id'] as String? ?? '';
                          final name = student['full_name']?.toString() ?? 'Student';
                          final email = student['email']?.toString() ?? '';
                          final section = student['section']?.toString() ?? 'Unassigned';
                          final grade = student['grade']?.toString() ?? '';
                          final completedLos = student['completed_los'] as int? ?? 0;
                          final enrolledSubjects = student['enrolled_subjects'] as int? ?? 0;
                          final isEnrolled = student['is_enrolled'] == true || (student['is_enrolled'] == 1);

                          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isEnrolled
                                    ? AppTheme.primary.withValues(alpha: 0.2)
                                    : AppTheme.border,
                              ),
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
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 4,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle_outline, size: 14, color: AppTheme.success),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$completedLos LOs Completed',
                                                style: TextStyle(fontSize: 11, color: AppTheme.text),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
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

  Widget _buildSectionCard({
    required String name,
    required String grade,
    required int studentCount,
    required bool isSelected,
    required VoidCallback onTap,
    bool isAllCard = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  isAllCard ? Icons.grid_view_rounded : Icons.layers,
                  size: 16,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? AppTheme.primary : AppTheme.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              grade,
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : AppTheme.border.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$studentCount ${studentCount == 1 ? 'Student' : 'Students'}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.primary : AppTheme.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
