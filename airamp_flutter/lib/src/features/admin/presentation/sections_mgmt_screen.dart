import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../data/admin_repository.dart';
import 'student_profile_screen.dart';

class SectionsMgmtScreen extends ConsumerStatefulWidget {
  const SectionsMgmtScreen({super.key});

  @override
  ConsumerState<SectionsMgmtScreen> createState() => _SectionsMgmtScreenState();
}

class _SectionsMgmtScreenState extends ConsumerState<SectionsMgmtScreen> {
  bool _showForm = false;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _roomController = TextEditingController();
  String _selectedGrade = '';

  final List<String> _grades = [
    'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10',
    'Grade 11', 'Grade 12',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _showConfirmation({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(title, style: TextStyle(color: AppTheme.text)),
        content: Text(content, style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onConfirm();
    }
  }

  void _showEditDialog(Map<String, dynamic> section) {
    final editNameController = TextEditingController(text: section['name']);
    final editDescController = TextEditingController(text: section['description'] ?? '');
    final editRoomController = TextEditingController(text: section['room'] ?? '');
    String editSelectedGrade = section['grade'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text('Edit Section', style: TextStyle(color: AppTheme.text)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: editNameController,
                      style: TextStyle(color: AppTheme.text),
                      decoration: const InputDecoration(
                        labelText: 'Section Name',
                        hintText: 'Section Name (e.g., Grade 12 - ICT A)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editRoomController,
                      style: TextStyle(color: AppTheme.text),
                      decoration: const InputDecoration(
                        labelText: 'Room / Building',
                        hintText: 'Room (e.g., Room 304 - Science Bldg)',
                        prefixIcon: Icon(Icons.meeting_room_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editDescController,
                      style: TextStyle(color: AppTheme.text),
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'Description (optional)',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Assign Grade Level',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _grades.map((grade) {
                        final isSelected = editSelectedGrade == grade;
                        return ChoiceChip(
                          label: Text(grade),
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() => editSelectedGrade = selected ? grade : '');
                          },
                          selectedColor: Theme.of(context).colorScheme.primary,
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (editNameController.text.isNotEmpty) {
                      _showConfirmation(
                        title: 'Save Changes',
                        content: 'Are you sure you want to update this section?',
                        onConfirm: () async {
                          final sectionId = section['id'];
                          final nav = Navigator.of(context);
                          if (sectionId is int) {
                            await ref.read(sectionsProvider.notifier).updateSection(
                              sectionId,
                              {
                                'name': editNameController.text.trim(),
                                'description': editDescController.text.trim(),
                                'grade': editSelectedGrade.isNotEmpty ? editSelectedGrade : (section['grade'] ?? 'Grade 11'),
                                'room': editRoomController.text.trim(),
                              },
                            );
                          }
                          nav.pop();
                        },
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final sections = ref.watch(sectionsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Sections',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sections.length} active sections',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                  FloatingActionButton.small(
                    onPressed: () {
                      setState(() => _showForm = !_showForm);
                    },
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(_showForm ? Icons.close : Icons.add, color: Colors.black),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Add New Section Form
              if (_showForm) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Section',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        style: TextStyle(color: AppTheme.text),
                        decoration: const InputDecoration(
                          hintText: 'Section Name (e.g., Grade 12 - ICT A)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _roomController,
                        style: TextStyle(color: AppTheme.text),
                        decoration: const InputDecoration(
                          hintText: 'Room / Building (e.g., Room 304, Science Bldg)',
                          prefixIcon: Icon(Icons.meeting_room_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descController,
                        style: TextStyle(color: AppTheme.text),
                        decoration: const InputDecoration(
                          hintText: 'Description (optional)',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Assign Grade Level',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _grades.map((grade) {
                          final isSelected = _selectedGrade == grade;
                          return ChoiceChip(
                            label: Text(grade),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() => _selectedGrade = selected ? grade : '');
                            },
                            selectedColor: Theme.of(context).colorScheme.primary,
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _showForm = false;
                                  _nameController.clear();
                                  _descController.clear();
                                  _roomController.clear();
                                  _selectedGrade = '';
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textSecondary,
                                side: BorderSide(color: AppTheme.border),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_nameController.text.trim().isNotEmpty) {
                                  await ref.read(sectionsProvider.notifier).addSection({
                                    'name': _nameController.text.trim(),
                                    'description': _descController.text.trim(),
                                    'grade': _selectedGrade.isNotEmpty ? _selectedGrade : 'Grade 11',
                                    'room': _roomController.text.trim(),
                                    'student_count': 0,
                                    'created_at': DateTime.now().toIso8601String(),
                                  });
                                  setState(() {
                                    _showForm = false;
                                    _nameController.clear();
                                    _descController.clear();
                                    _roomController.clear();
                                    _selectedGrade = '';
                                  });
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Empty state
              if (sections.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.groups_outlined, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text('No class sections created yet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Click "+" above to add your first classroom section with room assignment.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                ),

              // Section Cards
              ...sections.map((section) => _SectionCard(
                section: section,
                onEdit: () => _showEditDialog(section),
                onDelete: () {
                  _showConfirmation(
                    title: 'Delete Section',
                    content: 'Are you sure you want to delete "${section['name']}"?',
                    onConfirm: () async {
                      final sectionId = section['id'];
                      if (sectionId is int) {
                        await ref.read(sectionsProvider.notifier).deleteSection(sectionId);
                      }
                    },
                  );
                },
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> section;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SectionCard({required this.section, required this.onEdit, required this.onDelete});

  @override
  ConsumerState<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends ConsumerState<_SectionCard> {
  bool _isExpanded = false;
  int _selectedTab = 0; // 0 for Students, 1 for Progress Chart
  List<Map<String, dynamic>> _sectionStudents = [];
  bool _isLoadingStudents = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final allStudents = await DatabaseHelper().getAdminStudentsList();
      final sectionName = widget.section['name']?.toString().toLowerCase().trim() ?? '';
      final matched = allStudents.where((s) {
        final sSection = s['section']?.toString().toLowerCase().trim() ?? '';
        return sSection.isNotEmpty && (sSection == sectionName || sectionName.contains(sSection));
      }).toList();
      if (mounted) {
        setState(() {
          _sectionStudents = matched;
          _isLoadingStudents = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.section['room']?.toString() ?? '';
    final studentCount = _sectionStudents.isNotEmpty
        ? _sectionStudents.length
        : (widget.section['student_count'] ?? widget.section['studentCount'] ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.section['name'] ?? '',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    if (widget.section['description'] != null && widget.section['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.section['description'],
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.school_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              widget.section['grade'] ?? 'No grade',
                              style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (room.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.meeting_room_outlined, size: 14, color: AppTheme.accent),
                              const SizedBox(width: 4),
                              Text(
                                room,
                                style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, size: 14, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '$studentCount students',
                              style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: widget.onEdit,
                    icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primarySoft,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.errorSoft,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 20),
                  ),
                ],
              ),
            ],
          ),
          
          if (_isExpanded) ...[
            const SizedBox(height: 16),
            // Tabs
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 16, color: _selectedTab == 0 ? Colors.black : AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text('Students', style: TextStyle(
                              color: _selectedTab == 0 ? Colors.black : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bar_chart, size: 16, color: _selectedTab == 1 ? Colors.black : AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text('Progress Chart', style: TextStyle(
                              color: _selectedTab == 1 ? Colors.black : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            if (_selectedTab == 0) _buildStudentsList() else _buildProgressChart(),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    if (_isLoadingStudents) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_sectionStudents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('No students currently assigned to this section.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      );
    }

    return Column(
      children: _sectionStudents.map((student) {
        final name = student['full_name'] ?? student['name'] ?? 'Student';
        final initials = name.toString().isNotEmpty ? name.toString()[0].toUpperCase() : '?';
        return Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                  child: Text(initials, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('${student['email'] ?? ''} · ${student['grade'] ?? widget.section['grade'] ?? ''}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentProfileScreen(
                          student: student,
                          sectionName: widget.section['name'],
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.visibility_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.background, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ],
            ),
            const Divider(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildProgressChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Section Cohort Mastery', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Live Stats', style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Assigned Room: ${widget.section['room'] ?? 'Not specified'}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text('Grade Level: ${widget.section['grade'] ?? 'Not specified'}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0.75,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text('75% curriculum completion target reached', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}
