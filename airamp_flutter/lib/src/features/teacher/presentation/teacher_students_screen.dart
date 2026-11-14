import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/animations/animated_pressable.dart';
import '../../../core/components/app_toast.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/components/skeleton_loader.dart';
import '../../../core/components/user_avatar_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/section_key_helper.dart';
import '../../admin/data/admin_repository.dart';
import '../../admin/presentation/scores_screen.dart';
import '../../chat/application/chat_provider.dart';
import '../data/teacher_repository.dart';

class TeacherStudentsScreen extends ConsumerStatefulWidget {
  final String? initialSection;
  final int initialTab; // 0: Students, 1: Scores

  const TeacherStudentsScreen({
    super.key,
    this.initialSection,
    this.initialTab = 0,
  });

  @override
  ConsumerState<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends ConsumerState<TeacherStudentsScreen> {
  final _searchController = TextEditingController();
  late String _selectedSection;
  late int _activeTab;
  static const int _pageSize = 25;
  int _displayLimit = _pageSize;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
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
    if (widget.initialTab != oldWidget.initialTab && widget.initialTab != _activeTab) {
      setState(() {
        _activeTab = widget.initialTab;
      });
    }
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
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _displayLimit = _pageSize;
      });
      ref.read(teacherStudentsProvider.notifier).reload(
            section: _selectedSection == 'All Sections' ? null : _selectedSection,
            query: _searchController.text.trim(),
          );
    });
  }

  void _onSelectSection(String section) {
    if (_selectedSection == section) return;
    setState(() {
      _selectedSection = section;
      _displayLimit = _pageSize;
    });

    // Synchronize selection with GoRouter URL query parameters
    final queryParams = <String, String>{};
    if (section != 'All Sections') {
      queryParams['section'] = section;
    }
    if (_activeTab == 1) {
      queryParams['tab'] = 'scores';
    }
    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final targetPath = queryString.isNotEmpty
        ? '/teacher/students?$queryString'
        : '/teacher/students';
    context.go(targetPath);

    ref.read(teacherStudentsProvider.notifier).reload(
          section: section == 'All Sections' ? null : section,
          query: _searchController.text.trim(),
        );
  }

  void _onSelectTab(int tab) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
    });
    final queryParams = <String, String>{};
    if (_selectedSection != 'All Sections') {
      queryParams['section'] = _selectedSection;
    }
    if (tab == 1) {
      queryParams['tab'] = 'scores';
    }
    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final targetPath = queryString.isNotEmpty
        ? '/teacher/students?$queryString'
        : '/teacher/students';
    context.go(targetPath);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  String _cleanSectionName(String raw) {
    var clean = raw.trim();
    if (clean.toLowerCase().startsWith('grade')) {
      final dashIdx = clean.indexOf('-');
      if (dashIdx != -1) {
        clean = clean.substring(dashIdx + 1).trim();
      }
    }
    return clean;
  }

  String _formatSectionBadge(String section, String grade) {
    var cleanSec = section.trim();
    if (cleanSec.toLowerCase().startsWith('grade')) {
      final idx = cleanSec.indexOf('-');
      if (idx != -1) cleanSec = cleanSec.substring(idx + 1).trim();
    }
    if (grade.isNotEmpty && cleanSec.isNotEmpty && cleanSec != 'Unassigned') {
      return '$grade • Sec. $cleanSec';
    } else if (cleanSec.isNotEmpty && cleanSec != 'Unassigned') {
      return 'Sec. $cleanSec';
    } else if (grade.isNotEmpty) {
      return grade;
    }
    return section;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final students = ref.watch(teacherStudentsProvider);
    final isLoading = ref.watch(isTeacherStudentsLoadingProvider);
    final sectionsDetailsAsync = ref.watch(teacherHandledSectionsDetailsProvider);
    final sectionsListAsync = ref.watch(availableSectionsProvider);

    final handledSections = sectionsDetailsAsync.value ?? [];
    final fallbackSections = sectionsListAsync.value ?? [];

    // Synthesize structured classroom section list so classrooms ALWAYS render first
    List<Map<String, dynamic>> effectiveSections = List.from(handledSections);
    if (effectiveSections.isEmpty && fallbackSections.isNotEmpty) {
      effectiveSections = fallbackSections.map((secName) {
        String grade = '';
        if (secName.toLowerCase().startsWith('grade')) {
          final dash = secName.indexOf('-');
          if (dash != -1) {
            grade = secName.substring(0, dash).trim();
          }
        }
        final count = students.where((s) {
          final sSec = (s['section'] as String?)?.toLowerCase().trim() ?? '';
          final cleanName = secName.toLowerCase().trim();
          return sSec == cleanName ||
              (sSec.isNotEmpty &&
                  (sSec.contains(cleanName) || cleanName.contains(sSec)));
        }).length;

        final enrollmentKey = SectionKeyHelper.generateKey(
          sectionName: secName,
          gradeLevel: grade,
        );

        return {
          'name': secName,
          'grade': grade.isNotEmpty ? grade : 'Section',
          'room': '',
          'enrollment_key': enrollmentKey,
          'student_count': count,
          'enrolled_count': count,
        };
      }).toList();
    }

    // Ensure all effective sections have valid enrollment keys
    for (final sec in effectiveSections) {
      if ((sec['enrollment_key'] as String?)?.isEmpty ?? true) {
        sec['enrollment_key'] = SectionKeyHelper.generateKey(
          sectionName: sec['name'] as String? ?? 'Section',
          gradeLevel: sec['grade'] as String?,
        );
      }
    }

    final activeSectionData = effectiveSections.firstWhere(
      (s) =>
          (s['name'] as String? ?? '').toLowerCase().trim() ==
          _selectedSection.toLowerCase().trim(),
      orElse: () => {
        'name': _selectedSection,
        'grade': '',
        'room': '',
        'enrollment_key':
            SectionKeyHelper.generateKey(sectionName: _selectedSection),
        'student_count': students.length,
      },
    );
    final activeKey =
        (activeSectionData['enrollment_key'] as String?)?.trim().toUpperCase() ??
            SectionKeyHelper.generateKey(sectionName: _selectedSection);

    final handledNames =
        effectiveSections.map((s) => s['name'] as String).toList();
    final sectionChipNames =
        handledNames.isNotEmpty ? handledNames : fallbackSections;
    final combinedSections =
        <String>{'All Sections', ...sectionChipNames}.toList();

    final totalStudentCount = effectiveSections.fold<int>(
      0,
      (sum, s) => sum + (s['student_count'] as int? ?? 0),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Segmented Pill Toggle: Students vs Quiz Scores
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
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
                      children: [
                        Expanded(
                          child: _buildSegmentTab(
                            label: 'Students',
                            icon: Icons.people_alt_rounded,
                            isActive: _activeTab == 0,
                            onTap: () => _onSelectTab(0),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildSegmentTab(
                            label: 'Quiz Scores',
                            icon: Icons.assignment_turned_in_rounded,
                            isActive: _activeTab == 1,
                            onTap: () => _onSelectTab(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Tab Content
            Expanded(
              child: _activeTab == 0
                  ? RefreshIndicator(
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
                          // Header & Classroom Exploration Area (Classroom First)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                          child: Icon(Icons.school_rounded, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Classrooms & Students',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.text,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Select a classroom first to view its enrolled students and learning progress',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Classroom Selection Hub (Classroom First Cards)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.meeting_room_rounded, size: 16, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Assigned Classrooms',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedSection != 'All Sections')
                          InkWell(
                            onTap: () => _onSelectSection('All Sections'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.clear_all_rounded, size: 14, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'View All Classrooms',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 94,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        clipBehavior: Clip.none,
                        child: Row(
                          children: [
                            // "All Sections" Card
                            _buildSectionCard(
                              name: 'All Sections',
                              grade: 'All Levels',
                              studentCount: totalStudentCount > 0 ? totalStudentCount : students.length,
                              isSelected: _selectedSection == 'All Sections',
                              onTap: () => _onSelectSection('All Sections'),
                              isAllCard: true,
                            ),
                            // Individual Handled Section Cards
                            ...effectiveSections.map((sec) {
                              final name = sec['name'] as String? ?? 'Section';
                              final grade = sec['grade'] as String? ?? '';
                              final count = sec['student_count'] as int? ?? 0;
                              final secKey = (sec['enrollment_key'] as String?)?.trim().toUpperCase() ??
                                  SectionKeyHelper.generateKey(sectionName: name, gradeLevel: grade);
                              final isSelected =
                                  _selectedSection.toLowerCase() == name.toLowerCase();

                              return _buildSectionCard(
                                name: name,
                                grade: grade,
                                studentCount: count,
                                enrollmentKey: secKey,
                                isSelected: isSelected,
                                onTap: () => _onSelectSection(name),
                                onProject: () {
                                  _showClassroomProjectionDialog(
                                    context: context,
                                    sectionName: name,
                                    grade: grade,
                                    enrollmentKey: secKey,
                                    studentCount: count,
                                  );
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Active Classroom Context Banner with Projection Actions
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedSection != 'All Sections'
                            ? AppTheme.primary.withValues(alpha: 0.08)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedSection != 'All Sections'
                              ? AppTheme.primary.withValues(alpha: 0.25)
                              : AppTheme.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: _selectedSection != 'All Sections'
                                  ? AppTheme.primary.withValues(alpha: 0.16)
                                  : AppTheme.border.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _selectedSection != 'All Sections'
                                  ? Icons.meeting_room_rounded
                                  : Icons.groups_rounded,
                              size: 16,
                              color: _selectedSection != 'All Sections'
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _selectedSection != 'All Sections'
                                          ? 'Classroom: ${_cleanSectionName(_selectedSection)}'
                                          : 'All Classrooms Roster',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedSection != 'All Sections'
                                            ? AppTheme.primary
                                            : AppTheme.text,
                                      ),
                                    ),
                                    if (_selectedSection != 'All Sections' && activeKey.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: activeKey));
                                          AppToast.showSuccess(context, 'Section Key "$activeKey" copied to clipboard!');
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: AppTheme.primary.withValues(alpha: 0.3),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.key_rounded, size: 11, color: AppTheme.primary),
                                              const SizedBox(width: 3),
                                              Text(
                                                activeKey,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontFamily: 'monospace',
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 3),
                                              Icon(Icons.copy_rounded, size: 10, color: AppTheme.primary),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  _selectedSection != 'All Sections'
                                      ? '${students.length} ${students.length == 1 ? 'student enrolled' : 'students enrolled'} in Section $_selectedSection'
                                      : '${students.length} ${students.length == 1 ? 'student' : 'students'} across your assigned sections',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedSection != 'All Sections') ...[
                            ElevatedButton.icon(
                              icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                              label: const Text('Project QR', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                _showClassroomProjectionDialog(
                                  context: context,
                                  sectionName: _selectedSection,
                                  grade: activeSectionData['grade'] as String? ?? '',
                                  enrollmentKey: activeKey,
                                  studentCount: students.length,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _onSelectSection('All Sections'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.close_rounded, size: 13, color: AppTheme.textMuted),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Clear',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else if (effectiveSections.isNotEmpty) ...[
                            OutlinedButton.icon(
                              icon: const Icon(Icons.qr_code_2_rounded, size: 15),
                              label: const Text('Project QR', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                final firstSec = effectiveSections.first;
                                final firstKey = (firstSec['enrollment_key'] as String?)?.trim().toUpperCase() ??
                                    SectionKeyHelper.generateKey(sectionName: firstSec['name'] as String? ?? '');
                                _showClassroomProjectionDialog(
                                  context: context,
                                  sectionName: firstSec['name'] as String? ?? 'Section',
                                  grade: firstSec['grade'] as String? ?? '',
                                  enrollmentKey: firstKey,
                                  studentCount: firstSec['student_count'] as int? ?? 0,
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Responsive Search & Unified Filter Bar
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 640;
                        final searchField = SizedBox(
                          height: 44,
                          child: TextField(
                            controller: _searchController,
                            maxLength: 60,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            style: TextStyle(color: AppTheme.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              hintText: _selectedSection == 'All Sections'
                                  ? 'Search students across all classrooms...'
                                  : 'Search students in ${_cleanSectionName(_selectedSection)}...',
                              counterText: '',
                              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 19),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear_rounded, color: AppTheme.textMuted, size: 17),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: AppTheme.surface,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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
                                borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                              ),
                            ),
                          ),
                        );

                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 480),
                                  child: searchField,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(
                                  '${students.length} ${students.length == 1 ? 'Student' : 'Students'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            searchField,
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${students.length} ${students.length == 1 ? 'Student' : 'Students'}',
                                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: AppTheme.border),

              // Student list with Skeleton Shimmer loader
              Expanded(
                child: isLoading
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth >= 768;
                          return _buildSkeletonList(isDesktop);
                        },
                      )
                    : students.isEmpty
                        ? _searchController.text.isNotEmpty
                            ? AppEmptyState.search(
                                query: _searchController.text,
                                onClearSearch: () => _searchController.clear(),
                              )
                            : _selectedSection != 'All Sections'
                                ? AppEmptyState(
                                    icon: Icons.group_off_outlined,
                                    title: 'No Students in Section $_selectedSection',
                                    message:
                                        'No students are currently enrolled in section "$_selectedSection". Select below to view all classrooms.',
                                    actionLabel: 'View All Classrooms',
                                    actionIcon: Icons.groups_outlined,
                                    onAction: () => _onSelectSection('All Sections'),
                                  )
                                : AppEmptyState(
                                    icon: Icons.people_outline,
                                    title: 'No Students Found',
                                    message:
                                        'No students have been assigned to your classes yet. Select below to refresh your student list.',
                                    actionLabel: 'Refresh Students',
                                    actionIcon: Icons.refresh_rounded,
                                    onAction: () {
                                      ref.read(teacherStudentsProvider.notifier).reload(
                                            section: null,
                                            query: '',
                                          );
                                    },
                                  )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final isDesktop = constraints.maxWidth >= 768;
                              final bottomPad = isDesktop ? 24.0 : 100.0;
                              final itemCount = students.length > _displayLimit
                                  ? _displayLimit + 1
                                  : students.length;

                              if (isDesktop) {
                                return GridView.builder(
                                  padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 480,
                                    mainAxisExtent: 118,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: itemCount,
                                  itemBuilder: (context, index) =>
                                      _buildStudentListItem(context, index, students),
                                );
                              }

                              return ListView.builder(
                                padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad),
                                itemCount: itemCount,
                                itemBuilder: (context, index) =>
                                    _buildStudentListItem(context, index, students),
                              );
                            },
                          ),
              ),
            ],
          ),
        )
      : ScoresScreen(
          isEmbedded: true,
          initialSection: _selectedSection == 'All Sections' ? null : _selectedSection,
          sections: combinedSections,
        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentListItem(BuildContext context, int index, List<Map<String, dynamic>> students) {
    if (index == _displayLimit && students.length > _displayLimit) {
      final remaining = students.length - _displayLimit;
      return Center(
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
                  'Load More Students ($remaining remaining)',
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
      );
    }

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
      padding: const EdgeInsets.all(14),
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
          UserAvatarWidget(
            imageSource: (student['profile_image'] ?? student['profileImage']) as String?,
            fallbackInitial: initial,
            size: 42,
            fontSize: 15,
          ),
          const SizedBox(width: 12),
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
                          fontSize: 14,
                          color: AppTheme.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.border.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatSectionBadge(section, grade),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 13, color: AppTheme.success),
                        const SizedBox(width: 4),
                        Text(
                          '$completedLos LOs Completed',
                          style: TextStyle(fontSize: 10.5, color: AppTheme.text),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.book_outlined, size: 13, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          '$enrolledSubjects Subjects',
                          style: TextStyle(fontSize: 10.5, color: AppTheme.text),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: AppTheme.primary, size: 19),
            tooltip: 'Message $name',
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
  }

  Widget _buildSkeletonList(bool isDesktop) {
    final bottomPad = isDesktop ? 24.0 : 100.0;
    if (isDesktop) {
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 480,
          mainAxisExtent: 118,
          crossAxisSpacing: 14,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => _buildSkeletonItem(),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildSkeletonItem(),
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      height: 114,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(
            width: 42,
            height: 42,
            borderRadius: BorderRadius.all(Radius.circular(21)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                SkeletonLoader(width: 140, height: 16),
                SkeletonLoader(width: 190, height: 12),
                SkeletonLoader(width: 110, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? Colors.white : AppTheme.textSecondary,
                letterSpacing: -0.2,
              ),
            ),
          ],
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
    String? enrollmentKey,
    VoidCallback? onProject,
    bool isAllCard = false,
  }) {
    final displayName = isAllCard ? 'All Sections' : _cleanSectionName(name);
    final displayGrade = isAllCard
        ? 'All Levels'
        : (grade.isNotEmpty
            ? grade
            : (name.startsWith('Grade') ? name.split('-').first.trim() : 'Section'));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minWidth: 175),
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.20)
                          : AppTheme.border.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      isAllCard ? Icons.grid_view_rounded : Icons.layers_rounded,
                      size: 15,
                      color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: isSelected ? AppTheme.primary : AppTheme.text,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.primary),
                  ],
                  if (!isAllCard && onProject != null) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Project Classroom QR',
                      child: InkWell(
                        onTap: onProject,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.22)
                                : AppTheme.border.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.qr_code_2_rounded,
                            size: 13,
                            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayGrade,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.22)
                          : AppTheme.border.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
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
                  if (!isAllCard && enrollmentKey != null && enrollmentKey.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      enrollmentKey,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClassroomProjectionDialog({
    required BuildContext context,
    required String sectionName,
    required String grade,
    required String enrollmentKey,
    int studentCount = 0,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final primary = AppTheme.primary;
          final displayName = _cleanSectionName(sectionName);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D2E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.qr_code_2_rounded, color: primary, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Classroom Projection',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.text,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$sectionName ${grade.isNotEmpty ? "• $grade" : ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 22),
                            color: AppTheme.textMuted,
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // High-Contrast White QR Surface for Classroom Projector/Screen
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: enrollmentKey,
                          version: QrVersions.auto,
                          size: 220.0,
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Scan with AIRAMP camera scanner to enroll',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section Key Box with Copy
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: enrollmentKey));
                          AppToast.showSuccess(context, 'Section Key "$enrollmentKey" copied to clipboard!');
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: primary.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'SECTION KEY',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    enrollmentKey,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: primary,
                                      letterSpacing: 3.0,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(Icons.copy_rounded, color: primary, size: 20),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Onboarding instructions for students
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 14, color: primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Student Onboarding Steps',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildInstructionStep('1', 'Open AIRAMP and go to My Courses'),
                            _buildInstructionStep('2', 'Tap "Scan Classroom QR" or enter key'),
                            _buildInstructionStep('3', 'Verify & auto-enroll in all $displayName subjects'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Close & Copy Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Copy Key'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: enrollmentKey));
                                AppToast.showSuccess(context, 'Section Key "$enrollmentKey" copied to clipboard!');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructionStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              num,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
