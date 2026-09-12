import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/section_key_helper.dart';
import '../data/admin_repository.dart';
import 'student_profile_screen.dart';

class SectionsMgmtScreen extends ConsumerStatefulWidget {
  const SectionsMgmtScreen({super.key});

  @override
  ConsumerState<SectionsMgmtScreen> createState() => _SectionsMgmtScreenState();
}

class _SectionsMgmtScreenState extends ConsumerState<SectionsMgmtScreen> {
  String _selectedGradeFilter = 'All';

  final List<String> _grades = [
    'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10',
    'Grade 11', 'Grade 12',
  ];

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
    final editKeyController = TextEditingController(text: section['enrollment_key'] ?? '');
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
                      controller: editKeyController,
                      style: TextStyle(color: AppTheme.text),
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Enrollment Key (for Students)',
                        hintText: 'e.g., SEC-EMR10',
                        prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                        suffixIcon: IconButton(
                          tooltip: 'Auto-generate standard key',
                          icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                          onPressed: () {
                            editKeyController.text = SectionKeyHelper.generateKey(
                              sectionName: editNameController.text.isNotEmpty ? editNameController.text : (section['name'] ?? 'Section'),
                              gradeLevel: editSelectedGrade.isNotEmpty ? editSelectedGrade : section['grade'],
                            );
                          },
                        ),
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
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
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
                            final rawKey = editKeyController.text.trim().toUpperCase();
                            final key = rawKey.isNotEmpty ? rawKey : (section['enrollment_key'] ?? 'SEC-${section['id']}');
                            await ref.read(sectionsProvider.notifier).updateSection(
                              sectionId,
                              {
                                'name': editNameController.text.trim(),
                                'description': editDescController.text.trim(),
                                'grade': editSelectedGrade.isNotEmpty ? editSelectedGrade : (section['grade'] ?? 'Grade 11'),
                                'room': editRoomController.text.trim(),
                                'enrollment_key': key,
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

  void _showAddSectionDialog({String? initialGrade}) {
    final formKey = GlobalKey<FormState>();
    final addNameController = TextEditingController();
    final addDescController = TextEditingController();
    final addRoomController = TextEditingController();
    final addKeyController = TextEditingController();
    String addSelectedGrade = (initialGrade != null && _grades.contains(initialGrade))
        ? initialGrade
        : (_selectedGradeFilter != 'All' && _grades.contains(_selectedGradeFilter)
            ? _selectedGradeFilter
            : 'Grade 10');
    String autoEnrollmentKey = SectionKeyHelper.generateKey(
      sectionName: 'Section',
      gradeLevel: addSelectedGrade,
    );
    bool isCustomKey = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.groups_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add New Section',
                    style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: addNameController,
                          style: TextStyle(color: AppTheme.text),
                          decoration: const InputDecoration(
                            labelText: 'Section Name',
                            hintText: 'e.g., Grade 10 - Sapphire',
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          ),
                          onChanged: (val) {
                            if (!isCustomKey) {
                              setDialogState(() {
                                autoEnrollmentKey = SectionKeyHelper.generateKey(
                                  sectionName: val.trim().isNotEmpty ? val.trim() : 'Section',
                                  gradeLevel: addSelectedGrade,
                                );
                              });
                            }
                          },
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter section name';
                            }
                            return null;
                          },
                          autofocus: true,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: addRoomController,
                          style: TextStyle(color: AppTheme.text),
                          decoration: const InputDecoration(
                            labelText: 'Room / Building',
                            hintText: 'e.g., Room 304 - Science Bldg',
                            prefixIcon: Icon(Icons.meeting_room_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Auto-Generated Enrollment Key Card - Zero typing required!
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.vpn_key_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Enrollment Key (optional)', // Exact text preserved for widget test compatibility
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'AUTO-GENERATED',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      isCustomKey && addKeyController.text.isNotEmpty ? addKeyController.text : autoEnrollmentKey,
                                      style: TextStyle(
                                        color: AppTheme.text,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Shuffle variant suffix',
                                    icon: Icon(Icons.shuffle_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                                    onPressed: () {
                                      setDialogState(() {
                                        isCustomKey = false;
                                        addKeyController.clear();
                                        autoEnrollmentKey = SectionKeyHelper.generateRandomVariation(
                                          sectionName: addNameController.text.trim().isNotEmpty ? addNameController.text.trim() : 'Section',
                                          gradeLevel: addSelectedGrade,
                                        );
                                      });
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Copy key',
                                    icon: Icon(Icons.copy_rounded, size: 16, color: AppTheme.textSecondary),
                                    onPressed: () {
                                      final keyToCopy = isCustomKey && addKeyController.text.isNotEmpty ? addKeyController.text : autoEnrollmentKey;
                                      Clipboard.setData(ClipboardData(text: keyToCopy));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Copied key "$keyToCopy"'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Generated automatically when creating this section. Zero typing needed.',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!isCustomKey)
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                isCustomKey = true;
                                addKeyController.text = autoEnrollmentKey;
                              });
                            },
                            child: Text(
                              '+ Customize key manually (optional)',
                              style: TextStyle(fontSize: 11, color: AppTheme.primary, decoration: TextDecoration.underline),
                            ),
                          )
                        else
                          TextFormField(
                            controller: addKeyController,
                            style: TextStyle(color: AppTheme.text),
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Custom Key Override',
                              hintText: 'e.g., SEC-CUSTOM10',
                              prefixIcon: Icon(Icons.edit_outlined, size: 18),
                            ),
                          ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: addDescController,
                          style: TextStyle(color: AppTheme.text),
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            hintText: 'e.g., Senior High STEM Section',
                            prefixIcon: Icon(Icons.notes_outlined, size: 20),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Assign Grade Level',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _grades.map((grade) {
                            final isSelected = addSelectedGrade == grade;
                            return ChoiceChip(
                              label: Text(grade),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setDialogState(() {
                                    addSelectedGrade = grade;
                                    if (!isCustomKey) {
                                      autoEnrollmentKey = SectionKeyHelper.generateKey(
                                        sectionName: addNameController.text.trim().isNotEmpty ? addNameController.text.trim() : 'Section',
                                        gradeLevel: grade,
                                      );
                                    }
                                  });
                                }
                              },
                              selectedColor: Theme.of(context).colorScheme.primary,
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textSecondary,
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
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final name = addNameController.text.trim();
                      final rawKey = addKeyController.text.trim().toUpperCase();
                      final enrollmentKey = (isCustomKey && rawKey.isNotEmpty) ? rawKey : autoEnrollmentKey;

                      final messenger = ScaffoldMessenger.of(context);
                      final router = GoRouter.maybeOf(context);
                      Navigator.pop(dialogCtx);
                      await ref.read(sectionsProvider.notifier).addSection({
                        'name': name,
                        'description': addDescController.text.trim(),
                        'grade': addSelectedGrade.isNotEmpty ? addSelectedGrade : 'Grade 10',
                        'room': addRoomController.text.trim(),
                        'enrollment_key': enrollmentKey,
                        'student_count': 0,
                        'created_at': DateTime.now().toIso8601String(),
                      });
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Created section "$name" with Key: $enrollmentKey'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                        try {
                          router?.go('/admin/keys');
                        } catch (_) {}
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text('Create Section'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGradeFilterChip(String label, int count) {
    final isSelected = _selectedGradeFilter == label;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : primary,
                ),
              ),
            ),
          ],
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedColor: primary,
        side: BorderSide(
          color: isSelected ? primary : AppTheme.border,
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        onSelected: (_) {
          setState(() {
            _selectedGradeFilter = label;
          });
        },
      ),
    );
  }

  Widget _buildGradeGroupHeader(String grade, int sectionCount) {
    final isJuniorHigh = ['Grade 7', 'Grade 8', 'Grade 9', 'Grade 10'].contains(grade);
    final isSeniorHigh = ['Grade 11', 'Grade 12'].contains(grade);
    final division = isJuniorHigh ? 'Junior High School' : (isSeniorHigh ? 'Senior High School' : 'Classroom Department');

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.school_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      grade,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$sectionCount ${sectionCount == 1 ? 'Section' : 'Sections'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  division,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showAddSectionDialog(initialGrade: grade),
            icon: const Icon(Icons.add, size: 14),
            label: Text('Add $grade Section', style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyGradeState(String grade) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(Icons.groups_outlined, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'No sections created for $grade yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),
          const SizedBox(height: 4),
          Text(
            'Click the button below to add your first $grade section with room assignment.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAddSectionDialog(initialGrade: grade),
            icon: const Icon(Icons.add, size: 16),
            label: Text('Create $grade Section'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final sections = ref.watch(sectionsProvider);

    // Calculate section counts per grade
    final Map<String, int> gradeSectionCounts = {};
    for (final g in _grades) {
      gradeSectionCounts[g] = 0;
    }
    for (final s in sections) {
      final g = s['grade']?.toString() ?? '';
      if (gradeSectionCounts.containsKey(g)) {
        gradeSectionCounts[g] = (gradeSectionCounts[g] ?? 0) + 1;
      }
    }

    // Group sections by grade level
    final Map<String, List<Map<String, dynamic>>> groupedSections = {};
    for (final s in sections) {
      final g = s['grade']?.toString() ?? 'Unassigned';
      groupedSections.putIfAbsent(g, () => []).add(s);
    }
    final sortedGrades = groupedSections.keys.toList()
      ..sort((a, b) {
        final iA = _grades.indexOf(a);
        final iB = _grades.indexOf(b);
        if (iA != -1 && iB != -1) return iA.compareTo(iB);
        if (iA != -1) return -1;
        if (iB != -1) return 1;
        return a.compareTo(b);
      });

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
                        '${sections.length} active sections · Separated by grade level',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddSectionDialog(
                      initialGrade: _selectedGradeFilter != 'All' ? _selectedGradeFilter : 'Grade 10',
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Section'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      minimumSize: const Size(0, 42),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Grade Level Filter Chips Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildGradeFilterChip('All', sections.length),
                    ..._grades.map((g) => _buildGradeFilterChip(g, gradeSectionCounts[g] ?? 0)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Empty state when no sections exist overall
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
                      Text('Click "+ Add Section" above to add your first classroom section with room assignment.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddSectionDialog(initialGrade: 'Grade 10'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create First Section'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_selectedGradeFilter == 'All') ...[
                // Render sections separated into Grade Level groups
                ...sortedGrades.expand((grade) {
                  final gradeSecs = groupedSections[grade] ?? [];
                  return [
                    _buildGradeGroupHeader(grade, gradeSecs.length),
                    ...gradeSecs.map((section) => _SectionCard(
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
                  ];
                }),
              ] else ...[
                // Render only selected grade level
                () {
                  final specificSecs = sections.where((s) => s['grade']?.toString() == _selectedGradeFilter).toList();
                  if (specificSecs.isEmpty) {
                    return _buildEmptyGradeState(_selectedGradeFilter);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGradeGroupHeader(_selectedGradeFilter, specificSecs.length),
                      ...specificSecs.map((section) => _SectionCard(
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
                  );
                }(),
              ],
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
        if (sSection.isEmpty) return false;
        return sSection == sectionName ||
            sectionName.contains(sSection) ||
            sSection.contains(sectionName);
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
                        if (widget.section['enrollment_key'] != null &&
                            widget.section['enrollment_key'].toString().isNotEmpty) ...[
                          InkWell(
                            onTap: () {
                              final key = widget.section['enrollment_key'].toString();
                              Clipboard.setData(ClipboardData(text: key));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Section Key "$key" copied to clipboard! Provide this to students.'),
                                  backgroundColor: AppTheme.success,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.vpn_key, size: 12, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Key: ${widget.section['enrollment_key']}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.copy, size: 11, color: Theme.of(context).colorScheme.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
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
