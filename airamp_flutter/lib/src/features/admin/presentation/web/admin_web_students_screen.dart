import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../data/admin_repository.dart';
import 'components/bulk_import_modal.dart';

class AdminWebStudentsScreen extends ConsumerStatefulWidget {
  const AdminWebStudentsScreen({super.key});

  @override
  ConsumerState<AdminWebStudentsScreen> createState() => _AdminWebStudentsScreenState();
}

class _AdminWebStudentsScreenState extends ConsumerState<AdminWebStudentsScreen> {
  final _searchController = TextEditingController();
  
  // Year Level & Classroom hierarchy state
  String _selectedGrade = 'Grade 10';
  String _selectedSection = 'All';
  bool _isSpecialView = false;
  bool _isAllDirectoryView = false;
  String _specialSubFilter = 'All'; // 'All', 'Irregular', 'Transferee', 'SPED', 'Unassigned'

  final List<String> _defaultGrades = [
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleExportCsv(List<Map<String, dynamic>> students) async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No student records available to export.')),
      );
      return;
    }

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final fileName = 'students_roster_$dateStr.csv';

    // Determine current scope label for display
    String scopeLabel;
    if (_searchController.text.trim().isNotEmpty) {
      scopeLabel = 'Search Filter ("${_searchController.text.trim()}")';
    } else if (_isSpecialView) {
      scopeLabel = 'Special Students (${_specialSubFilter == 'All' ? 'All Special' : _specialSubFilter})';
    } else if (_isAllDirectoryView) {
      scopeLabel = 'All School Students Master List';
    } else {
      scopeLabel = '$_selectedGrade • ${_selectedSection == 'All' ? 'All Classrooms' : _selectedSection}';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.file_download_outlined, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Confirm CSV Export',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to export student records to a CSV file?',
                  style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Records to Export:', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                          Text('${students.length} student(s)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.text)),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Scope:', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                          Flexible(
                            child: Text(
                              scopeLabel,
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Target File:', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                          Text(fileName, style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: AppTheme.text)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Export CSV', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 0,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final csvString = ref.read(adminStudentsProvider.notifier).exportStudentsCsv(studentsToExport: students);
    downloadCsvFile(csvString, fileName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_done, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Exported ${students.length} student records to $fileName'),
          ],
        ),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final allStudents = ref.watch(adminStudentsProvider);
    final availableSectionsAsync = ref.watch(availableSectionsProvider);
    final availableSections = availableSectionsAsync.value ?? ['STEM A', 'STEM B', 'STEM C', 'Emerald', 'Ruby'];
    final subjects = ref.watch(subjectsProvider);

    // Compute all dynamic grade levels present
    final Set<String> presentGrades = {};
    for (final s in allStudents) {
      final g = s['grade'] as String?;
      if (g != null && g.isNotEmpty && g != 'Unset') {
        presentGrades.add(g);
      }
    }

    // Always include all standard Philippine curriculum year levels (Grade 7 - Grade 12)
    final List<String> displayedGrades = List<String>.from(_defaultGrades);
    for (final g in presentGrades) {
      if (!displayedGrades.contains(g)) {
        displayedGrades.add(g);
      }
    }

    // Identify Special students (Irregular, SPED, Transferee, Unassigned, or non-regular)
    final specialStudents = allStudents.where((s) {
      final type = (s['student_type'] as String? ?? 'regular').toLowerCase();
      final sec = (s['section'] as String? ?? '').toLowerCase();
      final hasSpecialNotes = (s['special_notes'] as String?)?.isNotEmpty == true;
      return type != 'regular' || sec == 'unassigned' || sec.isEmpty || hasSpecialNotes;
    }).toList();

    // Determine current filtered student list
    List<Map<String, dynamic>> filteredStudents;
    final query = _searchController.text.trim().toLowerCase();

    if (query.isNotEmpty) {
      filteredStudents = allStudents.where((s) {
        final name = (s['full_name'] as String? ?? '').toLowerCase();
        final email = (s['email'] as String? ?? '').toLowerCase();
        final sec = (s['section'] as String? ?? '').toLowerCase();
        final grade = (s['grade'] as String? ?? '').toLowerCase();
        return name.contains(query) || email.contains(query) || sec.contains(query) || grade.contains(query);
      }).toList();
    } else if (_isSpecialView) {
      filteredStudents = specialStudents.where((s) {
        if (_specialSubFilter == 'All') return true;
        final type = (s['student_type'] as String? ?? '').toLowerCase();
        final sec = (s['section'] as String? ?? '').toLowerCase();
        if (_specialSubFilter == 'Unassigned') return sec == 'unassigned' || sec.isEmpty;
        if (_specialSubFilter == 'Irregular') return type.contains('irregular') || type.contains('cross');
        if (_specialSubFilter == 'SPED') return type.contains('sped') || type.contains('accommodat');
        if (_specialSubFilter == 'Transferee') return type.contains('transferee');
        return true;
      }).toList();
    } else if (_isAllDirectoryView) {
      filteredStudents = allStudents;
    } else {
      // Scoped exclusively to the chosen Year Level
      filteredStudents = allStudents.where((s) {
        final g = s['grade'] as String? ?? '';
        final sec = s['section'] as String? ?? '';
        final matchesGrade = g == _selectedGrade || sec.contains(_selectedGrade);
        if (!matchesGrade) return false;

        if (_selectedSection != 'All') {
          return sec == _selectedSection || sec.endsWith(_selectedSection);
        }
        return true;
      }).toList();
    }

    // Classrooms belonging to currently selected Year Level
    final classroomsInSelectedGrade = <String>[];
    for (final sec in availableSections) {
      final secUpper = sec.toUpperCase();
      final gradeUpper = _selectedGrade.toUpperCase();
      // Match if section belongs to this grade explicitly or has students in this grade
      final belongsToGrade = secUpper.contains(gradeUpper) ||
          allStudents.any((s) => (s['grade'] == _selectedGrade && s['section'] == sec));
      if (belongsToGrade && !classroomsInSelectedGrade.contains(sec)) {
        classroomsInSelectedGrade.add(sec);
      }
    }
    // If no explicit match, fallback to sections assigned to students in this grade
    if (classroomsInSelectedGrade.isEmpty) {
      for (final s in allStudents) {
        if (s['grade'] == _selectedGrade) {
          final sec = s['section'] as String?;
          if (sec != null && sec.isNotEmpty && sec != 'Unassigned' && !classroomsInSelectedGrade.contains(sec)) {
            classroomsInSelectedGrade.add(sec);
          }
        }
      }
    }
    // If still empty, show all available sections so admin can assign students
    if (classroomsInSelectedGrade.isEmpty) {
      classroomsInSelectedGrade.addAll(availableSections);
    }

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
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isNarrow = headerConstraints.maxWidth < 760;

                  final titleSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Management & Section Arrangement',
                        style: TextStyle(
                          fontSize: isNarrow ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Organized by Year Level ➔ Classroom Section ➔ Student, with specialized student tracking',
                        style: TextStyle(fontSize: isNarrow ? 12.5 : 14, color: AppTheme.textSecondary),
                      ),
                    ],
                  );

                  final actionButtons = Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _handleExportCsv(filteredStudents),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Export CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.text,
                          side: BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => BulkImportModal.show(context),
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('Import CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.text,
                          side: BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openAddStudentDialog(context, availableSections, subjects),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                        label: const Text('Add New Student', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          '${allStudents.length} Students Listed',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ),
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleSection,
                        const SizedBox(height: 14),
                        actionButtons,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 16),
                      actionButtons,
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Global Search Bar
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TextField(
                  controller: _searchController,
                  maxLength: 60,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  style: TextStyle(color: AppTheme.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search student name, email, or section across school...',
                    counterText: '',
                    prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Hierarchy Navigation Container
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // STEP 1: YEAR LEVEL SELECTOR
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'STEP 1',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Choose Year Level:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const Spacer(),
                        // View mode indicators
                        if (_isSpecialView)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, size: 13, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Special Students Active',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Year Level Chips + Special Student Option
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Standard Year Levels
                          ...displayedGrades.map((grade) {
                            final isSelected = !_isSpecialView && !_isAllDirectoryView && _selectedGrade == grade;
                            final count = allStudents.where((s) => s['grade'] == grade).length;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                avatar: Icon(
                                  Icons.school_outlined,
                                  size: 15,
                                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                                ),
                                label: Text('$grade ($count)'),
                                selected: isSelected,
                                selectedColor: AppTheme.primary,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                                ),
                                backgroundColor: AppTheme.background,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
                                onSelected: (_) {
                                  setState(() {
                                    _selectedGrade = grade;
                                    _selectedSection = 'All';
                                    _isSpecialView = false;
                                    _isAllDirectoryView = false;
                                  });
                                },
                              ),
                            );
                          }),

                          // Divider
                          Container(
                            height: 24,
                            width: 1,
                            color: AppTheme.border,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                          ),

                          // Special Students Option
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: Icon(
                                Icons.workspace_premium_outlined,
                                size: 15,
                                color: _isSpecialView ? Colors.white : AppTheme.textSecondary,
                              ),
                              label: Text('Special Students (${specialStudents.length})'),
                              selected: _isSpecialView,
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: _isSpecialView ? FontWeight.bold : FontWeight.w500,
                                color: _isSpecialView ? Colors.white : AppTheme.textSecondary,
                              ),
                              backgroundColor: AppTheme.background,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              side: BorderSide(color: _isSpecialView ? AppTheme.primary : AppTheme.border),
                              onSelected: (_) {
                                setState(() {
                                  _isSpecialView = true;
                                  _isAllDirectoryView = false;
                                });
                              },
                            ),
                          ),

                          // All Directory View
                          ChoiceChip(
                            avatar: Icon(
                              Icons.list_alt_rounded,
                              size: 15,
                              color: _isAllDirectoryView ? Colors.white : AppTheme.textSecondary,
                            ),
                            label: Text('All Students (${allStudents.length})'),
                            selected: _isAllDirectoryView,
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: _isAllDirectoryView ? FontWeight.bold : FontWeight.w500,
                              color: _isAllDirectoryView ? Colors.white : AppTheme.textSecondary,
                            ),
                            backgroundColor: AppTheme.background,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            side: BorderSide(color: _isAllDirectoryView ? AppTheme.primary : AppTheme.border),
                            onSelected: (_) {
                              setState(() {
                                _isAllDirectoryView = true;
                                _isSpecialView = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Divider(height: 1, color: AppTheme.border),
                    const SizedBox(height: 16),

                    // STEP 2: CLASSROOM / SECTION SELECTOR (OR SPECIAL SUB-FILTER)
                    if (_isSpecialView) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'TRACK',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Special Student Category:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            {'id': 'All', 'name': 'All Special', 'count': specialStudents.length},
                            {'id': 'Irregular', 'name': 'Irregular', 'count': specialStudents.where((s) => (s['student_type'] as String? ?? '').toLowerCase().contains('irregular')).length},
                            {'id': 'Transferee', 'name': 'Transferee', 'count': specialStudents.where((s) => (s['student_type'] as String? ?? '').toLowerCase().contains('transferee')).length},
                            {'id': 'SPED', 'name': 'SPED', 'count': specialStudents.where((s) => (s['student_type'] as String? ?? '').toLowerCase().contains('sped')).length},
                            {'id': 'Unassigned', 'name': 'Unassigned', 'count': specialStudents.where((s) {
                              final sec = (s['section'] as String? ?? '').toLowerCase();
                              return sec == 'unassigned' || sec.isEmpty;
                            }).length},
                          ].map((item) {
                            final cat = item['id'] as String;
                            final name = item['name'] as String;
                            final count = item['count'] as int;
                            final isSel = _specialSubFilter == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(name),
                                    const SizedBox(width: 4),
                                    Text(
                                      '($count)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.normal,
                                        color: isSel ? Colors.white : AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                selected: isSel,
                                selectedColor: AppTheme.primary,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                  color: isSel ? Colors.white : AppTheme.textSecondary,
                                ),
                                backgroundColor: AppTheme.background,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: BorderSide(color: isSel ? AppTheme.primary : AppTheme.border),
                                onSelected: (_) => setState(() => _specialSubFilter = cat),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ] else if (!_isAllDirectoryView) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'STEP 2',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Choose Classroom in $_selectedGrade:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // "All Classrooms in Grade" chip
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text('All $_selectedGrade Classrooms'),
                                selected: _selectedSection == 'All',
                                selectedColor: AppTheme.primary,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedSection == 'All' ? FontWeight.bold : FontWeight.normal,
                                  color: _selectedSection == 'All' ? Colors.white : AppTheme.textSecondary,
                                ),
                                backgroundColor: AppTheme.background,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: BorderSide(color: _selectedSection == 'All' ? AppTheme.primary : AppTheme.border),
                                onSelected: (_) => setState(() => _selectedSection = 'All'),
                              ),
                            ),

                            // Specific Classroom chips
                            ...classroomsInSelectedGrade.map((sec) {
                              final isSel = _selectedSection == sec;
                              final count = allStudents.where((s) {
                                final sGrade = s['grade'] as String? ?? '';
                                final sSec = s['section'] as String? ?? '';
                                return (sGrade == _selectedGrade || sSec.contains(_selectedGrade)) &&
                                    (sSec == sec || sSec.endsWith(sec));
                              }).length;

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  avatar: Icon(Icons.meeting_room_outlined, size: 14, color: isSel ? Colors.white : AppTheme.primary),
                                  label: Text('$sec ($count)'),
                                  selected: isSel,
                                  selectedColor: AppTheme.primary,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    color: isSel ? Colors.white : AppTheme.textSecondary,
                                  ),
                                  backgroundColor: AppTheme.background,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  side: BorderSide(color: isSel ? AppTheme.primary : AppTheme.border),
                                  onSelected: (_) => setState(() => _selectedSection = sec),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Active Scoped Scope Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSpecialView
                          ? Icons.workspace_premium_outlined
                          : (_isAllDirectoryView ? Icons.folder_shared_outlined : Icons.account_tree_outlined),
                      size: 20,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isSpecialView
                            ? 'Special Students Hub — Showing ${_specialSubFilter == 'All' ? 'all special, irregular, SPED, and unassigned students' : 'category: $_specialSubFilter'}'
                            : (_isAllDirectoryView
                                ? 'Full School Student Directory (All Grade Levels)'
                                : 'Active Scope: $_selectedGrade ➔ ${_selectedSection == 'All' ? 'All Classrooms' : 'Classroom: $_selectedSection'} (${filteredStudents.length} Students)'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                    if (_selectedSection != 'All' || _isSpecialView || _isAllDirectoryView)
                      TextButton.icon(
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: const Text('Reset Filter', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                        onPressed: () {
                          setState(() {
                            _selectedGrade = 'Grade 10';
                            _selectedSection = 'All';
                            _isSpecialView = false;
                            _isAllDirectoryView = false;
                            _searchController.clear();
                          });
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Student Table or Empty State
              if (filteredStudents.isEmpty)
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
                      Icon(
                        _isSpecialView ? Icons.workspace_premium_outlined : Icons.person_search_outlined,
                        size: 54,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isSpecialView ? 'No Special Students Found' : 'No Students In This Classroom / Grade',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSpecialView
                            ? 'You can tag any student as a Special Student to manage their individualized curriculum.'
                            : 'No students are currently enrolled in this specific grade and classroom.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _openAddStudentDialog(context, availableSections, subjects),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                        label: const Text('Add Student to This Classroom'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 800;

                    if (isWide) {
                      return _buildDesktopStudentTable(filteredStudents, availableSections);
                    } else {
                      return _buildMobileStudentCards(filteredStudents, availableSections);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1080),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.background),
              dataRowMinHeight: 64,
              dataRowMaxHeight: 70,
              horizontalMargin: 20,
              columnSpacing: 22,
              columns: const [
                DataColumn(label: Text('STUDENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('ASSIGNED SECTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('GRADE LEVEL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('CLASSIFICATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('ENROLLED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('QUIZ AVG', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              ],
              rows: students.map((s) {
                final studentId = s['id'] as String? ?? '';
                final name = s['full_name'] as String? ?? 'Student';
                final email = s['email'] as String? ?? '';
                final section = (s['section'] as String?)?.isNotEmpty == true ? s['section'] as String : 'Unassigned';
                final grade = (s['grade'] as String?)?.isNotEmpty == true ? s['grade'] as String : 'Unset';
                final studentType = (s['student_type'] as String?)?.isNotEmpty == true ? s['student_type'] as String : 'regular';
                final notes = s['special_notes'] as String?;
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
                            radius: 17,
                            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'S',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                              ),
                              const SizedBox(height: 2),
                              Text(email, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Assigned Section
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: hasSection
                              ? (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC))
                              : (isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          section,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: hasSection ? FontWeight.w600 : FontWeight.w500,
                            color: hasSection ? AppTheme.text : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),

                    // Grade Level
                    DataCell(
                      Text(grade, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ),

                    // Classification (Regular / Special Student)
                    DataCell(
                      InkWell(
                        onTap: () => _showClassificationDialog(studentId, name, studentType, notes),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: studentType.toLowerCase() != 'regular'
                                ? AppTheme.primary.withValues(alpha: 0.08)
                                : (isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: studentType.toLowerCase() != 'regular'
                                  ? AppTheme.primary.withValues(alpha: 0.25)
                                  : AppTheme.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                studentType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: studentType.toLowerCase() != 'regular'
                                      ? (isDark ? const Color(0xFF5EEAD4) : AppTheme.primary)
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit_outlined,
                                size: 11,
                                color: studentType.toLowerCase() != 'regular'
                                    ? (isDark ? const Color(0xFF5EEAD4) : AppTheme.primary)
                                    : AppTheme.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Enrolled courses
                    DataCell(
                      Text(
                        '$enrolledCount subject${enrolledCount == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                      ),
                    ),

                    // Quiz average
                    DataCell(
                      Text(
                        '$avgScore%',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: avgScore >= 75 ? AppTheme.success : AppTheme.textSecondary,
                        ),
                      ),
                    ),

                    // Actions: Manage Courses, Arrange Section & Delete
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showManageCoursesDialog(studentId, name),
                            icon: const Icon(Icons.menu_book_outlined, size: 14),
                            label: const Text('Courses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.text,
                              side: BorderSide(color: AppTheme.border),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            onPressed: () => _showArrangeSectionDialog(studentId, name, section, grade, availableSections),
                            icon: const Icon(Icons.swap_horiz, size: 14),
                            label: const Text('Move / Assign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.text,
                              side: BorderSide(color: AppTheme.border),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => _resendStudentCredentialsDialog(context, s),
                            tooltip: 'Resend Credentials Email',
                            icon: const Icon(Icons.forward_to_inbox_rounded, size: 17),
                            color: AppTheme.textSecondary,
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            onPressed: () => _confirmDeleteStudent(context, s),
                            tooltip: 'Delete student permanently',
                            icon: const Icon(Icons.delete_outline_rounded, size: 17),
                            color: AppTheme.error.withValues(alpha: 0.8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
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
        final studentType = (s['student_type'] as String?)?.isNotEmpty == true ? s['student_type'] as String : 'regular';
        final notes = s['special_notes'] as String?;
        final enrolledCount = s['enrolled_courses'] as int? ?? 0;
        final avgScore = s['avg_score'] as int? ?? 0;

        final hasSection = section != 'Unassigned';

        final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'S',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.text)),
                        const SizedBox(height: 2),
                        Text(email, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: hasSection
                          ? (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC))
                          : (isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      section,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: hasSection ? FontWeight.w600 : FontWeight.w500,
                        color: hasSection ? AppTheme.text : AppTheme.textMuted,
                      ),
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
                  InkWell(
                    onTap: () => _showClassificationDialog(studentId, name, studentType, notes),
                    child: Text(
                      'Type: ${studentType.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: studentType.toLowerCase() != 'regular'
                            ? (isDark ? const Color(0xFF5EEAD4) : AppTheme.primary)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Text('Courses: $enrolledCount', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  Text('Quiz Avg: $avgScore%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showManageCoursesDialog(studentId, name),
                      icon: const Icon(Icons.menu_book_outlined, size: 15),
                      label: const Text('Courses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.text,
                        side: BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showArrangeSectionDialog(studentId, name, section, grade, availableSections),
                      icon: const Icon(Icons.swap_horiz, size: 15),
                      label: const Text('Move / Assign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.text,
                        side: BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _resendStudentCredentialsDialog(context, s),
                    tooltip: 'Resend Credentials Email',
                    icon: const Icon(Icons.forward_to_inbox_rounded, size: 17),
                    color: AppTheme.textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () => _confirmDeleteStudent(context, s),
                    tooltip: 'Delete Student',
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    color: AppTheme.error.withValues(alpha: 0.8),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Classification Dialog: Regular vs Special Student
  void _showClassificationDialog(String studentId, String studentName, String currentType, String? currentNotes) {
    String selectedType = currentType.isNotEmpty ? currentType : 'regular';
    final notesController = TextEditingController(text: currentNotes ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(Icons.workspace_premium_outlined, color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Student Classification',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configure whether "$studentName" follows a regular cohort or an individualized special curriculum track.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 18),

                  Text('Classification Track', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    dropdownColor: AppTheme.surface,
                    style: TextStyle(color: AppTheme.text, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.background,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'regular', child: Text('Regular Student (Standard Section)')),
                      DropdownMenuItem(value: 'irregular', child: Text('Irregular / Cross-Enrolled')),
                      DropdownMenuItem(value: 'transferee', child: Text('Transferee / Bridging')),
                      DropdownMenuItem(value: 'sped', child: Text('SPED / Special Accommodations')),
                      DropdownMenuItem(value: 'accelerated', child: Text('Accelerated / Working Student')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  Text('Special Notes & Academic Adjustments (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLength: 500,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    maxLines: 3,
                    style: TextStyle(color: AppTheme.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g., Taking cross-grade subjects, remedial requirements, or individual education plan (IEP) notes...',
                      counterText: '',
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                    ),
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
                  await ref.read(adminStudentsProvider.notifier).updateStudentClassification(
                        studentId,
                        selectedType,
                        notes: notesController.text.trim(),
                      );
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Updated classification for $studentName to ${selectedType.toUpperCase()}'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Save Classification', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showArrangeSectionDialog(
    String studentId,
    String studentName,
    String currentSection,
    String currentGrade,
    List<String> availableSections,
  ) {
    String destinationSection = availableSections.contains(currentSection) ? currentSection : (availableSections.isNotEmpty ? availableSections.first : 'Emerald');
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
                      DropdownMenuItem(value: 'Grade 7', child: Text('Grade 7')),
                      DropdownMenuItem(value: 'Grade 8', child: Text('Grade 8')),
                      DropdownMenuItem(value: 'Grade 9', child: Text('Grade 9')),
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

  Future<void> _showManageCoursesDialog(String studentId, String studentName) async {
    final details = await DatabaseHelper().getStudentEnrollmentsWithDetails(studentId);
    if (!mounted) return;

    final selectedSubjectIds = details
        .where((d) => d['is_enrolled'] == true)
        .map((d) => d['id'] as int)
        .toSet();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.menu_book_outlined, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manage Course Enrollments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text)),
                      Text('for $studentName', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select or unselect courses to customize this student\'s curriculum. Changes take effect immediately in the student app.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (details.isEmpty)
                    Text('No subjects created in curriculum yet.', style: TextStyle(color: AppTheme.textMuted))
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: details.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: AppTheme.border),
                        itemBuilder: (ctx, i) {
                          final sub = details[i];
                          final id = sub['id'] as int;
                          final code = sub['subject_code'] as String? ?? '';
                          final name = sub['name'] as String? ?? 'Course';
                          final teacher = sub['teacher_name'] as String?;
                          final isChecked = selectedSubjectIds.contains(id);

                          return CheckboxListTile(
                            value: isChecked,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  selectedSubjectIds.add(id);
                                } else {
                                  selectedSubjectIds.remove(id);
                                }
                              });
                            },
                            title: Text(
                              code.isNotEmpty ? '$code — $name' : name,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                            ),
                            subtitle: teacher != null && teacher.isNotEmpty
                                ? Text('Instructor: $teacher', style: TextStyle(fontSize: 11, color: AppTheme.textMuted))
                                : null,
                            activeColor: AppTheme.primary,
                            dense: true,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(dialogCtx).pop();
                  await ref.read(adminStudentsProvider.notifier).updateStudentEnrollments(
                        studentId,
                        selectedSubjectIds.toList(),
                      );
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Updated course enrollments for $studentName (${selectedSubjectIds.length} courses)'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Save Enrollments'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteStudent(BuildContext context, Map<String, dynamic> student) {
    final studentId = student['id'] as String? ?? '';
    final studentName = student['full_name'] as String? ?? 'Student';
    final studentEmail = student['email'] as String? ?? '';
    final studentGrade = student['grade'] as String? ?? 'Unset';
    final studentSection = student['section'] as String? ?? 'Unassigned';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Delete Student Record',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you sure you want to permanently delete this student account?',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Student Name:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              Flexible(
                                child: Text(
                                  studentName,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.text),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Student ID / LRN:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              Text(
                                studentId,
                                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (studentEmail.isNotEmpty) ...[
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Email:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                Flexible(
                                  child: Text(
                                    studentEmail,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Classroom:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              Text(
                                '$studentGrade • $studentSection',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Warning: This action permanently deletes the student account from local and cloud databases. All subject enrollments, quiz scores, and submission records will be removed. This cannot be undone.',
                              style: TextStyle(fontSize: 11.5, color: Colors.red.shade700, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          try {
                            await ref
                                .read(adminStudentsProvider.notifier)
                                .deleteStudent(studentId)
                                .timeout(const Duration(seconds: 8));
                            if (context.mounted) {
                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text('Student "$studentName" ($studentId) was permanently deleted.'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to delete student: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 40),
                  ),
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete_forever, size: 18),
                  label: Text(isDeleting ? 'Deleting...' : 'Delete Student'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Resend Student Credentials Dialog ───────────────────────
  void _resendStudentCredentialsDialog(BuildContext context, Map<String, dynamic> student) {
    final studentId = student['id'] as String? ?? '';
    final studentName = student['full_name'] as String? ?? 'Student';
    final studentEmail = (student['email'] as String? ?? '').trim();

    if (studentEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot send email: This student has no email address configured.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final passwordCtrl = TextEditingController(text: 'Student@123');
    bool obscurePassword = false;
    bool isSending = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.forward_to_inbox_rounded, color: Colors.blue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resend Credentials Email',
                          style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Dispatches login details directly to student email via Gmail SMTP',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Recipient:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                Flexible(
                                  child: Text(
                                    studentName,
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.text),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Email Address:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                Flexible(
                                  child: Text(
                                    studentEmail,
                                    style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Student ID:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                Text(
                                  studentId,
                                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Temporary Password for Reset',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: obscurePassword,
                        style: TextStyle(color: AppTheme.text, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. Student@123',
                          prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppTheme.textMuted),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                          ),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                        ),
                        validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'The student password will be reset to this temporary password. Upon their next login, they will be required to change their password.',
                                style: TextStyle(fontSize: 11.5, color: AppTheme.text, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSending = true);
                          final newPass = passwordCtrl.text.trim();

                          final result = await DatabaseHelper().resetAndSendCredentials(
                            userId: studentId,
                            newPassword: newPass,
                          );

                          if (context.mounted) {
                            Navigator.of(dialogCtx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      result.success ? Icons.mark_email_read_rounded : Icons.warning_amber_rounded,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        result.success
                                            ? 'Credentials email dispatched to $studentEmail via Gmail SMTP! Password: $newPass'
                                            : 'Password updated to "$newPass", but email delivery failed: ${result.message}',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: result.success ? Colors.green.shade700 : Colors.amber.shade900,
                                duration: Duration(seconds: result.success ? 4 : 8),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 40),
                  ),
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(isSending ? 'Sending via SMTP...' : 'Send via SMTP'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Add New Student Dialog ──────────────────────────────────
  Future<void> _openAddStudentDialog(
    BuildContext context,
    List<String> availableSections,
    List<Map<String, dynamic>> availableSubjects,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nextId = await DatabaseHelper().generateNextStudentId();
    final studentIdCtrl = TextEditingController(text: nextId);
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: 'Student@123');
    final customSectionCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    if (!context.mounted) return;

    // Default grade & section based on currently active filter
    String selectedGrade = _selectedGrade != 'All' ? _selectedGrade : 'Grade 10';

    // Build clean list of section options
    final sectionOptions = <String>{};
    for (final s in availableSections) {
      if (s.isNotEmpty && s != 'All') sectionOptions.add(s);
    }
    sectionOptions.add('Diamond');
    sectionOptions.add('Emerald');
    sectionOptions.add('Ruby');
    sectionOptions.add('Sapphire');
    sectionOptions.add('STEM A');
    sectionOptions.add('STEM B');
    sectionOptions.add('Unassigned');

    String selectedSection = (_selectedSection != 'All' && _selectedSection.isNotEmpty)
        ? _selectedSection
        : (sectionOptions.contains('Diamond') ? 'Diamond' : sectionOptions.first);

    String selectedType = 'regular';
    final selectedSubjectIds = <int>{};
    bool obscurePassword = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Onboard New Student',
                          style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Creates student account & syncs immediately to Cloud Database',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Student Information', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: studentIdCtrl,
                          maxLength: 15,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          style: TextStyle(color: AppTheme.text, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Student ID (e.g. 001-0001)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            counterText: '',
                            prefixIcon: Icon(Icons.badge_outlined, size: 20, color: AppTheme.textMuted),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter student ID' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: nameCtrl,
                          maxLength: 50,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          style: TextStyle(color: AppTheme.text, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Full Name (e.g. Maria Clara Santos)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            counterText: '',
                            prefixIcon: Icon(Icons.person_outline, size: 20, color: AppTheme.textMuted),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter student full name' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: emailCtrl,
                          maxLength: 50,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          style: TextStyle(color: AppTheme.text, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'School Email (e.g. maria.santos@school.edu)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            counterText: '',
                            prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppTheme.textMuted),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter email';
                            if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email address';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: usernameCtrl,
                                maxLength: 30,
                                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                style: TextStyle(color: AppTheme.text, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Username (Optional)',
                                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  counterText: '',
                                  prefixIcon: Icon(Icons.alternate_email, size: 20, color: AppTheme.textMuted),
                                  filled: true,
                                  fillColor: AppTheme.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: passwordCtrl,
                                maxLength: 16,
                                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                obscureText: obscurePassword,
                                style: TextStyle(color: AppTheme.text, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Initial Password',
                                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  counterText: '',
                                  prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppTheme.textMuted),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 18,
                                      color: AppTheme.textMuted,
                                    ),
                                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                ),
                                validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Text('Academic Placement & Classroom', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedGrade,
                                dropdownColor: AppTheme.surface,
                                style: TextStyle(color: AppTheme.text, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Grade Level',
                                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  prefixIcon: Icon(Icons.school_outlined, size: 20, color: AppTheme.textMuted),
                                  filled: true,
                                  fillColor: AppTheme.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Grade 7', child: Text('Grade 7')),
                                  DropdownMenuItem(value: 'Grade 8', child: Text('Grade 8')),
                                  DropdownMenuItem(value: 'Grade 9', child: Text('Grade 9')),
                                  DropdownMenuItem(value: 'Grade 10', child: Text('Grade 10')),
                                  DropdownMenuItem(value: 'Grade 11', child: Text('Grade 11')),
                                  DropdownMenuItem(value: 'Grade 12', child: Text('Grade 12')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedGrade = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: sectionOptions.contains(selectedSection) ? selectedSection : null,
                                dropdownColor: AppTheme.surface,
                                style: TextStyle(color: AppTheme.text, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Classroom / Section',
                                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  prefixIcon: Icon(Icons.meeting_room_outlined, size: 20, color: AppTheme.textMuted),
                                  filled: true,
                                  fillColor: AppTheme.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                ),
                                items: [
                                  ...sectionOptions.map((sec) => DropdownMenuItem(value: sec, child: Text(sec))),
                                  const DropdownMenuItem(value: '__custom__', child: Text('+ Custom Section...')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedSection = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        if (selectedSection == '__custom__') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: customSectionCtrl,
                            maxLength: 40,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            style: TextStyle(color: AppTheme.text, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'New Section Name (e.g. Diamond-A)',
                              labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              counterText: '',
                              prefixIcon: Icon(Icons.add_box_outlined, size: 20, color: AppTheme.textMuted),
                              filled: true,
                              fillColor: AppTheme.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                            ),
                            validator: (v) => selectedSection == '__custom__' && (v == null || v.trim().isEmpty)
                                ? 'Please enter the section name'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          dropdownColor: AppTheme.surface,
                          style: TextStyle(color: AppTheme.text, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Student Classification',
                            labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            prefixIcon: Icon(Icons.badge_outlined, size: 20, color: AppTheme.textMuted),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'regular', child: Text('Regular Student (Standard Curriculum)')),
                            DropdownMenuItem(value: 'irregular', child: Text('Irregular / Cross-Enrollee')),
                            DropdownMenuItem(value: 'transferee', child: Text('Transferee Student')),
                            DropdownMenuItem(value: 'sped', child: Text('SPED / Accommodated Student')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedType = val);
                          },
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: notesCtrl,
                          maxLength: 500,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          maxLines: 2,
                          style: TextStyle(color: AppTheme.text, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Special Notes / Learning Accommodations (Optional)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            hintText: 'e.g. Needs front row seating, transfer student from St. Jude...',
                            counterText: '',
                            hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            prefixIcon: Icon(Icons.note_alt_outlined, size: 20, color: AppTheme.textMuted),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text('Initial Course Enrollments (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Courses will also auto-enroll based on section assignment.', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        const SizedBox(height: 8),
                        if (availableSubjects.isEmpty)
                          Text('No curriculum subjects configured yet.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 160),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: availableSubjects.length,
                              separatorBuilder: (_, _) => Divider(height: 1, color: AppTheme.border),
                              itemBuilder: (ctx, i) {
                                final sub = availableSubjects[i];
                                final id = sub['id'] as int;
                                final name = sub['name'] as String? ?? 'Subject';
                                final code = sub['subject_code'] as String? ?? '';
                                final teacher = sub['teacher_name'] as String?;
                                final isSelected = selectedSubjectIds.contains(id);

                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedSubjectIds.add(id);
                                      } else {
                                        selectedSubjectIds.remove(id);
                                      }
                                    });
                                  },
                                  title: Text(
                                    code.isNotEmpty ? '$code — $name' : name,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                                  ),
                                  subtitle: teacher != null && teacher.isNotEmpty
                                      ? Text('Teacher: $teacher', style: TextStyle(fontSize: 11, color: AppTheme.textMuted))
                                      : null,
                                  activeColor: AppTheme.primary,
                                  dense: true,
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.mark_email_read_outlined, size: 20, color: AppTheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'SMTP Email Delivery: Student ID, username, and password will be sent automatically to the student\'s email via Gmail SMTP.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.text, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final finalSection = selectedSection == '__custom__'
                              ? (customSectionCtrl.text.trim().isNotEmpty ? customSectionCtrl.text.trim() : 'Unassigned')
                              : selectedSection;

                          try {
                            await ref.read(adminStudentsProvider.notifier).addStudent(
                                  id: studentIdCtrl.text.trim().isNotEmpty ? studentIdCtrl.text.trim() : null,
                                  fullName: nameCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  password: passwordCtrl.text.trim(),
                                  username: usernameCtrl.text.trim().isNotEmpty ? usernameCtrl.text.trim() : null,
                                  grade: selectedGrade,
                                  section: finalSection,
                                  studentType: selectedType,
                                  specialNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                  enrollSubjectIds: selectedSubjectIds.isNotEmpty ? selectedSubjectIds.toList() : null,
                                );
                            final emailResult = EmailService.lastResult;
                            final emailSent = emailResult?.success ?? false;

                            if (context.mounted) {
                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        emailSent ? Icons.mark_email_read_rounded : Icons.warning_amber_rounded,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          emailSent
                                              ? 'Student "${nameCtrl.text.trim()}" onboarded! Credentials sent to ${emailCtrl.text.trim()} via Gmail SMTP!'
                                              : 'Student "${nameCtrl.text.trim()}" created! Note: SMTP email could not be delivered (${emailResult?.message ?? "SMTP bridge error"}). You can resend anytime using the Resend button.',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: emailSent ? AppTheme.success : AppTheme.warning,
                                  duration: Duration(seconds: emailSent ? 4 : 8),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 40),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add Student'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
