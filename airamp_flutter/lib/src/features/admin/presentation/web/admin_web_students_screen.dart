import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../data/admin_repository.dart';

class AdminWebStudentsScreen extends ConsumerStatefulWidget {
  const AdminWebStudentsScreen({super.key});

  @override
  ConsumerState<AdminWebStudentsScreen> createState() => _AdminWebStudentsScreenState();
}

class _AdminWebStudentsScreenState extends ConsumerState<AdminWebStudentsScreen> {
  final _searchController = TextEditingController();
  String _selectedSection = 'All';
  String _selectedGrade = 'All';

  final List<String> _gradeOptions = ['All', 'Grade 10', 'Grade 11', 'Grade 12'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    ref.read(adminStudentsProvider.notifier).loadStudents(
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
    final students = ref.watch(adminStudentsProvider);
    final availableSectionsAsync = ref.watch(availableSectionsProvider);
    final availableSections = availableSectionsAsync.value ?? ['STEM A', 'STEM B', 'STEM C', 'Emerald', 'Ruby'];

    final sectionFilterList = ['All', ...availableSections, 'Unassigned'];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(adminStudentsProvider.notifier).loadStudents();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
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
                        Text(
                          'Student Management & Section Arrangement',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Inspect student enrollments, academic records, and assign students to perspective sections',
                          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      '${students.length} Students Listed',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filter Controls Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Search Bar
                        Expanded(
                          flex: 5,
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: AppTheme.text, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search student name, email, or section...',
                              prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref.read(adminStudentsProvider.notifier).loadStudents(query: '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: AppTheme.background,
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppTheme.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppTheme.border),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Grade Dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedGrade,
                            dropdownColor: AppTheme.surface,
                            style: TextStyle(color: AppTheme.text, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Grade Level',
                              labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              filled: true,
                              fillColor: AppTheme.background,
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppTheme.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppTheme.border),
                              ),
                            ),
                            items: _gradeOptions.map((g) {
                              return DropdownMenuItem(value: g, child: Text(g));
                            }).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => _selectedGrade = val);
                              ref.read(adminStudentsProvider.notifier).loadStudents(grade: val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section Filter Chips
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Filter Section:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 34,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: sectionFilterList.length,
                              itemBuilder: (context, index) {
                                final sec = sectionFilterList[index];
                                final isSelected = _selectedSection == sec;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(sec),
                                    selected: isSelected,
                                    selectedColor: AppTheme.primary,
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                                    ),
                                    backgroundColor: AppTheme.background,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
                                    onSelected: (_) {
                                      setState(() => _selectedSection = sec);
                                      ref.read(adminStudentsProvider.notifier).loadStudents(section: sec);
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Student Table or Empty State
              if (students.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.person_search_outlined, size: 54, color: AppTheme.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        'No Students Found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try clearing your search query or adjusting the section/grade filter chips.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 800;

                    if (isWide) {
                      return _buildDesktopStudentTable(students, availableSections);
                    } else {
                      return _buildMobileStudentCards(students, availableSections);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopStudentTable(List<Map<String, dynamic>> students, List<String> availableSections) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.background),
          dataRowMinHeight: 64,
          dataRowMaxHeight: 68,
          horizontalMargin: 20,
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('STUDENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ASSIGNED SECTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('GRADE LEVEL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ENROLLED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('QUIZ AVG', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ARRANGE SECTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          ],
          rows: students.map((s) {
            final studentId = s['id'] as String? ?? '';
            final name = s['full_name'] as String? ?? 'Student';
            final email = s['email'] as String? ?? '';
            final section = (s['section'] as String?)?.isNotEmpty == true ? s['section'] as String : 'Unassigned';
            final grade = (s['grade'] as String?)?.isNotEmpty == true ? s['grade'] as String : 'Unset';
            final enrolledCount = s['enrolled_courses'] as int? ?? 0;
            final avgScore = s['avg_score'] as int? ?? 0;

            final hasSection = section != 'Unassigned';

            return DataRow(
              cells: [
                // Student info
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primarySoft,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text)),
                          Text(email, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Assigned Section
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasSection ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasSection ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      section,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasSection ? AppTheme.primary : AppTheme.warning,
                      ),
                    ),
                  ),
                ),

                // Grade Level
                DataCell(
                  Text(grade, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ),

                // Enrolled courses
                DataCell(
                  Text(
                    '$enrolledCount subject${enrolledCount == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                  ),
                ),

                // Quiz average
                DataCell(
                  Text(
                    '$avgScore%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: avgScore >= 75 ? AppTheme.success : AppTheme.textSecondary,
                    ),
                  ),
                ),

                // Action: Arrange Section
                DataCell(
                  ElevatedButton.icon(
                    onPressed: () => _showArrangeSectionDialog(studentId, name, section, grade, availableSections),
                    icon: const Icon(Icons.sync_alt, size: 14),
                    label: const Text('Move / Assign'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                      foregroundColor: AppTheme.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileStudentCards(List<Map<String, dynamic>> students, List<String> availableSections) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: students.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = students[index];
        final studentId = s['id'] as String? ?? '';
        final name = s['full_name'] as String? ?? 'Student';
        final email = s['email'] as String? ?? '';
        final section = (s['section'] as String?)?.isNotEmpty == true ? s['section'] as String : 'Unassigned';
        final grade = (s['grade'] as String?)?.isNotEmpty == true ? s['grade'] as String : 'Unset';
        final enrolledCount = s['enrolled_courses'] as int? ?? 0;
        final avgScore = s['avg_score'] as int? ?? 0;

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
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primarySoft,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'S',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.text)),
                        Text(email, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      section,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Grade: $grade', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  Text('Courses: $enrolledCount', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  Text('Quiz Avg: $avgScore%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showArrangeSectionDialog(studentId, name, section, grade, availableSections),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Arrange Perspective Section'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showArrangeSectionDialog(
    String studentId,
    String studentName,
    String currentSection,
    String currentGrade,
    List<String> availableSections,
  ) {
    String destinationSection = availableSections.contains(currentSection) ? currentSection : availableSections.first;
    String destinationGrade = currentGrade != 'Unset' ? currentGrade : 'Grade 10';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(Icons.groups_outlined, color: AppTheme.primary, size: 24),
                const SizedBox(width: 10),
                Text('Arrange Student Section', style: TextStyle(fontSize: 18, color: AppTheme.text)),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign or move "$studentName" to their perspective enrollment section.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 18),

                  // Current Info Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Section:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        Text(currentSection, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Destination Section Dropdown
                  Text('Target Enrollment Section', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: destinationSection,
                    dropdownColor: AppTheme.surface,
                    style: TextStyle(color: AppTheme.text, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.background,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                    ),
                    items: availableSections.map((sec) {
                      return DropdownMenuItem(value: sec, child: Text(sec));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => destinationSection = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Target Grade Level Dropdown
                  Text('Grade Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: destinationGrade,
                    dropdownColor: AppTheme.surface,
                    style: TextStyle(color: AppTheme.text, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.background,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Grade 10', child: Text('Grade 10')),
                      DropdownMenuItem(value: 'Grade 11', child: Text('Grade 11')),
                      DropdownMenuItem(value: 'Grade 12', child: Text('Grade 12')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => destinationGrade = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogCtx);
                  await ref.read(adminStudentsProvider.notifier).reassignSection(
                        studentId,
                        destinationSection,
                        newGrade: destinationGrade,
                      );
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Successfully assigned $studentName to $destinationSection ($destinationGrade)'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  minimumSize: const Size(0, 40),
                ),
                child: const Text('Save & Reassign', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
