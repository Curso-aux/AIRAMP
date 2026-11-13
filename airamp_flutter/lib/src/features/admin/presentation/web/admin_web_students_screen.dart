import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/components/aira_action_toast.dart';
import '../../../../core/components/aira_progress_dialog.dart';
import '../../../../core/components/user_avatar_widget.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../../core/utils/institutional_id_helper.dart';
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
  bool _isAllDirectoryView = true;
  String _statusFilter = 'all'; // 'all', 'active', 'inactive'
  bool get _isArchiveView => _statusFilter == 'inactive';
  set _isArchiveView(bool val) {
    _statusFilter = val ? 'inactive' : 'active';
  }
  String _specialSubFilter = 'All'; // 'All', 'Irregular', 'Transferee', 'SPED', 'Unassigned'

  // Multi-select state
  bool _isSelectionMode = false;
  final Set<String> _selectedStudentIds = {};

  String _formatArchivedDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Deactivated';
    try {
      final dt = DateTime.parse(isoString);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} $hour:$min $amPm';
    } catch (_) {
      return 'Deactivated';
    }
  }

  String _generateAutoStudentPassword() {
    final rand = Random();
    const symbols = ['@', '#', '!', '\$'];
    final symbol = symbols[rand.nextInt(symbols.length)];
    final num = 1000 + rand.nextInt(9000);
    return 'Stud$symbol$num';
  }

  final List<String> _defaultGrades = [
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];

  String? _lastProcessedQuery;

  void _syncWithRouteParams() {
    try {
      final uri = GoRouterState.of(context).uri;
      final currentQuery = uri.query;
      if (currentQuery != _lastProcessedQuery) {
        _lastProcessedQuery = currentQuery;
        final filter = uri.queryParameters['filter'];
        final section = uri.queryParameters['section'];
        final grade = uri.queryParameters['grade'];

        if (filter == 'archived' || filter == 'inactive') {
          _statusFilter = 'inactive';
          _isSpecialView = false;
          _isAllDirectoryView = false;
          _selectedStudentIds.clear();
        } else if (filter == 'active') {
          _statusFilter = 'active';
          _isSpecialView = false;
          _isAllDirectoryView = true;
          _selectedStudentIds.clear();
        } else if (filter == 'unassigned') {
          _statusFilter = 'all';
          _isSpecialView = true;
          _isAllDirectoryView = false;
          _specialSubFilter = 'Unassigned';
          _selectedStudentIds.clear();
        } else if (filter == 'special') {
          _statusFilter = 'all';
          _isSpecialView = true;
          _isAllDirectoryView = false;
          _specialSubFilter = 'All';
          _selectedStudentIds.clear();
        } else if (filter == 'all') {
          _statusFilter = 'all';
          _isAllDirectoryView = true;
          _isSpecialView = false;
          _selectedStudentIds.clear();
        }

        if (grade != null && grade.isNotEmpty) {
          _selectedGrade = grade;
        }
        if (section != null && section.isNotEmpty) {
          _selectedSection = section;
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _selectedStudentIds.clear();
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
    if (_isArchiveView) {
      scopeLabel = 'Deactivated Students';
    } else if (_searchController.text.trim().isNotEmpty) {
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
    if (!mounted || !context.mounted) return;
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
    _syncWithRouteParams();
    ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allStudents = ref.watch(adminStudentsProvider);
    final archivedStudents = ref.watch(adminArchivedStudentsProvider);
    final availableSectionsAsync = ref.watch(availableSectionsProvider);
    final availableSections = availableSectionsAsync.value ?? [];
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

    // Determine base pool by status filter (All, Active, Inactive)
    final List<Map<String, dynamic>> baseStudents;
    if (_statusFilter == 'inactive') {
      baseStudents = archivedStudents;
    } else if (_statusFilter == 'active') {
      baseStudents = allStudents;
    } else {
      baseStudents = [...allStudents, ...archivedStudents];
    }

    // Determine current filtered student list
    List<Map<String, dynamic>> filteredStudents = baseStudents;
    final query = _searchController.text.trim().toLowerCase();

    if (query.isNotEmpty) {
      filteredStudents = baseStudents.where((s) {
        final name = (s['full_name'] as String? ?? '').toLowerCase();
        final email = (s['email'] as String? ?? '').toLowerCase();
        final sec = (s['section'] as String? ?? '').toLowerCase();
        final grade = (s['grade'] as String? ?? '').toLowerCase();
        return name.contains(query) || email.contains(query) || sec.contains(query) || grade.contains(query);
      }).toList();
    } else if (_isSpecialView) {
      filteredStudents = baseStudents.where((s) {
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
      filteredStudents = baseStudents;
    } else {
      // Scoped exclusively to the chosen Year Level
      filteredStudents = baseStudents.where((s) {
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

                  final exportBtn = OutlinedButton.icon(
                    onPressed: () => _handleExportCsv(filteredStudents),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Export CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.text,
                      side: BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(0, 42),
                    ),
                  );

                  final importBtn = OutlinedButton.icon(
                    onPressed: () => BulkImportModal.show(context),
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: const Text('Import CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.text,
                      side: BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(0, 42),
                    ),
                  );

                  final addStudentBtn = ElevatedButton.icon(
                    onPressed: () => _openAddStudentDialog(context, availableSections, subjects),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('Add New Student', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      minimumSize: const Size(0, 42),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleSection,
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: addStudentBtn,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: exportBtn),
                            const SizedBox(width: 10),
                            Expanded(child: importBtn),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          exportBtn,
                          const SizedBox(width: 10),
                          importBtn,
                          const SizedBox(width: 10),
                          addStudentBtn,
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              // View Mode Switcher: Active Directory vs Archive Vault
              LayoutBuilder(
                builder: (context, switcherConstraints) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final isCompact = switcherConstraints.maxWidth < 520;
                  final allCount = allStudents.length + archivedStudents.length;
                  final allLabel = isCompact ? 'All ($allCount)' : 'All Students ($allCount)';
                  final activeLabel = isCompact ? 'Active (${allStudents.length})' : 'Active Students (${allStudents.length})';
                  final inactiveLabel = isCompact ? 'Inactive (${archivedStudents.length})' : 'Inactive Accounts (${archivedStudents.length})';

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // All Students
                          InkWell(
                            onTap: () {
                              setState(() {
                                _statusFilter = 'all';
                                _isSelectionMode = false;
                                _selectedStudentIds.clear();
                              });
                            },
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _statusFilter == 'all' ? AppTheme.surface : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _statusFilter == 'all'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.school_outlined,
                                    size: 16,
                                    color: _statusFilter == 'all' ? AppTheme.primary : AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    allLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _statusFilter == 'all' ? FontWeight.bold : FontWeight.w500,
                                      color: _statusFilter == 'all' ? AppTheme.text : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Active Students
                          InkWell(
                            onTap: () {
                              setState(() {
                                _statusFilter = 'active';
                                _isSelectionMode = false;
                                _selectedStudentIds.clear();
                              });
                            },
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _statusFilter == 'active' ? AppTheme.surface : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _statusFilter == 'active'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_alt_rounded,
                                    size: 16,
                                    color: _statusFilter == 'active' ? AppTheme.primary : AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    activeLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _statusFilter == 'active' ? FontWeight.bold : FontWeight.w500,
                                      color: _statusFilter == 'active' ? AppTheme.text : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Inactive / Deactivated Accounts
                          InkWell(
                            onTap: () {
                              setState(() {
                                _statusFilter = 'inactive';
                                _isSelectionMode = false;
                                _selectedStudentIds.clear();
                              });
                            },
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _statusFilter == 'inactive' ? AppTheme.surface : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _statusFilter == 'inactive'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_off_outlined,
                                    size: 16,
                                    color: _statusFilter == 'inactive' ? const Color(0xFFD97706) : AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    inactiveLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _statusFilter == 'inactive' ? FontWeight.bold : FontWeight.w500,
                                      color: _statusFilter == 'inactive' ? const Color(0xFFD97706) : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Global Search & Filter Toolbar (Year Level and Section Filter beside Search Bar)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;

                  final searchWidget = Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      maxLength: 60,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      style: TextStyle(color: AppTheme.text, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: _isArchiveView
                            ? 'Search deactivated student name, email, or last section...'
                            : 'Search student name, email, or section across school...',
                        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13.5),
                        counterText: '',
                        prefixIcon: Icon(Icons.search, size: 19, color: AppTheme.textMuted),
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  );

                  if (_isArchiveView) {
                    return searchWidget;
                  }

                  final yearDropdown = _buildYearLevelDropdown(allStudents, displayedGrades, specialStudents, isDark);
                  final sectionDropdown = _buildSectionDropdown(allStudents, classroomsInSelectedGrade, specialStudents, isDark);

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: searchWidget),
                        const SizedBox(width: 10),
                        yearDropdown,
                        const SizedBox(width: 10),
                        sectionDropdown,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      searchWidget,
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: yearDropdown),
                          const SizedBox(width: 10),
                          Expanded(child: sectionDropdown),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              // Hierarchy or Archive Vault Header
              if (_isArchiveView)
                LayoutBuilder(
                  builder: (context, bannerConstraints) {
                    final isNarrow = bannerConstraints.maxWidth < 640;

                    final headerIcon = Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_off_outlined, color: Color(0xFFD97706), size: 22),
                    );

                    final titleAndCount = Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Deactivated Student Accounts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF92400E),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${filteredStudents.length} Deactivated Record${filteredStudents.length == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    );

                    final descriptionText = Text(
                      'Deactivated student accounts are safely preserved here with their course enrollments and quiz history intact. You can reactivate them back to the active directory or delete them permanently.',
                      style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF78350F)),
                    );

                    final backButton = TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isArchiveView = false;
                          _selectedStudentIds.clear();
                        });
                      },
                      icon: const Icon(Icons.arrow_back, size: 14),
                      label: const Text('Back to Active Directory', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFD97706)),
                    );

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isNarrow) ...[
                            Row(
                              children: [
                                headerIcon,
                                const SizedBox(width: 12),
                                Expanded(child: titleAndCount),
                              ],
                            ),
                            const SizedBox(height: 8),
                            descriptionText,
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: backButton,
                            ),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                headerIcon,
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      titleAndCount,
                                      const SizedBox(height: 3),
                                      descriptionText,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                backButton,
                              ],
                            ),
                      if (filteredStudents.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isSelectionMode = !_isSelectionMode;
                                  if (!_isSelectionMode) {
                                    _selectedStudentIds.clear();
                                  }
                                });
                              },
                              icon: Icon(
                                _isSelectionMode ? Icons.close_rounded : Icons.checklist_rounded,
                                size: 16,
                                color: _isSelectionMode ? AppTheme.error : const Color(0xFFD97706),
                              ),
                              label: Text(
                                _isSelectionMode ? 'Cancel Selection' : 'Select Multiple',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _isSelectionMode ? AppTheme.error : const Color(0xFFD97706),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _isSelectionMode ? AppTheme.error : const Color(0xFFD97706),
                                side: BorderSide(
                                  color: _isSelectionMode
                                      ? AppTheme.error.withValues(alpha: 0.5)
                                      : const Color(0xFFD97706).withValues(alpha: 0.5),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  if (_selectedStudentIds.length == filteredStudents.length) {
                                    _selectedStudentIds.clear();
                                    _isSelectionMode = false;
                                  } else {
                                    _isSelectionMode = true;
                                    for (final s in filteredStudents) {
                                      final id = s['id'] as String?;
                                      if (id != null) _selectedStudentIds.add(id);
                                    }
                                  }
                                });
                              },
                              icon: Icon(
                                _selectedStudentIds.length == filteredStudents.length && filteredStudents.isNotEmpty
                                    ? Icons.deselect_rounded
                                    : Icons.select_all_rounded,
                                size: 16,
                              ),
                              label: Text(
                                _selectedStudentIds.length == filteredStudents.length && filteredStudents.isNotEmpty
                                    ? 'Deselect All'
                                    : 'Select All (${filteredStudents.length})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                side: BorderSide(color: const Color(0xFFD97706).withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            if (_selectedStudentIds.isNotEmpty) ...[
                              OutlinedButton.icon(
                                onPressed: () => _confirmBulkRestore(context, _selectedStudentIds.toList()),
                                icon: const Icon(Icons.restore_rounded, size: 14),
                                label: Text('Restore Selected (${_selectedStudentIds.length})'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                  backgroundColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5),
                                  side: BorderSide(color: isDark ? const Color(0xFF059669).withValues(alpha: 0.45) : const Color(0xFFA7F3D0)),
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                  minimumSize: const Size(0, 30),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _confirmBulkPermanentDelete(context, _selectedStudentIds.toList()),
                                icon: const Icon(Icons.delete_forever_rounded, size: 14),
                                label: Text('Delete Permanently (${_selectedStudentIds.length})'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                                  backgroundColor: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.35) : const Color(0xFFFEF2F2),
                                  side: BorderSide(color: isDark ? const Color(0xFF991B1B).withValues(alpha: 0.45) : const Color(0xFFFECACA)),
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                  minimumSize: const Size(0, 30),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            )
              else ...[
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
                                  : 'Active Scope: $_selectedGrade → ${_selectedSection == 'All' ? 'All Classrooms' : 'Classroom: $_selectedSection'} (${filteredStudents.length} Students)'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                      if (_selectedSection != 'All' || _isSpecialView || !_isAllDirectoryView || _searchController.text.isNotEmpty) ...[
                        TextButton.icon(
                          icon: const Icon(Icons.restart_alt, size: 16),
                          label: const Text('Reset Filter', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedGrade = 'Grade 10';
                              _selectedSection = 'All';
                              _isSpecialView = false;
                              _isAllDirectoryView = true;
                              _specialSubFilter = 'All';
                              _selectedStudentIds.clear();
                              _isSelectionMode = false;
                              _searchController.clear();
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = !_isSelectionMode;
                            if (!_isSelectionMode) {
                              _selectedStudentIds.clear();
                            }
                          });
                        },
                        icon: Icon(
                          _isSelectionMode ? Icons.close_rounded : Icons.checklist_rounded,
                          size: 15,
                          color: _isSelectionMode ? AppTheme.error : AppTheme.primary,
                        ),
                        label: Text(
                          _isSelectionMode ? 'Cancel Selection' : 'Select Multiple',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isSelectionMode ? AppTheme.error : AppTheme.text,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _isSelectionMode ? AppTheme.error.withValues(alpha: 0.4) : AppTheme.border,
                          ),
                          backgroundColor: _isSelectionMode
                              ? (isDark ? Colors.red.withValues(alpha: 0.1) : const Color(0xFFFEF2F2))
                              : AppTheme.surface,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Multi-select Batch Action Toolbar
              _buildBatchActionBar(filteredStudents, Theme.of(context).brightness == Brightness.dark),

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
                        _isArchiveView ? Icons.person_off_outlined : (_isSpecialView ? Icons.workspace_premium_outlined : Icons.person_search_outlined),
                        size: 54,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isArchiveView ? 'No Deactivated Accounts' : (_isSpecialView ? 'No Special Students Found' : 'No Students In This Classroom / Grade'),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isArchiveView
                            ? 'When student accounts are deactivated, they are kept here where they can be reactivated or permanently removed.'
                            : (_isSpecialView
                                ? 'You can tag any student as a Special Student to manage their individualized curriculum.'
                                : 'No students are currently enrolled in this specific grade and classroom.'),
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      if (_isArchiveView)
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isArchiveView = false;
                              _selectedStudentIds.clear();
                            });
                          },
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Back to Active Directory'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        )
                      else
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

  Widget _buildYearLevelDropdown(
    List<Map<String, dynamic>> allStudents,
    List<String> displayedGrades,
    List<Map<String, dynamic>> specialStudents,
    bool isDark,
  ) {
    String currentYearLabel = 'Grade 10';
    if (_isAllDirectoryView) {
      currentYearLabel = 'All Students';
    } else if (_isSpecialView) {
      currentYearLabel = 'Special Students';
    } else {
      currentYearLabel = _selectedGrade;
    }

    final isFiltered = _isSpecialView || _isAllDirectoryView || _selectedGrade != 'Grade 10';

    return PopupMenuButton<String>(
      tooltip: 'Filter by Year Level',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.border),
      ),
      color: AppTheme.surface,
      elevation: 6,
      onSelected: (val) {
        setState(() {
          if (val == 'all') {
            _isAllDirectoryView = true;
            _isSpecialView = false;
            _selectedSection = 'All';
          } else if (val == 'special') {
            _isSpecialView = true;
            _isAllDirectoryView = false;
            _specialSubFilter = 'All';
            _selectedSection = 'All';
          } else {
            _selectedGrade = val;
            _isSpecialView = false;
            _isAllDirectoryView = false;
            _selectedSection = 'All';
          }
          _selectedStudentIds.clear();
        });
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem<String>(
            value: 'all',
            child: Row(
              children: [
                Icon(Icons.list_alt_rounded, size: 16, color: _isAllDirectoryView ? AppTheme.primary : AppTheme.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All Students',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _isAllDirectoryView ? FontWeight.bold : FontWeight.normal,
                      color: _isAllDirectoryView ? AppTheme.primary : AppTheme.text,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${allStudents.length}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          ...displayedGrades.map((grade) {
            final isSel = !_isSpecialView && !_isAllDirectoryView && _selectedGrade == grade;
            final count = allStudents.where((s) => s['grade'] == grade).length;
            return PopupMenuItem<String>(
              value: grade,
              child: Row(
                children: [
                  Icon(Icons.school_outlined, size: 16, color: isSel ? AppTheme.primary : AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      grade,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? AppTheme.primary : AppTheme.text,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            );
          }),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'special',
            child: Row(
              children: [
                Icon(Icons.workspace_premium_outlined, size: 16, color: _isSpecialView ? AppTheme.primary : AppTheme.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Special Students',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _isSpecialView ? FontWeight.bold : FontWeight.normal,
                      color: _isSpecialView ? AppTheme.primary : AppTheme.text,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${specialStudents.length}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ];
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isFiltered ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFiltered ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.border,
            width: isFiltered ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isSpecialView
                  ? Icons.workspace_premium_outlined
                  : (_isAllDirectoryView ? Icons.list_alt_rounded : Icons.school_outlined),
              size: 16,
              color: isFiltered ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                currentYearLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isFiltered ? FontWeight.bold : FontWeight.w500,
                  color: isFiltered ? AppTheme.primary : AppTheme.text,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionDropdown(
    List<Map<String, dynamic>> allStudents,
    List<String> classroomsInSelectedGrade,
    List<Map<String, dynamic>> specialStudents,
    bool isDark,
  ) {
    String currentSectionLabel;
    IconData icon;
    bool isFiltered = false;

    if (_isSpecialView) {
      icon = Icons.category_outlined;
      currentSectionLabel = _specialSubFilter == 'All' ? 'All Special' : _specialSubFilter;
      isFiltered = _specialSubFilter != 'All';
    } else if (_isAllDirectoryView) {
      icon = Icons.meeting_room_outlined;
      currentSectionLabel = _selectedSection == 'All' ? 'All Sections' : _selectedSection;
      isFiltered = _selectedSection != 'All';
    } else {
      icon = Icons.meeting_room_outlined;
      currentSectionLabel = _selectedSection == 'All' ? 'All $_selectedGrade Classrooms' : _selectedSection;
      isFiltered = _selectedSection != 'All';
    }

    return PopupMenuButton<String>(
      tooltip: 'Filter by Classroom Section / Track',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.border),
      ),
      color: AppTheme.surface,
      elevation: 6,
      onSelected: (val) {
        setState(() {
          if (_isSpecialView) {
            _specialSubFilter = val;
          } else {
            _selectedSection = val;
          }
          _selectedStudentIds.clear();
        });
      },
      itemBuilder: (context) {
        if (_isSpecialView) {
          final specialCategories = [
            {'id': 'All', 'name': 'All Special', 'count': specialStudents.length},
            {'id': 'Irregular', 'name': 'Irregular', 'count': specialStudents.where((s) => (s['student_type'] as String? ?? '').toLowerCase().contains('irregular')).length},
            {'id': 'Transferee', 'name': 'Transferee', 'count': specialStudents.where((s) => (s['student_type'] as String? ?? '').toLowerCase().contains('transferee')).length},
            {'id': 'SPED', 'name': 'SPED', 'count': specialStudents.where((s) => (s['student_type'] as String? ?? '').toLowerCase().contains('sped')).length},
            {'id': 'Unassigned', 'name': 'Unassigned', 'count': specialStudents.where((s) {
              final sec = (s['section'] as String? ?? '').toLowerCase();
              return sec == 'unassigned' || sec.isEmpty;
            }).length},
          ];

          return specialCategories.map((item) {
            final cat = item['id'] as String;
            final name = item['name'] as String;
            final count = item['count'] as int;
            final isSel = _specialSubFilter == cat;
            return PopupMenuItem<String>(
              value: cat,
              child: Row(
                children: [
                  Icon(Icons.label_outline_rounded, size: 16, color: isSel ? AppTheme.primary : AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? AppTheme.primary : AppTheme.text,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            );
          }).toList();
        }

        // Standard Grade Sections or All Directory
        final List<String> availableSectionsToDisplay = _isAllDirectoryView
            ? () {
                final set = <String>{};
                for (final s in allStudents) {
                  final sec = s['section'] as String?;
                  if (sec != null && sec.isNotEmpty && sec != 'Unassigned') set.add(sec);
                }
                final list = set.toList()..sort();
                return list;
              }()
            : classroomsInSelectedGrade;

        final allClassroomsCount = _isAllDirectoryView
            ? allStudents.length
            : allStudents.where((s) {
                final g = s['grade'] as String? ?? '';
                final sec = s['section'] as String? ?? '';
                return g == _selectedGrade || sec.contains(_selectedGrade);
              }).length;

        return [
          PopupMenuItem<String>(
            value: 'All',
            child: Row(
              children: [
                Icon(Icons.dashboard_outlined, size: 16, color: _selectedSection == 'All' ? AppTheme.primary : AppTheme.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isAllDirectoryView ? 'All Classrooms' : 'All $_selectedGrade Classrooms',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _selectedSection == 'All' ? FontWeight.bold : FontWeight.normal,
                      color: _selectedSection == 'All' ? AppTheme.primary : AppTheme.text,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$allClassroomsCount',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
          if (availableSectionsToDisplay.isNotEmpty) const PopupMenuDivider(),
          ...availableSectionsToDisplay.map((sec) {
            final isSel = _selectedSection == sec;
            final count = allStudents.where((s) {
              if (_isAllDirectoryView) return s['section'] == sec;
              final sGrade = s['grade'] as String? ?? '';
              final sSec = s['section'] as String? ?? '';
              return (sGrade == _selectedGrade || sSec.contains(_selectedGrade)) &&
                  (sSec == sec || sSec.endsWith(sec));
            }).length;

            return PopupMenuItem<String>(
              value: sec,
              child: Row(
                children: [
                  Icon(Icons.meeting_room_outlined, size: 16, color: isSel ? AppTheme.primary : AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sec,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? AppTheme.primary : AppTheme.text,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            );
          }),
        ];
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isFiltered ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFiltered ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.border,
            width: isFiltered ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isFiltered ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                currentSectionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isFiltered ? FontWeight.bold : FontWeight.w500,
                  color: isFiltered ? AppTheme.primary : AppTheme.text,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchActionBar(List<Map<String, dynamic>> currentList, bool isDark) {
    if (_selectedStudentIds.isEmpty) return const SizedBox.shrink();

    final count = _selectedStudentIds.length;
    final allInCurrentSelected = currentList.isNotEmpty && currentList.every((s) => _selectedStudentIds.contains(s['id']));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: AppTheme.primary,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$count of ${currentList.length} student${count == 1 ? '' : 's'} selected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.text,
            ),
          ),
          if (!allInCurrentSelected) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  for (final s in currentList) {
                    final id = s['id'] as String?;
                    if (id != null) _selectedStudentIds.add(id);
                  }
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 28),
              ),
              child: Text(
                'Select all ${currentList.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (!_isArchiveView) ...[
            OutlinedButton.icon(
              onPressed: () => _confirmBulkArchive(context, _selectedStudentIds.toList()),
              icon: const Icon(Icons.person_off_outlined, size: 14),
              label: Text('Deactivate Selected ($count)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
                backgroundColor: isDark ? const Color(0xFF291C10) : const Color(0xFFFEF3C7),
                side: BorderSide(color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: () => _confirmBulkRestore(context, _selectedStudentIds.toList()),
              icon: const Icon(Icons.restore_rounded, size: 14),
              label: Text('Restore Selected ($count)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                backgroundColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5),
                side: BorderSide(color: isDark ? const Color(0xFF059669).withValues(alpha: 0.45) : const Color(0xFFA7F3D0)),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                minimumSize: const Size(0, 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _confirmBulkPermanentDelete(context, _selectedStudentIds.toList()),
              icon: const Icon(Icons.delete_forever_rounded, size: 14),
              label: Text('Delete Permanently ($count)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                backgroundColor: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.35) : const Color(0xFFFEF2F2),
                side: BorderSide(color: isDark ? const Color(0xFF991B1B).withValues(alpha: 0.45) : const Color(0xFFFECACA)),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                minimumSize: const Size(0, 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStudentIds.clear();
                _isSelectionMode = false;
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              'Clear Selection',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
            ),
          ),
        ],
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
            constraints: const BoxConstraints(minWidth: 1120),
            child: DataTable(
              showCheckboxColumn: _isSelectionMode,
              onSelectAll: _isSelectionMode
                  ? (val) {
                      setState(() {
                        if (val == true) {
                          for (final s in students) {
                            final id = s['id'] as String?;
                            if (id != null) _selectedStudentIds.add(id);
                          }
                        } else {
                          _selectedStudentIds.clear();
                        }
                      });
                    }
                  : null,
              headingRowColor: WidgetStateProperty.all(AppTheme.background),
              dataRowMinHeight: 64,
              dataRowMaxHeight: 70,
              horizontalMargin: 16,
              columnSpacing: 18,
              columns: [
                DataColumn(label: Text(_isArchiveView ? 'DEACTIVATED STUDENT' : 'STUDENT', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text(_isArchiveView ? 'LAST SECTION' : 'ASSIGNED SECTION', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('GRADE LEVEL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('CLASSIFICATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text(_isArchiveView ? 'DEACTIVATED AT' : 'ENROLLED', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                if (!_isArchiveView)
                  const DataColumn(label: Text('QUIZ AVG', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              ],
              rows: students.map((s) {
                final studentId = s['id'] as String? ?? '';
                final email = s['email'] as String? ?? '';
                final rawName = s['full_name'] as String? ?? s['name'] as String? ?? s['student_name'] as String? ?? '';
                final name = rawName.trim().isNotEmpty ? rawName.trim() : (email.isNotEmpty ? email : (studentId.isNotEmpty ? studentId : 'Student'));
                final section = (s['section'] as String?)?.isNotEmpty == true ? s['section'] as String : 'Unassigned';
                final grade = (s['grade'] as String?)?.isNotEmpty == true ? s['grade'] as String : 'Unset';
                final studentType = (s['student_type'] as String?)?.isNotEmpty == true ? s['student_type'] as String : 'regular';
                final notes = s['special_notes'] as String?;
                final enrolledCount = s['enrolled_courses'] as int? ?? 0;
                final avgScore = s['avg_score'] as int? ?? 0;
                final archivedAt = s['archived_at'] as String?;
                final bool isArchived = s['is_archived'] == 1 || s['is_archived'] == true || s['is_archived'] == '1';

                final hasSection = section != 'Unassigned';
                final isSelected = _selectedStudentIds.contains(studentId);

                return DataRow(
                  selected: _isSelectionMode && isSelected,
                  onSelectChanged: _isSelectionMode
                      ? (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedStudentIds.add(studentId);
                            } else {
                              _selectedStudentIds.remove(studentId);
                            }
                          });
                        }
                      : null,
                  cells: [
                    // Student info
                    DataCell(
                      Row(
                        children: [
                          UserAvatarWidget(
                            imageSource: (s['profile_image'] ?? s['profileImage']) as String?,
                            fallbackInitial: name,
                            size: 34,
                            fontSize: 13,
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

                    // Status Badge
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: !isArchived
                              ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5))
                              : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: !isArchived
                                ? (isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0))
                                : (isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A)),
                          ),
                        ),
                        child: Text(
                          !isArchived ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: !isArchived
                                ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                                : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
                          ),
                        ),
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
                      Text(
                        grade,
                        style: TextStyle(fontSize: 12.5, color: AppTheme.text),
                      ),
                    ),

                    // Classification
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

                    // Enrolled courses OR Archived At
                    if (_isArchiveView)
                      DataCell(
                        Text(
                          _formatArchivedDate(archivedAt),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                          ),
                        ),
                      )
                    else ...[
                      DataCell(
                        Text(
                          '$enrolledCount subject${enrolledCount == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                        ),
                      ),
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
                    ],

                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isArchived) ...[
                            OutlinedButton.icon(
                              onPressed: () async {
                                await ref.read(adminArchivedStudentsProvider.notifier).restoreStudent(studentId);
                                if (mounted) {
                                  AiraActionToast.showRestored(
                                    context,
                                    title: 'Student Restored',
                                    message: 'Student "$name" ($studentId) was restored to active directory.',
                                  );
                                }
                              },
                              icon: const Icon(Icons.restore_rounded, size: 13.5),
                              label: const Text('Restore', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                backgroundColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5),
                                side: BorderSide(color: isDark ? const Color(0xFF059669).withValues(alpha: 0.45) : const Color(0xFFA7F3D0)),
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                minimumSize: const Size(0, 28),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Permanently Delete Record',
                              child: InkWell(
                                onTap: () => _confirmPermanentDeleteStudent(context, s),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.35) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isDark ? const Color(0xFF991B1B).withValues(alpha: 0.45) : const Color(0xFFFECACA)),
                                  ),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 15,
                                    color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
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
                              onPressed: () => _confirmArchiveStudent(context, s),
                              tooltip: 'Deactivate Account',
                              icon: const Icon(Icons.person_off_outlined, size: 17),
                              color: const Color(0xFFD97706),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
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
      itemBuilder: (cardCtx, index) {
        final s = students[index];
        final studentId = s['id'] as String? ?? '';
        final email = s['email'] as String? ?? '';
        final rawName = s['full_name'] as String? ?? s['name'] as String? ?? s['student_name'] as String? ?? '';
        final name = rawName.trim().isNotEmpty ? rawName.trim() : (email.isNotEmpty ? email : (studentId.isNotEmpty ? studentId : 'Student'));
        final section = (s['section'] as String?)?.isNotEmpty == true ? s['section'] as String : 'Unassigned';
        final grade = (s['grade'] as String?)?.isNotEmpty == true ? s['grade'] as String : 'Unset';
        final studentType = (s['student_type'] as String?)?.isNotEmpty == true ? s['student_type'] as String : 'regular';
        final notes = s['special_notes'] as String?;
        final enrolledCount = s['enrolled_courses'] as int? ?? 0;
        final avgScore = s['avg_score'] as int? ?? 0;
        final archivedAt = s['archived_at'] as String?;
        final bool isArchived = s['is_archived'] == 1 || s['is_archived'] == true || s['is_archived'] == '1';

        final hasSection = section != 'Unassigned';
        final isSelected = _selectedStudentIds.contains(studentId);
        final isDark = Theme.of(cardCtx).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_isSelectionMode)
                    Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedStudentIds.add(studentId);
                          } else {
                            _selectedStudentIds.remove(studentId);
                          }
                        });
                      },
                    ),
                  UserAvatarWidget(
                    imageSource: (s['profile_image'] ?? s['profileImage']) as String?,
                    fallbackInitial: name,
                    size: 38,
                    fontSize: 14,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppTheme.text)),
                        const SizedBox(height: 2),
                        Text(email, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
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
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: 12),
              if (isArchived) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Grade: $grade', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text(
                      'Deactivated: ${_formatArchivedDate(archivedAt)}',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(adminArchivedStudentsProvider.notifier).restoreStudent(studentId);
                          if (cardCtx.mounted) {
                            AiraActionToast.showRestored(
                              cardCtx,
                              title: 'Student Restored',
                              message: 'Student "$name" has been restored to active directory.',
                            );
                          }
                        },
                        icon: const Icon(Icons.restore_rounded, size: 14),
                        label: const Text('Restore to Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                          backgroundColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5),
                          side: BorderSide(color: isDark ? const Color(0xFF059669).withValues(alpha: 0.45) : const Color(0xFFA7F3D0)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Permanently Delete',
                      child: InkWell(
                        onTap: () => _confirmPermanentDeleteStudent(cardCtx, s),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.35) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF991B1B).withValues(alpha: 0.45) : const Color(0xFFFECACA)),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
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
                        label: const Text('Courses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.text,
                          side: BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showArrangeSectionDialog(studentId, name, section, grade, availableSections),
                        icon: const Icon(Icons.swap_horiz, size: 15),
                        label: const Text('Move / Assign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.text,
                          side: BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _resendStudentCredentialsDialog(cardCtx, s),
                            tooltip: 'Resend Credentials Email',
                            icon: const Icon(Icons.forward_to_inbox_rounded, size: 16),
                            color: AppTheme.textSecondary,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                          Container(width: 1, height: 18, color: AppTheme.border),
                          IconButton(
                            onPressed: () => _confirmArchiveStudent(cardCtx, s),
                            tooltip: 'Deactivate Account',
                            icon: const Icon(Icons.person_off_outlined, size: 16),
                            color: const Color(0xFFD97706),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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
    String destinationSection = availableSections.contains(currentSection) ? currentSection : (availableSections.isNotEmpty ? availableSections.first : 'Unassigned');
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
    if (!mounted || !context.mounted) return;

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

  void _confirmArchiveStudent(BuildContext context, Map<String, dynamic> student) {
    final rootContext = context;
    final studentId = student['id'] as String? ?? '';
    final studentEmail = student['email'] as String? ?? '';
    final rawName = student['full_name'] as String? ?? student['name'] as String? ?? student['student_name'] as String? ?? '';
    final studentName = rawName.trim().isNotEmpty ? rawName.trim() : (studentEmail.isNotEmpty ? studentEmail : (studentId.isNotEmpty ? studentId : 'Student'));
    final studentGrade = student['grade'] as String? ?? 'Unset';
    final studentSection = student['section'] as String? ?? 'Unassigned';

    showDialog(
      context: rootContext,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogStateCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_off_outlined, color: Color(0xFFD97706), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Deactivate Student Account',
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
                      'Are you sure you want to deactivate this student account?',
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
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.28)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'The student will be hidden from active classroom rosters. Their course enrollments, quiz scores, and submissions are safely kept and can be reactivated at any time.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
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
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    _confirmPermanentDeleteStudent(rootContext, student);
                  },
                  icon: const Icon(Icons.delete_forever_rounded, size: 15, color: Color(0xFFB91C1C)),
                  label: const Text('Delete Permanently Instead', style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(dialogCtx).pop();
                    try {
                      await AiraProgressDialog.showDeactivating(
                        rootContext,
                        title: 'Deactivating Student Account',
                        initialMessage: 'Deactivating "$studentName" and synchronizing cloud records...',
                        task: (updateProgress) async {
                          updateProgress(0.3, 'Updating local student records...');
                          await ref
                              .read(adminStudentsProvider.notifier)
                              .archiveStudent(studentId)
                              .timeout(const Duration(seconds: 10));
                          updateProgress(1.0, 'Account deactivated successfully!');
                        },
                      );
                      if (rootContext.mounted) {
                        AiraActionToast.showDeactivated(
                          rootContext,
                          title: 'Student account deactivated',
                          message: 'Student "$studentName" ($studentId) was deactivated.',
                          duration: const Duration(seconds: 6),
                        );
                      }
                    } catch (e) {
                      if (rootContext.mounted) {
                        AiraActionToast.showError(
                          rootContext,
                          title: 'Failed to deactivate student',
                          message: 'An unexpected error occurred: $e',
                          duration: const Duration(seconds: 8),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.person_off_outlined, size: 16),
                  label: const Text('Deactivate Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmBulkArchive(BuildContext context, List<String> studentIds) {
    if (studentIds.isEmpty) return;
    final rootContext = context;

    showDialog(
      context: rootContext,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogStateCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_off_outlined, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Deactivate ${studentIds.length} Students?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Text(
                  'Are you sure you want to deactivate ${studentIds.length} selected student accounts? Their course enrollments, quiz scores, and submissions will be safely preserved and can be reactivated at any time.',
                  style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    _confirmBulkPermanentDelete(rootContext, studentIds);
                  },
                  icon: const Icon(Icons.delete_forever_rounded, size: 15, color: Color(0xFFB91C1C)),
                  label: const Text('Delete Permanently Instead', style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(dialogCtx).pop();
                    try {
                      await AiraProgressDialog.showDeactivating(
                        rootContext,
                        title: 'Deactivating ${studentIds.length} Student Accounts',
                        initialMessage: 'Preparing student records and Cloud Firestore sync...',
                        task: (updateProgress) async {
                          await ref.read(adminStudentsProvider.notifier).bulkArchiveStudents(
                            studentIds,
                            onProgress: (progress, statusMessage) {
                              updateProgress(progress, statusMessage);
                            },
                          );
                        },
                      );
                      setState(() => _selectedStudentIds.clear());
                      if (rootContext.mounted) {
                        AiraActionToast.showDeactivated(
                          rootContext,
                          title: 'Students Deactivated',
                          message: '${studentIds.length} student accounts were deactivated.',
                        );
                      }
                    } catch (e) {
                      if (rootContext.mounted) {
                        AiraActionToast.showError(
                          rootContext,
                          title: 'Deactivation Failed',
                          message: 'An error occurred while deactivating students: $e',
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.person_off_outlined, size: 16),
                  label: const Text('Deactivate All Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmPermanentDeleteStudent(BuildContext context, Map<String, dynamic> student) {
    final rootContext = context;
    final studentId = student['id'] as String? ?? '';
    final studentEmail = student['email'] as String? ?? '';
    final rawName = student['full_name'] as String? ?? student['name'] as String? ?? student['student_name'] as String? ?? '';
    final studentName = rawName.trim().isNotEmpty ? rawName.trim() : (studentEmail.isNotEmpty ? studentEmail : (studentId.isNotEmpty ? studentId : 'Student'));
    final studentGrade = student['grade'] as String? ?? 'Unset';
    final studentSection = student['section'] as String? ?? 'Unassigned';

    showDialog(
      context: rootContext,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogStateCtx, setDialogState) {
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
                    'Permanently Delete Student',
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
                      'DANGER: This action cannot be undone. Are you sure you want to permanently delete this student record?',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600,
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
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.28)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Warning: All enrollments, quiz attempts, progress records, submissions, and Cloud Firestore documents will be permanently purged from the system.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
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
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(dialogCtx).pop();
                    try {
                      await AiraProgressDialog.showDeleting(
                        rootContext,
                        title: 'Permanently Deleting Student Record',
                        initialMessage: 'Purging student records and cloud database...',
                        task: (updateProgress) async {
                          await ref
                              .read(adminArchivedStudentsProvider.notifier)
                              .permanentDeleteStudent(
                                studentId,
                                onProgress: updateProgress,
                              )
                              .timeout(const Duration(seconds: 10));
                        },
                      );
                      setState(() => _selectedStudentIds.remove(studentId));
                      if (rootContext.mounted) {
                        AiraActionToast.showDeleted(
                          rootContext,
                          title: 'Student record permanently purged',
                          message: 'Student "$studentName" ($studentId) was permanently deleted.',
                          duration: const Duration(seconds: 8),
                        );
                      }
                    } catch (e) {
                      if (rootContext.mounted) {
                        AiraActionToast.showError(
                          rootContext,
                          title: 'Failed to delete student',
                          message: 'An unexpected error occurred while deleting "$studentName": $e',
                          duration: const Duration(seconds: 8),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text('Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmBulkRestore(BuildContext context, List<String> studentIds) {
    if (studentIds.isEmpty) return;
    final rootContext = context;

    showDialog(
      context: rootContext,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogStateCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.restore_rounded, color: AppTheme.success, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Restore ${studentIds.length} Students?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Text(
                  'Are you sure you want to reactivate ${studentIds.length} students back to the active directory and classroom rosters?',
                  style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(dialogCtx).pop();
                    try {
                      await AiraProgressDialog.showRestoring(
                        rootContext,
                        title: 'Restoring ${studentIds.length} Students',
                        initialMessage: 'Reactivating accounts and restoring rosters...',
                        task: (updateProgress) async {
                          updateProgress(0.4, 'Restoring local directory records...');
                          await ref.read(adminArchivedStudentsProvider.notifier).bulkRestoreStudents(studentIds);
                          updateProgress(1.0, 'Students restored successfully!');
                        },
                      );
                      setState(() => _selectedStudentIds.clear());
                      if (rootContext.mounted) {
                        AiraActionToast.showRestored(
                          rootContext,
                          title: 'Students Restored',
                          message: '${studentIds.length} students restored to active directory.',
                        );
                      }
                    } catch (e) {
                      if (rootContext.mounted) {
                        AiraActionToast.showError(
                          rootContext,
                          title: 'Bulk Restore Failed',
                          message: 'An error occurred while restoring students: $e',
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text('Restore All Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmBulkPermanentDelete(BuildContext context, List<String> studentIds) {
    if (studentIds.isEmpty) return;
    final rootContext = context;

    showDialog(
      context: rootContext,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogStateCtx, setDialogState) {
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
                    'Permanently Delete ${studentIds.length} Students?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Text(
                  'DANGER: This action cannot be undone. Are you sure you want to permanently purge ${studentIds.length} selected students and all their course enrollments, quiz records, and cloud data?',
                  style: TextStyle(fontSize: 13.5, color: AppTheme.error, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(dialogCtx).pop();
                    try {
                      await AiraProgressDialog.showDeleting(
                        rootContext,
                        title: 'Permanently Deleting ${studentIds.length} Students',
                        initialMessage: 'Purging student records and cloud database...',
                        task: (updateProgress) async {
                          await ref.read(adminArchivedStudentsProvider.notifier).bulkPermanentDeleteStudents(
                            studentIds,
                            onProgress: (progress, statusMessage) {
                              updateProgress(progress, statusMessage);
                            },
                          );
                        },
                      );
                      setState(() => _selectedStudentIds.clear());
                      if (rootContext.mounted) {
                        AiraActionToast.showDeleted(
                          rootContext,
                          title: 'Students Permanently Purged',
                          message: '${studentIds.length} student records were permanently deleted.',
                        );
                      }
                    } catch (e) {
                      if (rootContext.mounted) {
                        AiraActionToast.showError(
                          rootContext,
                          title: 'Bulk Deletion Failed',
                          message: 'An error occurred while deleting students: $e',
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text('Delete Permanently All Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

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

    final passwordCtrl = TextEditingController(text: _generateAutoStudentPassword());
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
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: obscurePassword ? null : 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Stud@4829',
                          helperText: 'Auto-generated secure password',
                          prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppTheme.primary),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                tooltip: 'Regenerate Password',
                                color: AppTheme.primary,
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setDialogState(() {
                                    passwordCtrl.text = _generateAutoStudentPassword();
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 18,
                                  color: AppTheme.textMuted,
                                ),
                                tooltip: obscurePassword ? 'Show Password' : 'Hide Password',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                              ),
                              const SizedBox(width: 4),
                            ],
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
    final firstNameCtrl = TextEditingController();
    final middleNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    String selectedSuffix = 'None';
    const suffixOptions = ['None', 'Jr.', 'Sr.', 'II', 'III', 'IV', 'V'];
    final emailCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: _generateAutoStudentPassword());
    final customSectionCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    String normalizeNamePart(String input) {
      final trimmed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (trimmed.isEmpty) return '';
      return trimmed.split(' ').map((word) {
        if (word.isEmpty) return '';
        final lower = word.toLowerCase();
        if (['de', 'la', 'del', 'san', 'van', 'von'].contains(lower)) return lower;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }

    if (!mounted || !context.mounted) return;

    // Default grade & section based on currently active filter
    String selectedGrade = _selectedGrade != 'All' ? _selectedGrade : 'Grade 10';

    // Build clean list of section options based strictly on registered school sections
    final sectionOptions = <String>{};
    for (final s in availableSections) {
      if (s.isNotEmpty && s != 'All') sectionOptions.add(s);
    }
    sectionOptions.add('Unassigned');

    String selectedSection = (_selectedSection != 'All' && _selectedSection.isNotEmpty && sectionOptions.contains(_selectedSection))
        ? _selectedSection
        : (sectionOptions.isNotEmpty ? sectionOptions.first : 'Unassigned');

    String selectedType = 'regular';
    final selectedSubjectIds = <int>{};
    bool obscurePassword = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isMobile = MediaQuery.sizeOf(dialogCtx).width < 580;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
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
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
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
                            labelText: 'Student ID (e.g. S-100-0001)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            counterText: '',
                            prefixIcon: Icon(Icons.badge_outlined, size: 20, color: AppTheme.textMuted),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter student ID';
                            final clean = InstitutionalIdHelper.normalize(v.trim());
                            final detected = InstitutionalIdHelper.detectRole(clean);
                            if (detected != null && detected != 'student') {
                              return 'ID "$clean" is a $detected ID. Student IDs must start with "S-" (e.g. S-100-0001)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        // 1. First Name & Middle Name (Optional)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: TextFormField(
                                controller: firstNameCtrl,
                                maxLength: 35,
                                textCapitalization: TextCapitalization.words,
                                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                style: TextStyle(color: AppTheme.text, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'First Name *',
                                  hintText: 'e.g. Maria Clara',
                                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  counterText: '',
                                  prefixIcon: Icon(Icons.person_outline, size: 20, color: AppTheme.textMuted),
                                  filled: true,
                                  fillColor: AppTheme.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter first name' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 5,
                              child: TextFormField(
                                controller: middleNameCtrl,
                                maxLength: 30,
                                textCapitalization: TextCapitalization.words,
                                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                style: TextStyle(color: AppTheme.text, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Middle Name (Optional)',
                                  hintText: 'e.g. Santos',
                                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  counterText: '',
                                  filled: true,
                                  fillColor: AppTheme.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // 2. Surname / Last Name & Suffix
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: TextFormField(
                                controller: lastNameCtrl,
                                maxLength: 35,
                                textCapitalization: TextCapitalization.words,
                                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                style: TextStyle(color: AppTheme.text, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Surname / Last Name *',
                                  hintText: 'e.g. Dela Cruz',
                                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  counterText: '',
                                  prefixIcon: Icon(Icons.badge_outlined, size: 20, color: AppTheme.textMuted),
                                  filled: true,
                                  fillColor: AppTheme.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter surname' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedSuffix,
                                style: TextStyle(color: AppTheme.text, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Suffix',
                                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  filled: true,
                                  fillColor: AppTheme.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                ),
                                items: suffixOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => selectedSuffix = val ?? 'None'),
                              ),
                            ),
                          ],
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
                        if (isMobile) ...[
                          TextFormField(
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
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: passwordCtrl,
                            maxLength: 24,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            obscureText: obscurePassword,
                            style: TextStyle(
                              color: AppTheme.text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              fontFamily: obscurePassword ? null : 'monospace',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Initial Password (Auto-Generated)',
                              labelStyle: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
                              helperText: 'Auto-generated secure password',
                              helperStyle: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              counterText: '',
                              prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppTheme.primary),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    tooltip: 'Regenerate Password',
                                    color: AppTheme.primary,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      setDialogState(() {
                                        passwordCtrl.text = _generateAutoStudentPassword();
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 18,
                                      color: AppTheme.textMuted,
                                    ),
                                    tooltip: obscurePassword ? 'Show Password' : 'Hide Password',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                              filled: true,
                              fillColor: AppTheme.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.primary, width: 1.5)),
                            ),
                            validator: (v) => v == null || v.trim().length < 6 ? 'Minimum 6 characters' : null,
                          ),
                        ] else ...[
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
                                  maxLength: 24,
                                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                  obscureText: obscurePassword,
                                  style: TextStyle(
                                    color: AppTheme.text,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: obscurePassword ? null : 'monospace',
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Initial Password (Auto-Generated)',
                                    labelStyle: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
                                    helperText: 'Auto-generated secure password',
                                    helperStyle: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                    counterText: '',
                                    prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppTheme.primary),
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.refresh_rounded, size: 18),
                                          tooltip: 'Regenerate Password',
                                          color: AppTheme.primary,
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () {
                                            setDialogState(() {
                                              passwordCtrl.text = _generateAutoStudentPassword();
                                            });
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            size: 18,
                                            color: AppTheme.textMuted,
                                          ),
                                          tooltip: obscurePassword ? 'Show Password' : 'Hide Password',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.background,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.primary, width: 1.5)),
                                  ),
                                  validator: (v) => v == null || v.trim().length < 6 ? 'Minimum 6 characters' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),

                        Text('Academic Placement & Classroom', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        if (isMobile) ...[
                          DropdownButtonFormField<String>(
                            isExpanded: true,
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
                              DropdownMenuItem(value: 'Grade 7', child: Text('Grade 7', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Grade 8', child: Text('Grade 8', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Grade 9', child: Text('Grade 9', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Grade 10', child: Text('Grade 10', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Grade 11', child: Text('Grade 11', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Grade 12', child: Text('Grade 12', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedGrade = val);
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
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
                              ...sectionOptions.map((sec) => DropdownMenuItem(value: sec, child: Text(sec, overflow: TextOverflow.ellipsis))),
                              const DropdownMenuItem(value: '__custom__', child: Text('+ Custom Section...', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedSection = val);
                            },
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
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
                                    DropdownMenuItem(value: 'Grade 7', child: Text('Grade 7', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'Grade 8', child: Text('Grade 8', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'Grade 9', child: Text('Grade 9', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'Grade 10', child: Text('Grade 10', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'Grade 11', child: Text('Grade 11', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'Grade 12', child: Text('Grade 12', overflow: TextOverflow.ellipsis)),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedGrade = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
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
                                    ...sectionOptions.map((sec) => DropdownMenuItem(value: sec, child: Text(sec, overflow: TextOverflow.ellipsis))),
                                    const DropdownMenuItem(value: '__custom__', child: Text('+ Custom Section...', overflow: TextOverflow.ellipsis)),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedSection = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
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
                          isExpanded: true,
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
                            DropdownMenuItem(value: 'regular', child: Text('Regular Student (Standard Curriculum)', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'irregular', child: Text('Irregular / Cross-Enrollee', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'transferee', child: Text('Transferee Student', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'sped', child: Text('SPED / Accommodated Student', overflow: TextOverflow.ellipsis)),
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

                          final cleanFirst = normalizeNamePart(firstNameCtrl.text);
                          final cleanMiddle = normalizeNamePart(middleNameCtrl.text);
                          final cleanLast = normalizeNamePart(lastNameCtrl.text);
                          final sfx = (selectedSuffix != 'None' && selectedSuffix.isNotEmpty) ? ' $selectedSuffix' : '';
                          final computedFullName = cleanMiddle.isNotEmpty
                              ? '$cleanFirst $cleanMiddle $cleanLast$sfx'
                              : '$cleanFirst $cleanLast$sfx';

                          final autoUsername = (usernameCtrl.text.trim().isNotEmpty)
                              ? usernameCtrl.text.trim()
                              : '${cleanFirst.toLowerCase().split(' ').first}.${cleanLast.toLowerCase().replaceAll(' ', '')}';

                          try {
                            final createdSid = await ref.read(adminStudentsProvider.notifier).addStudent(
                                  id: studentIdCtrl.text.trim().isNotEmpty ? studentIdCtrl.text.trim() : null,
                                  fullName: computedFullName,
                                  email: emailCtrl.text.trim(),
                                  password: passwordCtrl.text.trim(),
                                  username: autoUsername,
                                  grade: selectedGrade,
                                  section: finalSection,
                                  studentType: selectedType,
                                  specialNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                  enrollSubjectIds: selectedSubjectIds.isNotEmpty ? selectedSubjectIds.toList() : null,
                                );
                            final emailResult = EmailService.lastResult;
                            final emailSent = emailResult?.success ?? false;
                            final isQueued = emailResult?.channel == 'cloud_queue_pending';
                            final finalStudentId = createdSid.isNotEmpty ? createdSid : studentIdCtrl.text.trim();

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
                                              ? (isQueued
                                                  ? 'Student "$computedFullName" ($finalStudentId) onboarded! Credentials queued for delivery to ${emailCtrl.text.trim()} via Gmail SMTP.'
                                                  : 'Student "$computedFullName" ($finalStudentId) onboarded! Credentials sent to ${emailCtrl.text.trim()} via Gmail SMTP!')
                                              : 'Student "$computedFullName" ($finalStudentId) created! Note: SMTP email could not be delivered (${emailResult?.message ?? "SMTP bridge error"}). You can resend anytime using the Resend button.',
                                        ),
                                      ),
                                    ],
                                  ),
                                  action: !emailSent
                                      ? SnackBarAction(
                                          label: 'Resend',
                                          textColor: Colors.white,
                                          onPressed: () {
                                            _resendStudentCredentialsDialog(context, {
                                              'id': finalStudentId,
                                              'full_name': computedFullName,
                                              'email': emailCtrl.text.trim(),
                                            });
                                          },
                                        )
                                      : null,
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
