import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/theme_provider.dart';
import '../../../../../core/utils/file_download_helper.dart';
import '../../../data/admin_repository.dart';
import 'bulk_import_modal.dart';

enum CommandCategory {
  navigation('Pages & Screens', Icons.explore_outlined),
  actions('Quick Actions', Icons.bolt_outlined),
  students('Students', Icons.school_outlined),
  teachers('Faculty & Staff', Icons.badge_outlined),
  sections('Class Sections', Icons.groups_outlined);

  final String label;
  final IconData icon;
  const CommandCategory(this.label, this.icon);
}

class CommandPaletteItem {
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final CommandCategory category;
  final VoidCallback onSelect;

  const CommandPaletteItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.category,
    required this.onSelect,
  });
}

class AdminCommandPalette extends ConsumerStatefulWidget {
  final void Function(int branchIndex) onSelectTab;

  const AdminCommandPalette({
    super.key,
    required this.onSelectTab,
  });

  static Future<void> show(BuildContext context, {required void Function(int branchIndex) onSelectTab}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      barrierDismissible: true,
      builder: (context) => AdminCommandPalette(onSelectTab: onSelectTab),
    );
  }

  @override
  ConsumerState<AdminCommandPalette> createState() => _AdminCommandPaletteState();
}

class _AdminCommandPaletteState extends ConsumerState<AdminCommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _safeClose() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  List<CommandPaletteItem> _buildAllItems() {
    final students = ref.watch(adminStudentsProvider);
    final teachers = ref.watch(adminTeachersProvider);
    final sections = ref.watch(sectionsProvider);

    final List<CommandPaletteItem> items = [];

    // 1. Navigation Pages
    final pages = [
      (0, 'Analytics & Insights', 'Dashboard overview and metrics', Icons.insights),
      (1, 'Student Directory', 'Classroom sections and student records', Icons.school),
      (2, 'Faculty & Staff', 'Teacher profiles and assigned subjects', Icons.badge),
      (3, 'Subject Offerings', 'Curriculum, outcomes, and topics', Icons.menu_book),
      (4, 'Enrollment Keys', 'Active codes organized by year level', Icons.vpn_key),
      (5, 'Announcements', 'Broadcast alerts and school bulletins', Icons.campaign),
      (6, 'Quiz Scores & Results', 'Student performance and attempts', Icons.assignment_turned_in),
      (7, 'Class Sections', 'Room assignments and section arrangements', Icons.groups),
    ];

    for (final p in pages) {
      items.add(CommandPaletteItem(
        id: 'nav_${p.$1}',
        title: p.$2,
        subtitle: p.$3,
        icon: p.$4,
        category: CommandCategory.navigation,
        onSelect: () {
          _safeClose();
          widget.onSelectTab(p.$1);
        },
      ));
    }

    // 2. Quick Actions
    items.add(CommandPaletteItem(
      id: 'action_import_csv',
      title: 'Bulk Import Students & Faculty (CSV)',
      subtitle: 'Upload CSV or paste student list',
      icon: Icons.upload_file_rounded,
      category: CommandCategory.actions,
      onSelect: () {
        _safeClose();
        BulkImportModal.show(context);
      },
    ));

    items.add(CommandPaletteItem(
      id: 'action_export_csv',
      title: 'Export Student Roster (CSV)',
      subtitle: 'Download complete student list as CSV',
      icon: Icons.download_rounded,
      category: CommandCategory.actions,
      onSelect: () {
        _safeClose();
        final csv = ref.read(adminStudentsProvider.notifier).exportStudentsCsv();
        final now = DateTime.now();
        final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        downloadCsvFile(csv, 'students_roster_$dateStr.csv');
      },
    ));

    items.add(CommandPaletteItem(
      id: 'action_toggle_theme',
      title: 'Toggle Dark / Light Mode',
      subtitle: AppTheme.isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
      icon: AppTheme.isDark ? Icons.light_mode : Icons.dark_mode,
      category: CommandCategory.actions,
      onSelect: () {
        _safeClose();
        ref.read(themeProvider.notifier).toggleTheme();
      },
    ));

    items.add(CommandPaletteItem(
      id: 'action_create_section',
      title: 'Create New Class Section',
      subtitle: 'Add section with auto-generated enrollment key',
      icon: Icons.add_circle_outline,
      category: CommandCategory.actions,
      onSelect: () {
        _safeClose();
        widget.onSelectTab(7); // Class Sections tab
      },
    ));

    // 3. Students (up to 30 items)
    for (final s in students.take(30)) {
      final name = s['full_name'] as String? ?? 'Student';
      final email = s['email'] as String? ?? '';
      final sec = s['section'] as String? ?? 'Unassigned';
      final grade = s['grade'] as String? ?? '';

      items.add(CommandPaletteItem(
        id: 'student_${s['id']}',
        title: name,
        subtitle: '$email • $grade $sec',
        icon: Icons.person_outline,
        category: CommandCategory.students,
        onSelect: () {
          _safeClose();
          widget.onSelectTab(1); // Jump to Student Directory
        },
      ));
    }

    // 4. Faculty & Teachers
    for (final t in teachers) {
      final name = t['full_name'] as String? ?? 'Teacher';
      final email = t['email'] as String? ?? '';

      items.add(CommandPaletteItem(
        id: 'teacher_${t['id']}',
        title: name,
        subtitle: email,
        icon: Icons.badge_outlined,
        category: CommandCategory.teachers,
        onSelect: () {
          _safeClose();
          widget.onSelectTab(2); // Jump to Faculty & Staff
        },
      ));
    }

    // 5. Class Sections
    for (final sec in sections) {
      final name = sec['name'] as String? ?? 'Section';
      final grade = sec['grade'] as String? ?? '';
      final room = sec['room'] as String? ?? '';
      final count = sec['student_count']?.toString() ?? '0';

      items.add(CommandPaletteItem(
        id: 'sec_${sec['id']}',
        title: name,
        subtitle: '$grade • Room $room • $count Students',
        icon: Icons.groups_outlined,
        category: CommandCategory.sections,
        onSelect: () {
          _safeClose();
          widget.onSelectTab(7); // Jump to Sections
        },
      ));
    }

    return items;
  }

  List<CommandPaletteItem> _filterItems(List<CommandPaletteItem> allItems, String query) {
    if (query.trim().isEmpty) {
      // By default show all navigation pages and quick actions
      return allItems.where((item) =>
          item.category == CommandCategory.navigation ||
          item.category == CommandCategory.actions
      ).toList();
    }

    final q = query.trim().toLowerCase();
    return allItems.where((item) {
      final titleMatch = item.title.toLowerCase().contains(q);
      final subtitleMatch = item.subtitle?.toLowerCase().contains(q) ?? false;
      final categoryMatch = item.category.label.toLowerCase().contains(q);
      return titleMatch || subtitleMatch || categoryMatch;
    }).toList();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final filtered = _filterItems(_buildAllItems(), _searchController.text);
    if (filtered.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % filtered.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + filtered.length) % filtered.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedIndex >= 0 && _selectedIndex < filtered.length) {
        filtered[_selectedIndex].onSelect();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _safeClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _buildAllItems();
    final filtered = _filterItems(allItems, _searchController.text);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        alignment: Alignment.topCenter,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 640,
            constraints: const BoxConstraints(maxHeight: 520),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Search Input Box
                _buildSearchInput(),

                const Divider(height: 1, thickness: 1),

                // Results list
                Flexible(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final isSelected = index == _selectedIndex;
                            return _buildItemRow(item, isSelected, index);
                          },
                        ),
                ),

                const Divider(height: 1, thickness: 1),

                // Footer Keyboard Hints
                _buildFooterHints(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 22, color: AppTheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.text,
              ),
              decoration: InputDecoration(
                hintText: 'Search pages, students, teachers, sections, or actions...',
                hintStyle: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'ESC',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(CommandPaletteItem item, bool isSelected, int index) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _selectedIndex = index);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => item.onSelect(),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary.withValues(alpha: 0.3) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  size: 16,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppTheme.primary : AppTheme.text,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.category.label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(Icons.keyboard_return, size: 14, color: AppTheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(
            'No matching commands or records found',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),
          const SizedBox(height: 4),
          Text(
            'Try searching for student names, faculty, sections, or "CSV"',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterHints() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Row(
        children: [
          _buildShortcutBadge('↑↓', 'Navigate'),
          const SizedBox(width: 14),
          _buildShortcutBadge('↵', 'Select'),
          const SizedBox(width: 14),
          _buildShortcutBadge('ESC', 'Close'),
          const Spacer(),
          Text(
            'AIRAMP Quick Command',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutBadge(String keyText, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            keyText,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
