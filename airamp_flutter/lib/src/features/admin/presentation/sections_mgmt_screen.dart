import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/aira_action_toast.dart';
import '../../../core/components/user_avatar_widget.dart';
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
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
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
    final editDescController = TextEditingController(
      text: section['description'] ?? '',
    );
    final editRoomController = TextEditingController(
      text: section['room'] ?? '',
    );
    final editKeyController = TextEditingController(
      text: section['enrollment_key'] ?? '',
    );
    String editSelectedGrade = section['grade'] ?? '';

    final initialSubjectCodes = <String>{};
    final rawSecSubs = section['subject_ids'];
    if (rawSecSubs is List) {
      for (final s in rawSecSubs) {
        if (s != null && s.toString().trim().isNotEmpty) {
          initialSubjectCodes.add(s.toString().trim().toUpperCase());
        }
      }
    } else if (rawSecSubs is String &&
        rawSecSubs.isNotEmpty &&
        rawSecSubs != 'null') {
      try {
        final dec = jsonDecode(rawSecSubs);
        if (dec is List) {
          for (final s in dec) {
            if (s != null && s.toString().trim().isNotEmpty) {
              initialSubjectCodes.add(s.toString().trim().toUpperCase());
            }
          }
        }
      } catch (_) {
        for (final s in rawSecSubs.split(',')) {
          if (s.trim().isNotEmpty) {
            initialSubjectCodes.add(s.trim().toUpperCase());
          }
        }
      }
    }
    final editSelectedSubjectCodes = Set<String>.from(initialSubjectCodes);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogStateCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(
                'Edit Section',
                style: TextStyle(color: AppTheme.text),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: editNameController,
                      maxLength: 40,
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      style: TextStyle(color: AppTheme.text),
                      decoration: const InputDecoration(
                        labelText: 'Section Name',
                        hintText: 'Section Name (e.g., Grade 12 - ICT A)',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editRoomController,
                      maxLength: 30,
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      style: TextStyle(color: AppTheme.text),
                      decoration: const InputDecoration(
                        labelText: 'Room / Building',
                        hintText: 'Room (e.g., Room 304 - Science Bldg)',
                        counterText: '',
                        prefixIcon: Icon(Icons.meeting_room_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editKeyController,
                      maxLength: 15,
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      style: TextStyle(color: AppTheme.text),
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Enrollment Key (for Students)',
                        counterText: '',
                        hintText: 'e.g., SEC-EMR10',
                        prefixIcon: const Icon(
                          Icons.vpn_key_outlined,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Auto-generate standard key',
                          icon: const Icon(
                            Icons.auto_fix_high_rounded,
                            size: 18,
                          ),
                          onPressed: () {
                            editKeyController
                                .text = SectionKeyHelper.generateKey(
                              sectionName: editNameController.text.isNotEmpty
                                  ? editNameController.text
                                  : (section['name'] ?? 'Section'),
                              gradeLevel: editSelectedGrade.isNotEmpty
                                  ? editSelectedGrade
                                  : section['grade'],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editDescController,
                      maxLength: 500,
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
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
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
                            setDialogState(
                              () => editSelectedGrade = selected ? grade : '',
                            );
                          },
                          selectedColor: Theme.of(context).colorScheme.primary,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assign Curriculum Subjects',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${editSelectedSubjectCodes.length} selected',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, cRef, _) {
                        final subjects = cRef.watch(subjectsProvider);
                        if (subjects.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No subjects found in database. Create subjects under Subjects & Courses first.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: subjects.map((sub) {
                            final code =
                                sub['subject_code']?.toString().toUpperCase() ??
                                sub['id']?.toString().toUpperCase() ??
                                '';
                            final name = sub['name']?.toString() ?? code;
                            final isSelected = editSelectedSubjectCodes
                                .contains(code);
                            return FilterChip(
                              label: Text('$code ($name)'),
                              selected: isSelected,
                              onSelected: (val) {
                                setDialogState(() {
                                  if (val) {
                                    editSelectedSubjectCodes.add(code);
                                  } else {
                                    editSelectedSubjectCodes.remove(code);
                                  }
                                });
                              },
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.2),
                              checkmarkColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : AppTheme.text,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                              ),
                            );
                          }).toList(),
                        );
                      },
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
                        content:
                            'Are you sure you want to update this section?',
                        onConfirm: () async {
                          final sectionId = section['id'];
                          final nav = Navigator.of(context);
                          if (sectionId is int) {
                            final rawKey = editKeyController.text
                                .trim()
                                .toUpperCase();
                            final key = rawKey.isNotEmpty
                                ? rawKey
                                : (section['enrollment_key'] ??
                                      'SEC-${section['id']}');
                            try {
                              await ref
                                  .read(sectionsProvider.notifier)
                                  .updateSection(sectionId, {
                                    'name': editNameController.text.trim(),
                                    'description': editDescController.text
                                        .trim(),
                                    'grade': editSelectedGrade.isNotEmpty
                                        ? editSelectedGrade
                                        : (section['grade'] ?? 'Grade 11'),
                                    'room': editRoomController.text.trim(),
                                    'enrollment_key': key,
                                    'subject_ids': editSelectedSubjectCodes
                                        .toList(),
                                  });
                              if (mounted) {
                                AiraActionToast.showSuccess(
                                  context,
                                  title: 'Section Updated',
                                  message:
                                      'Section "${editNameController.text.trim()}" updated successfully.',
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                final errStr = e.toString();
                                final displayMsg =
                                    errStr.contains('UNIQUE constraint') ||
                                        errStr.contains('already exists')
                                    ? 'A section with this enrollment key or name already exists.'
                                    : 'Failed to update section: ${errStr.replaceFirst("Exception: ", "")}';
                                AiraActionToast.showError(
                                  context,
                                  title: 'Failed to Update Section',
                                  message: displayMsg,
                                );
                              }
                            }
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
    final addSelectedSubjectCodes = <String>{};
    String? addSelectedTeacherId;
    String? addSelectedTeacherName;
    String addSelectedGrade =
        (initialGrade != null && _grades.contains(initialGrade))
        ? initialGrade
        : (_selectedGradeFilter != 'All' &&
                  _grades.contains(_selectedGradeFilter)
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.groups_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add New Section',
                    style: TextStyle(
                      color: AppTheme.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
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
                          maxLength: 40,
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => null,
                          style: TextStyle(color: AppTheme.text),
                          decoration: const InputDecoration(
                            labelText: 'Section Name',
                            counterText: '',
                            hintText: 'e.g., Grade 10 - Sapphire',
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          ),
                          onChanged: (val) {
                            if (!isCustomKey) {
                              setDialogState(() {
                                autoEnrollmentKey =
                                    SectionKeyHelper.generateKey(
                                      sectionName: val.trim().isNotEmpty
                                          ? val.trim()
                                          : 'Section',
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
                          maxLength: 30,
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => null,
                          style: TextStyle(color: AppTheme.text),
                          decoration: const InputDecoration(
                            labelText: 'Room / Building',
                            counterText: '',
                            hintText: 'e.g., Room 304 - Science Bldg',
                            prefixIcon: Icon(
                              Icons.meeting_room_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Auto-Generated Enrollment Key Card - Zero typing required!
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.25),
                            ),
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
                                      Icon(
                                        Icons.vpn_key_rounded,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Enrollment Key (optional)', // Exact text preserved for widget test compatibility
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'AUTO-GENERATED',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
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
                                      isCustomKey &&
                                              addKeyController.text.isNotEmpty
                                          ? addKeyController.text
                                          : autoEnrollmentKey,
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
                                    icon: Icon(
                                      Icons.shuffle_rounded,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        isCustomKey = false;
                                        addKeyController.clear();
                                        autoEnrollmentKey =
                                            SectionKeyHelper.generateRandomVariation(
                                              sectionName:
                                                  addNameController.text
                                                      .trim()
                                                      .isNotEmpty
                                                  ? addNameController.text
                                                        .trim()
                                                  : 'Section',
                                              gradeLevel: addSelectedGrade,
                                            );
                                      });
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Copy key',
                                    icon: Icon(
                                      Icons.copy_rounded,
                                      size: 16,
                                      color: AppTheme.textSecondary,
                                    ),
                                    onPressed: () {
                                      final keyToCopy =
                                          isCustomKey &&
                                              addKeyController.text.isNotEmpty
                                          ? addKeyController.text
                                          : autoEnrollmentKey;
                                      Clipboard.setData(
                                        ClipboardData(text: keyToCopy),
                                      );
                                      AiraActionToast.show(
                                        context,
                                        title: 'Key Copied',
                                        message:
                                            'Copied key "$keyToCopy" to clipboard',
                                        type: AiraToastType.info,
                                        customIcon: Icons.copy_rounded,
                                        duration: const Duration(seconds: 3),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Generated automatically when creating this section. Zero typing needed.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
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
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          )
                        else
                          TextFormField(
                            controller: addKeyController,
                            maxLength: 15,
                            buildCounter:
                                (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) => null,
                            style: TextStyle(color: AppTheme.text),
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Custom Key Override',
                              counterText: '',
                              hintText: 'e.g., SEC-CUSTOM10',
                              prefixIcon: Icon(Icons.edit_outlined, size: 18),
                            ),
                          ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: addDescController,
                          maxLength: 500,
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
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
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
                                      autoEnrollmentKey =
                                          SectionKeyHelper.generateKey(
                                            sectionName:
                                                addNameController.text
                                                    .trim()
                                                    .isNotEmpty
                                                ? addNameController.text.trim()
                                                : 'Section',
                                            gradeLevel: grade,
                                          );
                                    }
                                  });
                                }
                              },
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surface,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Assign Curriculum Subjects',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${addSelectedSubjectCodes.length} selected',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Consumer(
                          builder: (context, cRef, _) {
                            final subjects = cRef.watch(subjectsProvider);
                            if (subjects.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  'No subjects found in database. Create subjects under Subjects & Courses first.',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              );
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: subjects.map((sub) {
                                final code =
                                    sub['subject_code']
                                        ?.toString()
                                        .toUpperCase() ??
                                    sub['id']?.toString().toUpperCase() ??
                                    '';
                                final name = sub['name']?.toString() ?? code;
                                final isSelected = addSelectedSubjectCodes
                                    .contains(code);
                                return FilterChip(
                                  label: Text('$code ($name)'),
                                  selected: isSelected,
                                  onSelected: (val) {
                                    setDialogState(() {
                                      if (val) {
                                        addSelectedSubjectCodes.add(code);
                                      } else {
                                        addSelectedSubjectCodes.remove(code);
                                      }
                                    });
                                  },
                                  selectedColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.2),
                                  checkmarkColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : AppTheme.text,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Designated Teacher / Room Admin',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Consumer(
                          builder: (context, cRef, _) {
                            final teachers = cRef.watch(adminTeachersProvider);
                            return DropdownButtonFormField<String>(
                              initialValue: addSelectedTeacherId,
                              dropdownColor: Theme.of(
                                context,
                              ).colorScheme.surface,
                              decoration: const InputDecoration(
                                hintText:
                                    'Auto-assign from curriculum subjects',
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  size: 20,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(
                                    'Auto-assign from subjects / First faculty',
                                  ),
                                ),
                                ...teachers.map((t) {
                                  final tId = t['id']?.toString() ?? '';
                                  final tName =
                                      t['full_name']?.toString() ??
                                      t['name']?.toString() ??
                                      tId;
                                  return DropdownMenuItem<String>(
                                    value: tId,
                                    child: Text(
                                      '$tName (${t['email'] ?? tId})',
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setDialogState(() {
                                  addSelectedTeacherId = val;
                                  if (val != null) {
                                    final match = teachers.where(
                                      (t) => t['id']?.toString() == val,
                                    );
                                    if (match.isNotEmpty) {
                                      addSelectedTeacherName =
                                          match.first['full_name']
                                              ?.toString() ??
                                          match.first['name']?.toString();
                                    }
                                  } else {
                                    addSelectedTeacherName = null;
                                  }
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.forum_outlined,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Automated Group Chat: An official class group chat will automatically be initialized with key "${isCustomKey && addKeyController.text.isNotEmpty ? addKeyController.text : autoEnrollmentKey}" and the assigned teacher as Room Admin. Only students enrolled in this section will auto-join.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    height: 1.3,
                                  ),
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
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final name = addNameController.text.trim();
                      final rawKey = addKeyController.text.trim().toUpperCase();
                      final enrollmentKey = (isCustomKey && rawKey.isNotEmpty)
                          ? rawKey
                          : autoEnrollmentKey;

                      final rootContext = context;
                      final router = GoRouter.maybeOf(context);
                      Navigator.pop(dialogCtx);
                      try {
                        await ref.read(sectionsProvider.notifier).addSection({
                          'name': name,
                          'description': addDescController.text.trim(),
                          'grade': addSelectedGrade.isNotEmpty
                              ? addSelectedGrade
                              : 'Grade 10',
                          'room': addRoomController.text.trim(),
                          'enrollment_key': enrollmentKey,
                          'subject_ids': addSelectedSubjectCodes.toList(),
                          'teacher_id': addSelectedTeacherId,
                          'teacher_name': addSelectedTeacherName,
                          'student_count': 0,
                          'created_at': DateTime.now().toIso8601String(),
                        });
                        if (rootContext.mounted) {
                          AiraActionToast.showSuccess(
                            rootContext,
                            title: 'Section Created',
                            message:
                                'Created section "$name" with Key: $enrollmentKey',
                          );
                          try {
                            router?.go('/admin/keys');
                          } catch (_) {}
                        }
                      } catch (e) {
                        if (rootContext.mounted) {
                          final errStr = e.toString();
                          final displayMsg =
                              errStr.contains('UNIQUE constraint') ||
                                  errStr.contains('already exists')
                              ? 'A section with this enrollment key or name already exists. Please choose a different key.'
                              : 'Failed to create section: ${errStr.replaceFirst("Exception: ", "")}';
                          AiraActionToast.showError(
                            rootContext,
                            title: 'Failed to Create Section',
                            message: displayMsg,
                          );
                        }
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
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : primary.withValues(alpha: 0.12),
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
    final isJuniorHigh = [
      'Grade 7',
      'Grade 8',
      'Grade 9',
      'Grade 10',
    ].contains(grade);
    final isSeniorHigh = ['Grade 11', 'Grade 12'].contains(grade);
    final division = isJuniorHigh
        ? 'Junior High School'
        : (isSeniorHigh ? 'Senior High School' : 'Classroom Department');

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
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.school_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
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
            label: Text(
              MediaQuery.sizeOf(context).width < 600
                  ? 'Add'
                  : 'Add $grade Section',
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 600 ? 8 : 12,
                vertical: 8,
              ),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
          Icon(
            Icons.groups_outlined,
            size: 48,
            color: AppTheme.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No sections created for $grade yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
        child: RefreshIndicator(
          onRefresh: () async => ref.read(sectionsProvider.notifier).reload(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                LayoutBuilder(
                  builder: (context, headerConstraints) {
                    final isNarrow = headerConstraints.maxWidth < 600;

                    final titleSection = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Sections',
                          style: TextStyle(
                            fontSize: isNarrow ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${sections.length} active sections · Separated by grade level',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: isNarrow ? 12.5 : 14,
                          ),
                        ),
                      ],
                    );

                    final actionBtn = ElevatedButton.icon(
                      onPressed: () => _showAddSectionDialog(
                        initialGrade: _selectedGradeFilter != 'All'
                            ? _selectedGradeFilter
                            : 'Grade 10',
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Section'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        minimumSize: const Size(0, 42),
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleSection,
                          const SizedBox(height: 12),
                          actionBtn,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: titleSection),
                        const SizedBox(width: 16),
                        actionBtn,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Grade Level Filter Chips Bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildGradeFilterChip('All', sections.length),
                      ..._grades.map(
                        (g) => _buildGradeFilterChip(
                          g,
                          gradeSectionCounts[g] ?? 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Empty state when no sections exist overall
                if (sections.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 20,
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 48,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No class sections created yet.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Click "+ Add Section" above to add your first classroom section with room assignment.',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showAddSectionDialog(initialGrade: 'Grade 10'),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Create First Section'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
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
                      ...gradeSecs.map(
                        (section) => _SectionCard(
                          section: section,
                          onEdit: () => _showEditDialog(section),
                          onDelete: () {
                            _showConfirmation(
                              title: 'Delete Section',
                              content:
                                  'Are you sure you want to delete "${section['name']}"?',
                              onConfirm: () async {
                                final sectionId = section['id'];
                                final secName =
                                    section['name']?.toString() ?? 'Section';
                                if (sectionId is int) {
                                  try {
                                    await ref
                                        .read(sectionsProvider.notifier)
                                        .deleteSection(sectionId);
                                    if (mounted) {
                                      AiraActionToast.showDeleted(
                                        this.context,
                                        title: 'Section Deleted',
                                        message:
                                            'Section "$secName" was permanently deleted.',
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      AiraActionToast.showError(
                                        this.context,
                                        title: 'Failed to Delete Section',
                                        message:
                                            'Failed to delete section: ${e.toString().replaceFirst("Exception: ", "")}',
                                      );
                                    }
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ];
                  }),
                ] else ...[
                  // Render only selected grade level
                  () {
                    final specificSecs = sections
                        .where(
                          (s) => s['grade']?.toString() == _selectedGradeFilter,
                        )
                        .toList();
                    if (specificSecs.isEmpty) {
                      return _buildEmptyGradeState(_selectedGradeFilter);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGradeGroupHeader(
                          _selectedGradeFilter,
                          specificSecs.length,
                        ),
                        ...specificSecs.map(
                          (section) => _SectionCard(
                            section: section,
                            onEdit: () => _showEditDialog(section),
                            onDelete: () {
                              _showConfirmation(
                                title: 'Delete Section',
                                content:
                                    'Are you sure you want to delete "${section['name']}"?',
                                onConfirm: () async {
                                  final sectionId = section['id'];
                                  final secName =
                                      section['name']?.toString() ?? 'Section';
                                  if (sectionId is int) {
                                    try {
                                      await ref
                                          .read(sectionsProvider.notifier)
                                          .deleteSection(sectionId);
                                      if (mounted) {
                                        AiraActionToast.showDeleted(
                                          this.context,
                                          title: 'Section Deleted',
                                          message:
                                              'Section "$secName" was permanently deleted.',
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        AiraActionToast.showError(
                                          this.context,
                                          title: 'Failed to Delete Section',
                                          message:
                                              'Failed to delete section: ${e.toString().replaceFirst("Exception: ", "")}',
                                        );
                                      }
                                    }
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }(),
                ],
              ],
            ),
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

  const _SectionCard({
    required this.section,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  ConsumerState<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends ConsumerState<_SectionCard> {
  bool _isExpanded = false;
  int _selectedTab = 0; // 0 for Students, 1 for Subjects, 2 for Progress Chart
  List<Map<String, dynamic>> _sectionStudents = [];
  bool _isLoadingStudents = false;
  List<Map<String, dynamic>> _assignedSubjects = [];
  bool _isLoadingSubjects = false;

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

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadSubjects();
  }

  @override
  void didUpdateWidget(covariant _SectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _loadStudents();
      _loadSubjects();
    }
  }

  Future<void> _loadSubjects() async {
    setState(() => _isLoadingSubjects = true);
    try {
      final sectionName = widget.section['name']?.toString() ?? '';
      final list = await DatabaseHelper().getSubjectsForSection(sectionName);
      if (mounted) {
        setState(() {
          _assignedSubjects = list;
          _isLoadingSubjects = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSubjects = false);
    }
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final allStudents = await DatabaseHelper().getAdminStudentsList();
      final sectionName =
          widget.section['name']?.toString().toLowerCase().trim() ?? '';
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
        : (widget.section['student_count'] ??
              widget.section['studentCount'] ??
              0);

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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (widget.section['description'] != null &&
                        widget.section['description']
                            .toString()
                            .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.section['description'],
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
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
                            Icon(
                              Icons.school_outlined,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.section['grade'] ?? 'No grade',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (room.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.meeting_room_outlined,
                                size: 14,
                                color: AppTheme.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                room,
                                style: TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$studentCount students',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 14,
                              color: AppTheme.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_assignedSubjects.length} subjects',
                              style: TextStyle(
                                color: AppTheme.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (widget.section['enrollment_key'] != null &&
                            widget.section['enrollment_key']
                                .toString()
                                .isNotEmpty) ...[
                          InkWell(
                            onTap: () {
                              final key = widget.section['enrollment_key']
                                  .toString();
                              Clipboard.setData(ClipboardData(text: key));
                              AiraActionToast.show(
                                context,
                                title: 'Key Copied',
                                message:
                                    'Section Key "$key" copied to clipboard! Provide this to students.',
                                type: AiraToastType.info,
                                customIcon: Icons.copy_rounded,
                                duration: const Duration(seconds: 3),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.vpn_key,
                                    size: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Key: ${widget.section['enrollment_key']}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.copy,
                                    size: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
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
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primarySoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.errorSoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 20,
                    ),
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
                          color: _selectedTab == 0
                              ? AppTheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 16,
                              color: _selectedTab == 0
                                  ? Colors.black
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Students (${_sectionStudents.length})',
                              style: TextStyle(
                                color: _selectedTab == 0
                                    ? Colors.black
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
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
                          color: _selectedTab == 1
                              ? AppTheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 16,
                              color: _selectedTab == 1
                                  ? Colors.black
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Subjects (${_assignedSubjects.length})',
                              style: TextStyle(
                                color: _selectedTab == 1
                                    ? Colors.black
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 2
                              ? AppTheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bar_chart,
                              size: 16,
                              color: _selectedTab == 2
                                  ? Colors.black
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Progress',
                              style: TextStyle(
                                color: _selectedTab == 2
                                    ? Colors.black
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_selectedTab == 0)
              _buildStudentsList()
            else if (_selectedTab == 1)
              _buildSubjectsList()
            else
              _buildProgressChart(),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectsList() {
    if (_isLoadingSubjects) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigned Curriculum Subjects',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Enrolled students will have these courses loaded',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showAssignSubjectsModal(context),
              icon: const Icon(Icons.add_task_rounded, size: 14),
              label: const Text('Manage Subjects'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_assignedSubjects.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 32,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No subjects assigned to this section yet.',
                    style: TextStyle(
                      color: AppTheme.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Students in this section cannot see courses until subjects are assigned.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showAssignSubjectsModal(context),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Assign Subjects Now'),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          ..._assignedSubjects.map((sub) {
            final code =
                sub['subject_code']?.toString().toUpperCase() ??
                sub['id']?.toString().toUpperCase() ??
                '';
            final name = sub['name']?.toString() ?? code;
            final teacherName = sub['teacher_name']?.toString();
            final grade = sub['grade_level']?.toString() ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      code,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
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
                            color: AppTheme.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (grade.isNotEmpty) ...[
                              Text(
                                grade,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '·',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Icon(
                              Icons.person_outline,
                              size: 12,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              teacherName != null && teacherName.isNotEmpty
                                  ? teacherName
                                  : 'No teacher assigned',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove subject from section',
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () {
                      _showConfirmation(
                        title: 'Unassign Subject',
                        content: 'Remove "$code - $name" from this section?',
                        onConfirm: () async {
                          final sectionId = widget.section['id'];
                          if (sectionId is int) {
                            final currentCodes = _assignedSubjects
                                .map(
                                  (s) =>
                                      s['subject_code']
                                          ?.toString()
                                          .toUpperCase() ??
                                      s['id']?.toString().toUpperCase() ??
                                      '',
                                )
                                .where((c) => c != code && c.isNotEmpty)
                                .toList();
                            await ref
                                .read(sectionsProvider.notifier)
                                .assignSubjectsToSection(
                                  sectionId,
                                  currentCodes,
                                );
                            await _loadSubjects();
                            await _loadStudents();
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _showAssignSubjectsModal(BuildContext context) async {
    final sectionId = widget.section['id'];
    if (sectionId is! int) return;

    final currentSelected = _assignedSubjects
        .map(
          (s) =>
              s['subject_code']?.toString().toUpperCase() ??
              s['id']?.toString().toUpperCase() ??
              '',
        )
        .where((c) => c.isNotEmpty)
        .toSet();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allSubjects = ref.watch(subjectsProvider);
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.menu_book_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Subjects',
                          style: TextStyle(
                            color: AppTheme.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Section: ${widget.section['name']}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: allSubjects.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No subjects found. Please create subjects under Subjects & Courses first.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select the curriculum subjects that belong to this section. All students will immediately be enrolled in them.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...allSubjects.map((sub) {
                              final code =
                                  sub['subject_code']
                                      ?.toString()
                                      .toUpperCase() ??
                                  sub['id']?.toString().toUpperCase() ??
                                  '';
                              final name = sub['name']?.toString() ?? code;
                              final teacher = sub['teacher_name']?.toString();
                              final isChecked = currentSelected.contains(code);

                              return CheckboxListTile(
                                value: isChecked,
                                activeColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                checkColor: Colors.white,
                                title: Text(
                                  '$code - $name',
                                  style: TextStyle(
                                    color: AppTheme.text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  teacher != null && teacher.isNotEmpty
                                      ? 'Teacher: $teacher · ${sub['grade_level'] ?? ''}'
                                      : '${sub['grade_level'] ?? ''}',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      currentSelected.add(code);
                                    } else {
                                      currentSelected.remove(code);
                                    }
                                  });
                                },
                              );
                            }),
                          ],
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
                    Navigator.pop(dialogCtx);
                    try {
                      await ref
                          .read(sectionsProvider.notifier)
                          .assignSubjectsToSection(
                            sectionId,
                            currentSelected.toList(),
                          );
                      await _loadSubjects();
                      await _loadStudents();
                      if (context.mounted) {
                        AiraActionToast.showSuccess(
                          context,
                          title: 'Subjects Assigned',
                          message:
                              'Assigned ${currentSelected.length} subjects to ${widget.section['name']}. Students auto-enrolled.',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AiraActionToast.showError(
                          context,
                          title: 'Failed to Assign Subjects',
                          message: e.toString().replaceFirst("Exception: ", ""),
                        );
                      }
                    }
                  },
                  child: const Text('Save & Auto-Enroll Students'),
                ),
              ],
            );
          },
        );
      },
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
        child: Text(
          'No students currently assigned to this section.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      );
    }

    return Column(
      children: _sectionStudents.map((student) {
        final name = student['full_name'] ?? student['name'] ?? 'Student';
        final initials = name.toString().isNotEmpty
            ? name.toString()[0].toUpperCase()
            : '?';
        return Column(
          children: [
            Row(
              children: [
                UserAvatarWidget(
                  imageSource:
                      (student['profile_image'] ?? student['profileImage'])
                          as String?,
                  fallbackInitial: initials,
                  size: 36,
                  fontSize: 14,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: AppTheme.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${student['email'] ?? ''} · ${student['grade'] ?? widget.section['grade'] ?? ''}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
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
                  icon: Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
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
              Text(
                'Section Cohort Mastery',
                style: TextStyle(
                  color: AppTheme.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Live Stats',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Assigned Room: ${widget.section['room'] ?? 'Not specified'}',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Grade Level: ${widget.section['grade'] ?? 'Not specified'}',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
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
          Text(
            '75% curriculum completion target reached',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
