import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/animations/animated_pressable.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/components/user_avatar_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
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
    setState(() {
      _displayLimit = _pageSize;
    });
    ref.read(teacherStudentsProvider.notifier).reload(
          section: _selectedSection == 'All Sections' ? null : _selectedSection,
          query: _searchController.text.trim(),
        );
  }

  void _onSelectSection(String section) {
    setState(() {
      _selectedSection = section;
      _displayLimit = _pageSize;
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
                            onTap: () => setState(() => _activeTab = 0),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildSegmentTab(
                            label: 'Quiz Scores',
                            icon: Icons.assignment_turned_in_rounded,
                            isActive: _activeTab == 1,
                            onTap: () => setState(() => _activeTab = 1),
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
                          // Header & Section Exploration Area
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
                          child: Icon(Icons.people_alt, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Students',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.text,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedSection == 'All Sections'
                                    ? '${students.length} students across your assigned sections'
                                    : '${students.length} students enrolled in Section $_selectedSection',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section Cards Overview (Assigned Sections)
                    if (handledSections.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Assigned Sections',
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
                      ),
                      const SizedBox(height: 14),
                    ],

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
                                  ? 'Search students across all sections...'
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
                              if (_selectedSection != 'All Sections') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.28)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.filter_alt_rounded, size: 14, color: AppTheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Section: ${_cleanSectionName(_selectedSection)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () => _onSelectSection('All Sections'),
                                        child: Icon(Icons.close_rounded, size: 15, color: AppTheme.primary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
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
                            if (_selectedSection != 'All Sections') ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.filter_alt_rounded, size: 13, color: AppTheme.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Filtered: ${_cleanSectionName(_selectedSection)}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () => _onSelectSection('All Sections'),
                                          child: Icon(Icons.close_rounded, size: 14, color: AppTheme.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${students.length} ${students.length == 1 ? 'Student' : 'Students'}',
                                    style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        );
                      },
                    ),

                    // Fallback Filter chips row only if handledSections is empty
                    if (handledSections.isEmpty && combinedSections.length > 1) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
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
                  ],
                ),
              ),

              Divider(height: 1, color: AppTheme.border),

              // Student list
              Expanded(
                child: students.isEmpty
                    ? _searchController.text.isNotEmpty
                        ? AppEmptyState.search(
                            query: _searchController.text,
                            onClearSearch: () => _searchController.clear(),
                          )
                        : _selectedSection != 'All Sections'
                            ? AppEmptyState(
                                icon: Icons.group_off_outlined,
                                title: 'No Students in Section $_selectedSection',
                                message: 'No students are currently enrolled in section "$_selectedSection". Select below to view all sections.',
                                actionLabel: 'View All Sections',
                                actionIcon: Icons.groups_outlined,
                                onAction: () => _onSelectSection('All Sections'),
                              )
                            : AppEmptyState(
                                icon: Icons.people_outline,
                                title: 'No Students Found',
                                message: 'No students have been assigned to your classes yet. Select below to refresh your student list.',
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
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 480,
                                mainAxisExtent: 118,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: itemCount,
                              itemBuilder: (context, index) => _buildStudentListItem(context, index, students),
                            );
                          }

                          return ListView.builder(
                            padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad),
                            itemCount: itemCount,
                            itemBuilder: (context, index) => _buildStudentListItem(context, index, students),
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
    bool isAllCard = false,
  }) {
    final displayName = isAllCard ? 'All Sections' : _cleanSectionName(name);
    final displayGrade = isAllCard
        ? 'All Levels'
        : (grade.isNotEmpty ? grade : (name.startsWith('Grade') ? name.split('-').first.trim() : 'Section'));

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
          constraints: const BoxConstraints(minWidth: 165),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
