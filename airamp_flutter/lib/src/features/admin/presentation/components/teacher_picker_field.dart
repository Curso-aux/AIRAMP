import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/admin_repository.dart';

/// Form field and debounced searchable modal/dialog for assigning a faculty/teacher to a subject.
/// Supports search by full name, email, and username with debounced input, no lag, and an empty-state.
class TeacherPickerField extends ConsumerWidget {
  final String? selectedTeacherId;
  final String? selectedTeacherName;
  final ValueChanged<Map<String, dynamic>?> onTeacherSelected;

  const TeacherPickerField({
    super.key,
    required this.selectedTeacherId,
    required this.selectedTeacherName,
    required this.onTeacherSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachersAsync = ref.watch(teachersListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Assigned Faculty / Teacher',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (selectedTeacherId != null)
              InkWell(
                onTap: () => onTeacherSelected(null),
                child: Text(
                  'Clear Assignment',
                  style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            teachersAsync.whenData((teachers) {
              _openTeacherSearchPicker(context, teachers);
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selectedTeacherId != null ? AppTheme.primary.withValues(alpha: 0.5) : AppTheme.border,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selectedTeacherId != null
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : AppTheme.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    selectedTeacherId != null ? Icons.person_rounded : Icons.person_add_alt_1_outlined,
                    color: selectedTeacherId != null ? AppTheme.primary : AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedTeacherName ?? (selectedTeacherId != null ? 'Teacher ID: $selectedTeacherId' : 'Unassigned / To Be Designated'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selectedTeacherId != null ? FontWeight.bold : FontWeight.normal,
                          color: selectedTeacherId != null ? AppTheme.text : AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        selectedTeacherId != null ? 'Click to change instructor' : 'Tap to search & assign teacher',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openTeacherSearchPicker(BuildContext context, List<Map<String, dynamic>> teachers) {
    final isDesktop = MediaQuery.of(context).size.width >= 650;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: _TeacherSearchModal(
              teachers: teachers,
              currentSelectedId: selectedTeacherId,
              onSelect: (teacher) {
                onTeacherSelected(teacher);
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: _TeacherSearchModal(
            teachers: teachers,
            currentSelectedId: selectedTeacherId,
            onSelect: (teacher) {
              onTeacherSelected(teacher);
              Navigator.pop(ctx);
            },
          ),
        ),
      );
    }
  }
}

class _TeacherSearchModal extends StatefulWidget {
  final List<Map<String, dynamic>> teachers;
  final String? currentSelectedId;
  final ValueChanged<Map<String, dynamic>?> onSelect;

  const _TeacherSearchModal({
    required this.teachers,
    required this.currentSelectedId,
    required this.onSelect,
  });

  @override
  State<_TeacherSearchModal> createState() => _TeacherSearchModalState();
}

class _TeacherSearchModalState extends State<_TeacherSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _filteredTeachers = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredTeachers = List.from(widget.teachers);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    setState(() => _isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      final q = query.trim().toLowerCase();
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        if (q.isEmpty) {
          _filteredTeachers = List.from(widget.teachers);
        } else {
          _filteredTeachers = widget.teachers.where((t) {
            final name = (t['full_name'] as String? ?? '').toLowerCase();
            final email = (t['email'] as String? ?? '').toLowerCase();
            final username = (t['username'] as String? ?? '').toLowerCase();
            return name.contains(q) || email.contains(q) || username.contains(q);
          }).toList();
        }
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Modal Header
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 16, top: 18, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.assignment_ind_rounded, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Assign Faculty / Teacher',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        // Debounced Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by faculty name, email, or username...',
              hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.primary),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _clearSearch,
                    )
                  : (_isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null),
              filled: true,
              fillColor: AppTheme.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Teacher List or Empty State
        Expanded(
          child: _filteredTeachers.isEmpty
              ? _buildEmptyState(query)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredTeachers.length + 1, // +1 for Unassigned option
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isUnassignedSelected = widget.currentSelectedId == null;
                      return _buildUnassignedTile(isUnassignedSelected);
                    }

                    final teacher = _filteredTeachers[index - 1];
                    final id = teacher['id']?.toString() ?? '';
                    final isSelected = widget.currentSelectedId == id;
                    final name = teacher['full_name'] as String? ?? 'Teacher';
                    final email = teacher['email'] as String? ?? '';
                    final assignedCount = (teacher['assigned_subjects_count'] as int?) ??
                        (teacher['assigned_subjects'] as List? ?? []).length;

                    return _buildTeacherTile(
                      teacher: teacher,
                      id: id,
                      name: name,
                      email: email,
                      assignedCount: assignedCount,
                      isSelected: isSelected,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUnassignedTile(bool isSelected) {
    return InkWell(
      onTap: () => widget.onSelect(null),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.background,
              child: Icon(Icons.person_off_outlined, size: 18, color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unassigned / To Be Designated',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? AppTheme.primary : AppTheme.text,
                    ),
                  ),
                  Text(
                    'Leave course without an assigned instructor for now',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherTile({
    required Map<String, dynamic> teacher,
    required String id,
    required String name,
    required String email,
    required int assignedCount,
    required bool isSelected,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';

    return InkWell(
      onTap: () => widget.onSelect(teacher),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isSelected ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.15),
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primary : AppTheme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (email.isNotEmpty) ...[
                        Icon(Icons.mail_outline, size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            email,
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          '$assignedCount courses',
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_search_outlined, size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              'No teacher found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
            const SizedBox(height: 6),
            Text(
              query.isNotEmpty
                  ? 'No faculty members match "$query". Check the spelling or search by DepEd email.'
                  : 'No faculty members are currently registered in this school.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Clear search'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
