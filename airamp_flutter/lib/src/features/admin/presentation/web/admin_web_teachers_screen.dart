import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/components/aira_action_toast.dart';
import '../../../../core/components/user_avatar_widget.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/email_service.dart';
import '../../data/admin_repository.dart';
import 'components/teacher_bulk_import_modal.dart';
import 'components/teacher_schedule_modal.dart';

class AdminWebTeachersScreen extends ConsumerStatefulWidget {
  const AdminWebTeachersScreen({super.key});

  @override
  ConsumerState<AdminWebTeachersScreen> createState() => _AdminWebTeachersScreenState();
}

class _AdminWebTeachersScreenState extends ConsumerState<AdminWebTeachersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isArchiveView = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedTeacherIds = {};

  String _formatArchivedDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Recently';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute $ampm';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teachers = ref.watch(adminTeachersProvider);
    final archivedTeachers = ref.watch(adminArchivedTeachersProvider);
    final subjects = ref.watch(subjectsProvider);

    final currentTeachersList = _isArchiveView ? archivedTeachers : teachers;

    final filteredTeachers = currentTeachersList.where((t) {
      if (_searchQuery.isEmpty) return true;
      final name = (t['full_name'] as String? ?? '').toLowerCase();
      final email = (t['email'] as String? ?? '').toLowerCase();
      final user = (t['username'] as String? ?? '').toLowerCase();
      final subs = (t['assigned_subjects'] as List? ?? []).map((s) => (s['name'] as String? ?? '').toLowerCase()).join(' ');
      return name.contains(_searchQuery) || email.contains(_searchQuery) || user.contains(_searchQuery) || subs.contains(_searchQuery);
    }).toList();

    // Summary calculations (based on active teachers)
    final totalTeachers = teachers.length;
    final totalAssignedSubjects = teachers.fold<int>(0, (sum, t) => sum + (t['assigned_subjects_count'] as int? ?? 0));
    final allSections = <String>{};
    for (final t in teachers) {
      final secs = t['handled_sections'] as List? ?? [];
      for (final s in secs) {
        allSections.add(s.toString());
      }
    }
    final totalStudentsReached = teachers.fold<int>(0, (sum, t) => sum + (t['student_count'] as int? ?? 0));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(adminTeachersProvider.notifier).loadTeachers();
          await ref.read(adminArchivedTeachersProvider.notifier).loadArchivedTeachers();
          await ref.read(subjectsProvider.notifier).reload();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isNarrow = headerConstraints.maxWidth < 800;

                  final titleSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Faculty & Teacher Management',
                        style: TextStyle(
                          fontSize: isNarrow ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage school instructors, course assignments, handled sections, and teaching workloads',
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
                        onPressed: () => context.go('/admin/schedules'),
                        icon: const Icon(Icons.calendar_month_outlined, size: 18),
                        label: const Text('Master Timetable', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.text,
                          side: BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: const Size(0, 42),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => TeacherBulkImportModal.show(context),
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        label: const Text('Bulk Import (CSV)', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.text,
                          side: BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: const Size(0, 42),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openAddTeacherDialog(context, subjects),
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('Add New Faculty'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                          minimumSize: const Size(0, 42),
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
              const SizedBox(height: 18),

              // View Mode Switcher: Active Faculty vs Archive Vault
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isArchiveView = false;
                              _isSelectionMode = false;
                              _selectedTeacherIds.clear();
                            });
                          },
                          borderRadius: BorderRadius.circular(9),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: !_isArchiveView ? AppTheme.surface : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: !_isArchiveView
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
                                  Icons.badge_outlined,
                                  size: 16,
                                  color: !_isArchiveView ? AppTheme.primary : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Active Faculty (${teachers.length})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !_isArchiveView ? FontWeight.bold : FontWeight.w500,
                                    color: !_isArchiveView ? AppTheme.text : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isArchiveView = true;
                              _isSelectionMode = false;
                              _selectedTeacherIds.clear();
                            });
                          },
                          borderRadius: BorderRadius.circular(9),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isArchiveView ? AppTheme.surface : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: _isArchiveView
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
                                  color: _isArchiveView ? const Color(0xFFD97706) : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Deactivated Accounts (${archivedTeachers.length})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _isArchiveView ? FontWeight.bold : FontWeight.w500,
                                    color: _isArchiveView ? const Color(0xFFD97706) : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (!_isArchiveView) ...[
                // KPI Stats Overview Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 800;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildKpiCard(
                          title: 'Total Faculty',
                          value: '$totalTeachers',
                          icon: Icons.badge_outlined,
                          color: AppTheme.primary,
                          width: isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                        ),
                        _buildKpiCard(
                          title: 'Assigned Courses',
                          value: '$totalAssignedSubjects',
                          icon: Icons.menu_book_outlined,
                          color: AppTheme.primary,
                          width: isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                        ),
                        _buildKpiCard(
                          title: 'Handled Sections',
                          value: '${allSections.length}',
                          icon: Icons.groups_outlined,
                          color: AppTheme.primary,
                          width: isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                        ),
                        _buildKpiCard(
                          title: 'Students Reached',
                          value: '$totalStudentsReached',
                          icon: Icons.school_outlined,
                          color: AppTheme.primary,
                          width: isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                        ),
                      ],
                    );
                  },
                ),
              ] else ...[
                // Faculty Archive Vault Banner
                Container(
                  padding: const EdgeInsets.all(20),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_off_outlined, color: Color(0xFFD97706), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Deactivated Faculty Accounts',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF92400E),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${filteredTeachers.length} Record${filteredTeachers.length == 1 ? '' : 's'}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Deactivated faculty accounts are safely preserved here with their profile and teaching history intact. You can reactivate them to active status or delete them permanently.',
                                  style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF78350F)),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _isArchiveView = false;
                                _selectedTeacherIds.clear();
                              });
                            },
                            icon: const Icon(Icons.arrow_back, size: 14),
                            label: const Text('Back to Active Faculty', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD97706)),
                          ),
                        ],
                      ),
                      if (filteredTeachers.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  if (_selectedTeacherIds.length == filteredTeachers.length) {
                                    _selectedTeacherIds.clear();
                                    _isSelectionMode = false;
                                  } else {
                                    _isSelectionMode = true;
                                    for (final t in filteredTeachers) {
                                      final id = t['id'] as String?;
                                      if (id != null) _selectedTeacherIds.add(id);
                                    }
                                  }
                                });
                              },
                              icon: Icon(
                                _selectedTeacherIds.length == filteredTeachers.length && filteredTeachers.isNotEmpty
                                    ? Icons.deselect_rounded
                                    : Icons.select_all_rounded,
                                size: 16,
                              ),
                              label: Text(
                                _selectedTeacherIds.length == filteredTeachers.length && filteredTeachers.isNotEmpty
                                    ? 'Deselect All'
                                    : 'Select All (${filteredTeachers.length})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                side: BorderSide(color: const Color(0xFFD97706).withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            if (_selectedTeacherIds.isNotEmpty) ...[
                              ElevatedButton.icon(
                                onPressed: () => _confirmBulkRestore(context, _selectedTeacherIds.toList()),
                                icon: const Icon(Icons.restore_rounded, size: 15),
                                label: Text('Restore Selected (${_selectedTeacherIds.length})'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _confirmBulkPermanentDelete(context, _selectedTeacherIds.toList()),
                                icon: const Icon(Icons.delete_forever_rounded, size: 15),
                                label: Text('Delete Permanently (${_selectedTeacherIds.length})'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.error,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Search & Filter Toolbar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        maxLength: 60,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        style: TextStyle(color: AppTheme.text, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _isArchiveView
                              ? 'Search deactivated faculty by name, email, or username...'
                              : 'Search faculty by name, email, username, or assigned subject...',
                          hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                          counterText: '',
                          prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        '${filteredTeachers.length} ${_isArchiveView ? 'Deactivated Records' : 'Faculty Members'}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = !_isSelectionMode;
                          if (!_isSelectionMode) {
                            _selectedTeacherIds.clear();
                          }
                        });
                      },
                      icon: Icon(
                        _isSelectionMode ? Icons.close_rounded : Icons.checklist_rounded,
                        size: 16,
                        color: _isSelectionMode ? AppTheme.error : AppTheme.primary,
                      ),
                      label: Text(
                        _isSelectionMode ? 'Cancel Selection' : 'Select Multiple',
                        style: TextStyle(
                          fontSize: 12.5,
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(0, 42),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Multi-select Batch Action Toolbar
              _buildBatchActionBar(filteredTeachers, isDark),

              // Faculty Table / List
              if (filteredTeachers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isArchiveView ? Icons.person_off_outlined : Icons.badge_outlined,
                        size: 64,
                        color: AppTheme.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isArchiveView
                            ? (_searchQuery.isEmpty ? 'No Deactivated Faculty' : 'No Deactivated Faculty Matching "$_searchQuery"')
                            : (_searchQuery.isEmpty ? 'No Faculty Registered Yet' : 'No Faculty Matching "$_searchQuery"'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isArchiveView
                            ? (_searchQuery.isEmpty
                                ? 'When faculty members are deactivated, they are safely kept here and can be reactivated or purged permanently.'
                                : 'Try adjusting your search criteria or clear the search filter.')
                            : (_searchQuery.isEmpty
                                ? 'Click "Add New Faculty" above to onboard your school teaching staff.'
                                : 'Try adjusting your search criteria or clear the search filter.'),
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      if (_isArchiveView) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isArchiveView = false;
                              _selectedTeacherIds.clear();
                            });
                          },
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Back to Active Faculty'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                Container(
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
                        constraints: const BoxConstraints(minWidth: 900),
                        child: DataTable(
                          showCheckboxColumn: _isSelectionMode,
                          onSelectAll: _isSelectionMode
                              ? (val) {
                                  setState(() {
                                    if (val == true) {
                                      for (final t in filteredTeachers) {
                                        final id = t['id'] as String?;
                                        if (id != null) _selectedTeacherIds.add(id);
                                      }
                                    } else {
                                      for (final t in filteredTeachers) {
                                        final id = t['id'] as String?;
                                        if (id != null) _selectedTeacherIds.remove(id);
                                      }
                                    }
                                  });
                                }
                              : null,
                          headingRowColor: WidgetStateProperty.all(AppTheme.background),
                          headingTextStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                          dataRowMaxHeight: 76,
                          horizontalMargin: 20,
                          columnSpacing: 24,
                          columns: [
                            const DataColumn(label: Text('FACULTY MEMBER')),
                            const DataColumn(label: Text('CONTACT & USERNAME')),
                            const DataColumn(label: Text('ASSIGNED SUBJECTS')),
                            const DataColumn(label: Text('HANDLED SECTIONS')),
                            DataColumn(label: Text(_isArchiveView ? 'DEACTIVATED AT' : 'STUDENTS REACH')),
                            const DataColumn(label: Text('ACTIONS')),
                          ],
                          rows: filteredTeachers.map((teacher) {
                            final teacherId = teacher['id'] as String? ?? '';
                            final isSelected = _selectedTeacherIds.contains(teacherId);
                            final rawName = teacher['full_name'] as String? ?? teacher['name'] as String? ?? '';
                            final email = teacher['email'] as String? ?? '';
                            final username = teacher['username'] as String? ?? '';
                            final safeName = rawName.trim().isNotEmpty
                                ? rawName.trim()
                                : (email.isNotEmpty ? email : (teacherId.isNotEmpty ? teacherId : 'Teacher'));
                            final assignedSubjects = (teacher['assigned_subjects'] as List? ?? []).cast<Map<String, dynamic>>();
                            final handledSections = (teacher['handled_sections'] as List? ?? []).map((s) => s.toString()).toList();
                            final studentCount = teacher['student_count'] as int? ?? 0;
                            final archivedAt = teacher['archived_at'] as String?;

                            return DataRow(
                              selected: _isSelectionMode && isSelected,
                              onSelectChanged: _isSelectionMode
                                  ? (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedTeacherIds.add(teacherId);
                                        } else {
                                          _selectedTeacherIds.remove(teacherId);
                                        }
                                      });
                                    }
                                  : null,
                              cells: [
                                // Faculty Member
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      UserAvatarWidget(
                                        imageSource: (teacher['profile_image'] ?? teacher['profileImage']) as String?,
                                        fallbackInitial: safeName,
                                        size: 40,
                                        fontSize: 16,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            safeName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppTheme.text,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _isArchiveView ? 'Deactivated Faculty' : 'Faculty Instructor',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _isArchiveView ? const Color(0xFFD97706) : AppTheme.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Contact & Username
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        email,
                                        style: TextStyle(fontSize: 13, color: AppTheme.text),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '@$username',
                                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),

                                // Assigned Subjects
                                DataCell(
                                  assignedSubjects.isEmpty
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
                                          ),
                                          child: Text(
                                            'None assigned',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        )
                                      : Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: assignedSubjects.take(3).map((sub) {
                                            final code = sub['subject_code'] as String? ?? '';
                                            final title = sub['name'] as String? ?? 'Subject';
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                                              ),
                                              child: Text(
                                                code.isNotEmpty ? code : title,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFF5EEAD4) : AppTheme.primary,
                                                ),
                                              ),
                                            );
                                          }).toList()
                                            ..addAll(assignedSubjects.length > 3
                                                ? [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.surface,
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: AppTheme.border),
                                                      ),
                                                      child: Text(
                                                        '+${assignedSubjects.length - 3}',
                                                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                                      ),
                                                    )
                                                  ]
                                                : []),
                                        ),
                                ),

                                // Handled Sections
                                DataCell(
                                  handledSections.isEmpty
                                      ? Text('—', style: TextStyle(color: AppTheme.textMuted))
                                      : Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: handledSections.map((sec) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppTheme.border),
                                              ),
                                              child: Text(
                                                sec,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppTheme.text,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                ),

                                // Students Reach / Archived At
                                DataCell(
                                  _isArchiveView
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.history_rounded, size: 14, color: Color(0xFFD97706)),
                                            const SizedBox(width: 6),
                                            Text(
                                              _formatArchivedDate(archivedAt),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        )
                                      : (studentCount > 0
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.people_alt_outlined,
                                                    size: 14,
                                                    color: isDark ? const Color(0xFF5EEAD4) : AppTheme.primary,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    '$studentCount Enrolled',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark ? const Color(0xFF5EEAD4) : AppTheme.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.people_alt_outlined,
                                                  size: 14,
                                                  color: AppTheme.textMuted,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  '0 Enrolled',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.textMuted,
                                                  ),
                                                ),
                                              ],
                                            )),
                                ),

                                // Action Buttons
                                DataCell(
                                  _isArchiveView
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: () async {
                                                await ref.read(adminArchivedTeachersProvider.notifier).restoreTeacher(teacherId);
                                                if (context.mounted) {
                                                  AiraActionToast.showRestored(
                                                    context,
                                                    title: 'Faculty Account Restored',
                                                    message: 'Faculty member "$safeName" ($teacherId) was restored to active directory.',
                                                  );
                                                }
                                              },
                                              icon: const Icon(Icons.restore_rounded, size: 14),
                                              label: const Text('Restore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.success,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                elevation: 0,
                                                minimumSize: const Size(0, 32),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.delete_forever_rounded, size: 18),
                                              tooltip: 'Permanently Delete Faculty',
                                              color: AppTheme.error,
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () => _confirmPermanentDeleteTeacher(context, teacher),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.calendar_month_outlined, size: 18),
                                              tooltip: 'Manage Teacher Schedule',
                                              color: AppTheme.textSecondary,
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () => TeacherScheduleModal.show(context, teacher),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                                              tooltip: 'Assign Courses',
                                              color: AppTheme.textSecondary,
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () => _openAssignCoursesDialog(context, teacher, subjects),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 18),
                                              tooltip: 'Edit Profile',
                                              color: AppTheme.textSecondary,
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () => _openEditTeacherDialog(context, teacher),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.forward_to_inbox_rounded, size: 18),
                                              tooltip: 'Resend Credentials Email',
                                              color: AppTheme.textSecondary,
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () => _resendTeacherCredentialsDialog(context, teacher),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.person_off_outlined, size: 18),
                                              tooltip: 'Deactivate Account',
                                              color: const Color(0xFFD97706),
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () => _confirmArchiveTeacher(context, teacher),
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchActionBar(List<Map<String, dynamic>> currentList, bool isDark) {
    if (_selectedTeacherIds.isEmpty) return const SizedBox.shrink();

    final count = _selectedTeacherIds.length;
    final allInCurrentSelected = currentList.isNotEmpty && currentList.every((t) => _selectedTeacherIds.contains(t['id']));

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
            '$count of ${currentList.length} faculty selected',
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
                  for (final t in currentList) {
                    final id = t['id'] as String?;
                    if (id != null) _selectedTeacherIds.add(id);
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
              onPressed: () => _confirmBulkArchive(context, _selectedTeacherIds.toList()),
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
            ElevatedButton.icon(
              onPressed: () => _confirmBulkRestore(context, _selectedTeacherIds.toList()),
              icon: const Icon(Icons.restore_rounded, size: 14),
              label: Text('Restore Selected ($count)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _confirmBulkPermanentDelete(context, _selectedTeacherIds.toList()),
              icon: const Icon(Icons.delete_forever_rounded, size: 14),
              label: Text('Delete Permanently ($count)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedTeacherIds.clear();
                _isSelectionMode = false;
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              'Clear Selection',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Add New Faculty Dialog ─────────────────────────────────
  Future<void> _openAddTeacherDialog(BuildContext context, List<Map<String, dynamic>> availableSubjects) async {
    final nextId = await DatabaseHelper().generateNextTeacherId();
    final teacherIdCtrl = TextEditingController(text: nextId);
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: 'Teacher@123');
    final selectedSubjectIds = <int>{};
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;

    if (!context.mounted) return;

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
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person_add_alt_1, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('Add New Faculty Member', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Instructor Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: teacherIdCtrl,
                          maxLength: 15,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          style: TextStyle(color: AppTheme.text, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Faculty ID (e.g. 002-0001)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            counterText: '',
                            prefixIcon: Icon(Icons.badge_outlined, size: 20, color: AppTheme.textMuted),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter teacher ID' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: nameCtrl,
                          maxLength: 50,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          style: TextStyle(color: AppTheme.text, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Full Name (e.g. Sir Juan Luna)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            counterText: '',
                            prefixIcon: Icon(Icons.person_outline, size: 20, color: AppTheme.textMuted),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter teacher full name' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: emailCtrl,
                          maxLength: 50,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          style: TextStyle(color: AppTheme.text, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'School Email (e.g. juan.luna@school.edu)',
                            labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            counterText: '',
                            prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppTheme.textMuted),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter email';
                            if (!v.contains('@')) return 'Please enter a valid email address';
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

                        Text('Initial Course Assignments (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        if (availableSubjects.isEmpty)
                          Text('No subjects created in school curriculum yet.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
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
                                final currentTeacher = sub['teacher_name'] as String?;
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
                                  subtitle: currentTeacher != null && currentTeacher.isNotEmpty
                                      ? Text('Currently: $currentTeacher', style: TextStyle(fontSize: 11, color: AppTheme.textMuted))
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
                                  'SMTP Email Delivery: Teacher ID, username, and password will be sent automatically to the faculty email via Gmail SMTP.',
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
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      final createdTid = await ref.read(adminTeachersProvider.notifier).addTeacher(
                            id: teacherIdCtrl.text.trim().isNotEmpty ? teacherIdCtrl.text.trim() : null,
                            fullName: nameCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            password: passwordCtrl.text.trim(),
                            username: usernameCtrl.text.trim().isNotEmpty ? usernameCtrl.text.trim() : null,
                            assignSubjectIds: selectedSubjectIds.toList(),
                          );
                      final emailResult = EmailService.lastResult;
                      final emailSent = emailResult?.success ?? false;
                      final isQueued = emailResult?.channel == 'cloud_queue_pending';
                      final finalTeacherId = createdTid.isNotEmpty ? createdTid : teacherIdCtrl.text.trim();

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
                                            ? 'Faculty "${nameCtrl.text.trim()}" ($finalTeacherId) onboarded! Credentials queued for delivery to ${emailCtrl.text.trim()} via Gmail SMTP.'
                                            : 'Faculty "${nameCtrl.text.trim()}" ($finalTeacherId) onboarded! Credentials sent to ${emailCtrl.text.trim()} via Gmail SMTP!')
                                        : 'Faculty "${nameCtrl.text.trim()}" ($finalTeacherId) created! Note: SMTP email could not be delivered (${emailResult?.message ?? "SMTP bridge error"}). You can resend anytime using the Resend button.',
                                  ),
                                ),
                              ],
                            ),
                            action: !emailSent
                                ? SnackBarAction(
                                    label: 'Resend',
                                    textColor: Colors.white,
                                    onPressed: () {
                                      _resendTeacherCredentialsDialog(context, {
                                        'id': teacherIdCtrl.text.trim(),
                                        'full_name': nameCtrl.text.trim(),
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
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
                  child: const Text('Add Faculty Member'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Assign Courses Dialog ──────────────────────────────────
  void _openAssignCoursesDialog(BuildContext context, Map<String, dynamic> teacher, List<Map<String, dynamic>> availableSubjects) {
    final teacherId = teacher['id'] as String;
    final teacherName = teacher['full_name'] as String? ?? 'Teacher';
    final currentAssigned = (teacher['assigned_subjects'] as List? ?? []).cast<Map<String, dynamic>>();
    final selectedIds = currentAssigned.map((s) => s['id'] as int).toSet();

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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.assignment_ind_outlined, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Course Assignments', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('for $teacherName', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: availableSubjects.isEmpty
                    ? Text('No subjects in school curriculum yet.', style: TextStyle(color: AppTheme.textMuted))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select courses taught by this teacher. All sections and students enrolled in these courses will be automatically linked.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 280),
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
                                final existingTeacherId = sub['teacher_id'] as String?;
                                final existingTeacherName = sub['teacher_name'] as String?;
                                final isSelected = selectedIds.contains(id);
                                final isAssignedOther = existingTeacherId != null && existingTeacherId != teacherId && existingTeacherId.isNotEmpty;

                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedIds.add(id);
                                      } else {
                                        selectedIds.remove(id);
                                      }
                                    });
                                  },
                                  title: Text(
                                    code.isNotEmpty ? '$code — $name' : name,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                                  ),
                                  subtitle: isAssignedOther
                                      ? Text('Currently assigned to: $existingTeacherName (will be transferred)',
                                          style: TextStyle(fontSize: 11, color: AppTheme.warning, fontWeight: FontWeight.w500))
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
                    try {
                      await ref.read(adminTeachersProvider.notifier).updateTeacher(
                            teacherId,
                            {},
                            assignSubjectIds: selectedIds.toList(),
                          );
                      if (context.mounted) {
                        Navigator.of(dialogCtx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Course assignments updated for $teacherName'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
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
                  child: const Text('Save Assignments'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Edit Teacher Dialog ────────────────────────────────────
  void _openEditTeacherDialog(BuildContext context, Map<String, dynamic> teacher) {
    final teacherId = teacher['id'] as String;
    final nameCtrl = TextEditingController(text: teacher['full_name'] as String? ?? '');
    final emailCtrl = TextEditingController(text: teacher['email'] as String? ?? '');
    final usernameCtrl = TextEditingController(text: teacher['username'] as String? ?? '');
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
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
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Edit Faculty Profile', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    maxLength: 50,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      counterText: '',
                      prefixIcon: Icon(Icons.person_outline, size: 20, color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please enter name' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailCtrl,
                    maxLength: 50,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      counterText: '',
                      prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                    ),
                    validator: (v) => v == null || !v.contains('@') ? 'Enter valid email' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: usernameCtrl,
                    maxLength: 30,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Username',
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
                    maxLength: 16,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    obscureText: true,
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Reset Password (leave empty to keep current)',
                      labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      counterText: '',
                      prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  final data = <String, dynamic>{
                    'full_name': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'username': usernameCtrl.text.trim(),
                  };
                  if (passwordCtrl.text.trim().isNotEmpty) {
                    data['password'] = passwordCtrl.text.trim();
                  }
                  await ref.read(adminTeachersProvider.notifier).updateTeacher(teacherId, data);
                  if (context.mounted) {
                    Navigator.of(dialogCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Faculty profile updated successfully'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  // ── Resend Faculty Credentials Dialog ───────────────────────
  void _resendTeacherCredentialsDialog(BuildContext context, Map<String, dynamic> teacher) {
    final teacherId = teacher['id'] as String? ?? '';
    final teacherName = teacher['full_name'] as String? ?? 'Faculty Member';
    final teacherEmail = (teacher['email'] as String? ?? '').trim();

    if (teacherEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot send email: This faculty member has no email address configured.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final passwordCtrl = TextEditingController(text: 'Teacher@123');
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
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.forward_to_inbox_rounded, color: AppTheme.primary, size: 22),
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
                          'Dispatches login details directly to faculty email via Gmail SMTP',
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
                                Text('Faculty Name:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                Flexible(
                                  child: Text(
                                    teacherName,
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
                                    teacherEmail,
                                    style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Teacher ID:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                Text(
                                  teacherId,
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
                          hintText: 'e.g. Teacher@123',
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
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'The faculty password will be reset to this temporary password. Upon their next login, they will be required to change their password.',
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
                            userId: teacherId,
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
                                            ? 'Credentials email dispatched to $teacherEmail via Gmail SMTP! Password: $newPass'
                                            : 'Password updated to "$newPass", but email delivery failed: ${result.message}',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: result.success ? AppTheme.success : AppTheme.warning,
                                duration: Duration(seconds: result.success ? 4 : 8),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
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

  // ── Confirm Archive Teacher Dialog ──────────────────────────
  void _confirmArchiveTeacher(BuildContext context, Map<String, dynamic> teacher) {
    final rootContext = context;
    final teacherId = teacher['id'] as String? ?? '';
    final teacherEmail = teacher['email'] as String? ?? '';
    final rawName = teacher['full_name'] as String? ?? teacher['name'] as String? ?? '';
    final teacherName = rawName.trim().isNotEmpty
        ? rawName.trim()
        : (teacherEmail.isNotEmpty ? teacherEmail : (teacherId.isNotEmpty ? teacherId : 'Faculty Member'));
    final assignedCount =
        teacher['assigned_subjects_count'] as int? ?? (teacher['assigned_subjects'] as List? ?? []).length;

    showDialog(
      context: rootContext,
      builder: (dialogCtx) {
        bool isProcessing = false;
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
                    'Deactivate Faculty Account',
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
                      'Are you sure you want to deactivate this faculty member\'s account?',
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
                              Text('Faculty Member:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              Flexible(
                                child: Text(
                                  teacherName,
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
                              Text('Teacher ID:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              Text(
                                teacherId,
                                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (teacherEmail.isNotEmpty) ...[
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Email:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                Flexible(
                                  child: Text(
                                    teacherEmail,
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
                              Text('Assigned Courses:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              Text(
                                '$assignedCount course(s)',
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
                              'The teacher will be hidden from active faculty lists and will not appear in course assignments. Their teaching history and credentials are preserved and can be restored anytime.',
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
                  onPressed: isProcessing ? null : () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setDialogState(() => isProcessing = true);
                          try {
                            await ref
                                .read(adminTeachersProvider.notifier)
                                .archiveTeacher(teacherId)
                                .timeout(const Duration(seconds: 8));
                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                            }
                            if (rootContext.mounted) {
                              AiraActionToast.showDeactivated(
                                rootContext,
                                title: 'Faculty Account Deactivated',
                                message: 'Faculty member "$teacherName" ($teacherId) was deactivated.',
                                duration: const Duration(seconds: 6),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isProcessing = false);
                            if (rootContext.mounted) {
                              AiraActionToast.showError(
                                rootContext,
                                title: 'Failed to deactivate faculty member',
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
                    minimumSize: const Size(0, 40),
                  ),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.person_off_outlined, size: 18),
                  label: Text(isProcessing ? 'Deactivating...' : 'Deactivate Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Confirm Bulk Archive Dialog ────────────────────────────
  void _confirmBulkArchive(BuildContext context, List<String> teacherIds) {
    if (teacherIds.isEmpty) return;
    final rootContext = context;

    showDialog(
      context: rootContext,
      builder: (dialogCtx) {
        bool isProcessing = false;
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
                    'Deactivate ${teacherIds.length} Faculty Members?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Text(
                  'Are you sure you want to deactivate ${teacherIds.length} faculty accounts? They can be reactivated at any time.',
                  style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setDialogState(() => isProcessing = true);
                          try {
                            await ref.read(adminTeachersProvider.notifier).bulkArchiveTeachers(teacherIds);
                            setState(() => _selectedTeacherIds.clear());
                            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                            if (rootContext.mounted) {
                              AiraActionToast.showDeactivated(
                                rootContext,
                                title: 'Faculty Accounts Deactivated',
                                message: '${teacherIds.length} faculty accounts were deactivated.',
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isProcessing = false);
                            if (rootContext.mounted) {
                              AiraActionToast.showError(
                                rootContext,
                                title: 'Bulk Deactivation Failed',
                                message: 'An error occurred while deactivating faculty: $e',
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.person_off_outlined, size: 16),
                  label: Text(isProcessing ? 'Deactivating...' : 'Deactivate All Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Confirm Permanent Delete Teacher Dialog ────────────────
  void _confirmPermanentDeleteTeacher(BuildContext context, Map<String, dynamic> teacher) {
    final rootContext = context;
    final teacherId = teacher['id'] as String? ?? '';
    final teacherEmail = teacher['email'] as String? ?? '';
    final rawName = teacher['full_name'] as String? ?? teacher['name'] as String? ?? '';
    final teacherName = rawName.trim().isNotEmpty
        ? rawName.trim()
        : (teacherEmail.isNotEmpty ? teacherEmail : (teacherId.isNotEmpty ? teacherId : 'Faculty Member'));

    showDialog(
      context: rootContext,
      builder: (dialogCtx) {
        bool isDeleting = false;
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
                    'Permanently Delete Faculty',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
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
                      'Are you sure you want to permanently delete this faculty account? All assigned courses will be safely unassigned.',
                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
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
                              Text('Faculty Member:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              Flexible(
                                child: Text(
                                  teacherName,
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
                              Text('Teacher ID:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              Text(
                                teacherId,
                                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
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
                        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, size: 18, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This action CANNOT be undone. The faculty login credentials and records will be completely removed from the database.',
                              style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w500, height: 1.35),
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
                                .read(adminArchivedTeachersProvider.notifier)
                                .permanentDeleteTeacher(teacherId)
                                .timeout(const Duration(seconds: 8));
                            setState(() => _selectedTeacherIds.remove(teacherId));
                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                            }
                            if (rootContext.mounted) {
                              AiraActionToast.showDeleted(
                                rootContext,
                                title: 'Faculty Account Deleted',
                                message: 'Faculty member "$teacherName" ($teacherId) was permanently purged.',
                                duration: const Duration(seconds: 8),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            if (rootContext.mounted) {
                              AiraActionToast.showError(
                                rootContext,
                                title: 'Failed to delete faculty member',
                                message: 'An unexpected error occurred while deleting "$teacherName": $e',
                                duration: const Duration(seconds: 8),
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
                  label: Text(isDeleting ? 'Deleting...' : 'Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Confirm Bulk Restore Dialog ────────────────────────────
  void _confirmBulkRestore(BuildContext context, List<String> teacherIds) {
    if (teacherIds.isEmpty) return;
    final rootContext = context;

    showDialog(
      context: rootContext,
      builder: (dialogCtx) {
        bool isProcessing = false;
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
                    'Restore ${teacherIds.length} Faculty Members?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Text(
                  'Are you sure you want to restore ${teacherIds.length} faculty accounts back to the active directory?',
                  style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setDialogState(() => isProcessing = true);
                          try {
                            await ref.read(adminArchivedTeachersProvider.notifier).bulkRestoreTeachers(teacherIds);
                            setState(() => _selectedTeacherIds.clear());
                            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                            if (rootContext.mounted) {
                              AiraActionToast.showRestored(
                                rootContext,
                                title: 'Faculty Members Restored',
                                message: '${teacherIds.length} faculty members restored to active directory.',
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isProcessing = false);
                            if (rootContext.mounted) {
                              AiraActionToast.showError(
                                rootContext,
                                title: 'Bulk Restore Failed',
                                message: 'An error occurred while restoring faculty: $e',
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: Text(isProcessing ? 'Restoring...' : 'Restore All Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Confirm Bulk Permanent Delete Dialog ───────────────────
  void _confirmBulkPermanentDelete(BuildContext context, List<String> teacherIds) {
    if (teacherIds.isEmpty) return;
    final rootContext = context;

    showDialog(
      context: rootContext,
      builder: (dialogCtx) {
        bool isDeleting = false;
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
                    'Permanently Delete ${teacherIds.length} Faculty Members?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Text(
                  'DANGER: This action cannot be undone. Are you sure you want to permanently purge ${teacherIds.length} selected faculty accounts? All assigned courses will be unassigned safely.',
                  style: TextStyle(fontSize: 13.5, color: AppTheme.error, fontWeight: FontWeight.w600, height: 1.4),
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
                            await ref.read(adminArchivedTeachersProvider.notifier).bulkPermanentDeleteTeachers(teacherIds);
                            setState(() => _selectedTeacherIds.clear());
                            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                            if (rootContext.mounted) {
                              AiraActionToast.showDeleted(
                                rootContext,
                                title: 'Faculty Accounts Purged',
                                message: '${teacherIds.length} faculty accounts were permanently deleted.',
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            if (rootContext.mounted) {
                              AiraActionToast.showError(
                                rootContext,
                                title: 'Bulk Purge Failed',
                                message: 'An error occurred while deleting faculty: $e',
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: Text(isDeleting ? 'Deleting...' : 'Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
