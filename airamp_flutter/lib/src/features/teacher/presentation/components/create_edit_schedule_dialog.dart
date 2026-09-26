import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/animations/app_transitions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_helper.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../auth/application/auth_provider.dart';
import '../../data/teacher_repository.dart';
import '../../data/teacher_schedule_repository.dart';

class CreateEditScheduleDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialSchedule;
  final String? defaultDay;
  final String? preselectedTeacherId;
  final String? preselectedTeacherName;

  const CreateEditScheduleDialog({
    super.key,
    this.initialSchedule,
    this.defaultDay,
    this.preselectedTeacherId,
    this.preselectedTeacherName,
  });

  static Future<bool?> show(
    BuildContext context, {
    Map<String, dynamic>? initialSchedule,
    String? defaultDay,
    String? preselectedTeacherId,
    String? preselectedTeacherName,
  }) {
    return AppModalTransitions.showSmoothDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateEditScheduleDialog(
        initialSchedule: initialSchedule,
        defaultDay: defaultDay,
        preselectedTeacherId: preselectedTeacherId,
        preselectedTeacherName: preselectedTeacherName,
      ),
    );
  }

  @override
  ConsumerState<CreateEditScheduleDialog> createState() => _CreateEditScheduleDialogState();
}

class _CreateEditScheduleDialogState extends ConsumerState<CreateEditScheduleDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedTeacherId;
  String? _selectedTeacherName;
  int? _selectedSubjectId;
  String? _selectedSubjectName;
  String? _selectedSection;
  bool _isCustomSection = false;
  final _customSectionController = TextEditingController();
  String _selectedDay = 'Monday';
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 30);
  final _roomController = TextEditingController();
  String _selectedColor = '#0D9488';

  bool _isSaving = false;
  String? _conflictError;

  static const List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  static const List<Map<String, dynamic>> _colorPresets = [
    {'name': 'Teal', 'hex': '#0D9488', 'color': Color(0xFF0D9488)},
    {'name': 'Blue', 'hex': '#2563EB', 'color': Color(0xFF2563EB)},
    {'name': 'Purple', 'hex': '#7C3AED', 'color': Color(0xFF7C3AED)},
    {'name': 'Amber', 'hex': '#D97706', 'color': Color(0xFFD97706)},
    {'name': 'Rose', 'hex': '#E11D48', 'color': Color(0xFFE11D48)},
    {'name': 'Emerald', 'hex': '#059669', 'color': Color(0xFF059669)},
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialSchedule;
    if (init != null) {
      _selectedTeacherId = init['teacher_id'] as String?;
      _selectedTeacherName = init['teacher_name'] as String?;
      _selectedSubjectId = init['subject_id'] as int?;
      _selectedSubjectName = init['subject_name'] as String?;
      _selectedSection = (init['section_name'] as String?)?.trim();
      _customSectionController.text = _selectedSection ?? '';
      _selectedDay = (init['day_of_week'] as String?) ?? 'Monday';
      _roomController.text = (init['room'] as String?) ?? '';
      _selectedColor = (init['color_code'] as String?) ?? '#0D9488';

      _startTime = _parseTime(init['start_time'] as String?) ?? const TimeOfDay(hour: 8, minute: 0);
      _endTime = _parseTime(init['end_time'] as String?) ?? const TimeOfDay(hour: 9, minute: 30);
    } else {
      _selectedTeacherId = widget.preselectedTeacherId;
      _selectedTeacherName = widget.preselectedTeacherName;
      if (widget.defaultDay != null && _daysOfWeek.contains(widget.defaultDay)) {
        _selectedDay = widget.defaultDay!;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminTeachersProvider.notifier).loadTeachers();
      ref.read(subjectsProvider.notifier).reload();
      ref.read(sectionsProvider.notifier).reload();
    });
  }

  @override
  void dispose() {
    _roomController.dispose();
    _customSectionController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return null;
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  String _formatTime(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDisplayTime(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final min = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        final startMinutes = picked.hour * 60 + picked.minute;
        final endMinutes = _endTime.hour * 60 + _endTime.minute;
        if (endMinutes <= startMinutes) {
          final newEndMin = (startMinutes + 90) % (24 * 60);
          _endTime = TimeOfDay(hour: newEndMin ~/ 60, minute: newEndMin % 60);
        }
        _conflictError = null;
      });
      _validateConflict();
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _conflictError = null;
      });
      _validateConflict();
    }
  }

  Future<void> _validateConflict() async {
    if (_selectedSection == null) return;
    final check = await DatabaseHelper().checkScheduleConflict(
      dayOfWeek: _selectedDay,
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      teacherId: _selectedTeacherId,
      sectionName: _selectedSection,
      room: _roomController.text.trim().isNotEmpty ? _roomController.text.trim() : null,
      excludeScheduleId: widget.initialSchedule?['id'] as String?,
    );

    if (mounted) {
      setState(() {
        if (check['hasConflict'] == true) {
          _conflictError = check['reason'] as String?;
        } else {
          _conflictError = null;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeacherId == null || _selectedTeacherName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an instructor/teacher to assign')),
      );
      return;
    }
    if (_selectedSubjectId == null || _selectedSubjectName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subject for this class')),
      );
      return;
    }
    final sectionToSave = _isCustomSection
        ? _customSectionController.text.trim()
        : (_selectedSection?.trim() ?? '');
    if (sectionToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or specify a class section')),
      );
      return;
    }
    _selectedSection = sectionToSave;

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      setState(() {
        _conflictError = 'End time must be after start time';
      });
      return;
    }

    setState(() => _isSaving = true);

    try {
      final startTimeStr = _formatTime(_startTime);
      final endTimeStr = _formatTime(_endTime);
      final roomStr = _roomController.text.trim();

      // Final Conflict Check
      final conflict = await DatabaseHelper().checkScheduleConflict(
        dayOfWeek: _selectedDay,
        startTime: startTimeStr,
        endTime: endTimeStr,
        teacherId: _selectedTeacherId,
        sectionName: _selectedSection,
        room: roomStr.isNotEmpty ? roomStr : null,
        excludeScheduleId: widget.initialSchedule?['id'] as String?,
      );

      if (conflict['hasConflict'] == true) {
        setState(() {
          _isSaving = false;
          _conflictError = conflict['reason'] as String? ?? 'Schedule conflict detected!';
        });
        return;
      }

      if (widget.initialSchedule != null) {
        await DatabaseHelper().updateClassSchedule(
          widget.initialSchedule!['id'] as String,
          {
            'teacher_id': _selectedTeacherId!,
            'teacher_name': _selectedTeacherName!,
            'subject_id': _selectedSubjectId!,
            'subject_name': _selectedSubjectName!,
            'section_name': _selectedSection!,
            'day_of_week': _selectedDay,
            'start_time': startTimeStr,
            'end_time': endTimeStr,
            'room': roomStr.isNotEmpty ? roomStr : null,
            'color_code': _selectedColor,
          },
        );
      } else {
        await DatabaseHelper().createClassSchedule({
          'teacher_id': _selectedTeacherId!,
          'teacher_name': _selectedTeacherName!,
          'subject_id': _selectedSubjectId!,
          'subject_name': _selectedSubjectName!,
          'section_name': _selectedSection!,
          'day_of_week': _selectedDay,
          'start_time': startTimeStr,
          'end_time': endTimeStr,
          'room': roomStr.isNotEmpty ? roomStr : null,
          'color_code': _selectedColor,
        });
      }

      // Invalidate riverpod providers
      ref.invalidate(allClassSchedulesProvider);
      ref.invalidate(todayTeacherSchedulesProvider);
      ref.invalidate(teacherSchedulesProvider);
      ref.invalidate(scheduledSectionsProvider);
      ref.invalidate(sectionSchedulesProvider);
      ref.invalidate(teacherHandledSectionsProvider);
      ref.invalidate(availableSectionsProvider);
      ref.invalidate(adminTeachersProvider);
      ref.invalidate(sectionsProvider);
      if (_selectedSection != null && _selectedSection!.trim().isNotEmpty) {
        ref.invalidate(sectionSchedulesProvider(_selectedSection!.trim()));
      }
      if (widget.initialSchedule != null) {
        final oldSec = (widget.initialSchedule!['section_name'] as String?)?.trim();
        if (oldSec != null && oldSec.isNotEmpty) {
          ref.invalidate(sectionSchedulesProvider(oldSec));
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.initialSchedule != null
                ? 'Class schedule updated successfully'
                : 'Schedule assigned to $_selectedTeacherName successfully',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _conflictError = 'Failed to save schedule: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final isAdmin = currentUser?.role == 'admin' || currentUser?.role == 'super_admin';
    final isTeacher = currentUser?.role == 'teacher';

    final teachers = ref.watch(adminTeachersProvider);
    final allSubjects = ref.watch(subjectsProvider);
    final allSections = ref.watch(sectionsProvider);

    final isEdit = widget.initialSchedule != null;

    // If teacher role, lock to their account
    if (isTeacher && currentUser != null) {
      _selectedTeacherId = currentUser.id;
      _selectedTeacherName = currentUser.fullName;
    }

    // Build safe list of teachers
    final List<Map<String, dynamic>> safeTeachers = List.from(teachers);
    if (_selectedTeacherId != null && !safeTeachers.any((t) => t['id'] == _selectedTeacherId)) {
      safeTeachers.insert(0, {
        'id': _selectedTeacherId!,
        'full_name': _selectedTeacherName ?? 'Instructor ($_selectedTeacherId)',
      });
    }
    if (_selectedTeacherId == null && safeTeachers.isNotEmpty) {
      _selectedTeacherId = safeTeachers.first['id'] as String?;
      _selectedTeacherName = safeTeachers.first['full_name'] as String?;
    }
    final effectiveTeacherId = (_selectedTeacherId != null && safeTeachers.any((t) => t['id'] == _selectedTeacherId))
        ? _selectedTeacherId
        : (safeTeachers.isNotEmpty ? safeTeachers.first['id'] as String? : null);

    // Determine subjects to offer: if teacher selected, optionally prioritize their assigned subjects
    final teacherMatch = safeTeachers.firstWhere(
      (t) => t['id'] == effectiveTeacherId,
      orElse: () => {},
    );
    final teacherAssignedSubjects = (teacherMatch['assigned_subjects'] as List? ?? []);

    final List<Map<String, dynamic>> safeSubjects = List.from(allSubjects);
    if (_selectedSubjectId != null && !safeSubjects.any((s) => s['id'] == _selectedSubjectId)) {
      safeSubjects.insert(0, {
        'id': _selectedSubjectId!,
        'name': _selectedSubjectName ?? 'Subject ($_selectedSubjectId)',
        'subject_code': '',
      });
    }
    if (_selectedSubjectId == null && safeSubjects.isNotEmpty) {
      if (teacherAssignedSubjects.isNotEmpty) {
        final firstAssigned = teacherAssignedSubjects.first as Map;
        _selectedSubjectId = firstAssigned['id'] as int?;
        _selectedSubjectName = firstAssigned['name'] as String?;
      } else {
        _selectedSubjectId = safeSubjects.first['id'] as int?;
        _selectedSubjectName = safeSubjects.first['name'] as String?;
      }
    }
    final effectiveSubjectId = (_selectedSubjectId != null && safeSubjects.any((s) => s['id'] == _selectedSubjectId))
        ? _selectedSubjectId
        : (safeSubjects.isNotEmpty ? safeSubjects.first['id'] as int? : null);

    // Section options: combine initial section, handled sections of teacher, and school sections
    final Set<String> sectionOptions = {};
    if (_selectedSection != null && _selectedSection!.trim().isNotEmpty) {
      sectionOptions.add(_selectedSection!.trim());
    }
    if (widget.initialSchedule != null) {
      final initSec = (widget.initialSchedule!['section_name'] as String?)?.trim();
      if (initSec != null && initSec.isNotEmpty) {
        sectionOptions.add(initSec);
      }
    }
    for (final sec in teacherMatch['handled_sections'] as List? ?? []) {
      final s = sec.toString().trim();
      if (s.isNotEmpty) sectionOptions.add(s);
    }
    for (final sec in allSections) {
      final name = (sec['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) sectionOptions.add(name);
    }
    if (sectionOptions.isEmpty) {
      sectionOptions.addAll(['STEM 12-A', 'STEM 12-B', 'ABM 12-A', 'HUMSS 12-A', 'Grade 10 - Emerald']);
    }

    if (_selectedSection == null || (!_isCustomSection && !sectionOptions.contains(_selectedSection))) {
      _selectedSection = sectionOptions.isNotEmpty ? sectionOptions.first : null;
    }

    final effectiveSelectedSection = (_selectedSection != null && sectionOptions.contains(_selectedSection))
        ? _selectedSection
        : (sectionOptions.isNotEmpty ? sectionOptions.first : null);

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Close Button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_calendar_rounded : Icons.calendar_month_rounded,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Edit Class Schedule' : 'Assign Class Schedule',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                            ),
                          ),
                          Text(
                            isAdmin
                                ? 'Assign faculty instructor, subject, section, time slot & room'
                                : 'Configure your class schedule, time slot & classroom',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Form Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Conflict Banner
                        if (_conflictError != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Schedule Conflict Detected',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.error,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _conflictError!,
                                        style: TextStyle(fontSize: 12, color: AppTheme.text),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Faculty / Teacher Selection Dropdown
                        Text(
                          'Assigned Faculty / Instructor *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isTeacher ? AppTheme.surface : AppTheme.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: effectiveTeacherId,
                              hint: Text('Select Instructor', style: TextStyle(color: AppTheme.textMuted)),
                              dropdownColor: AppTheme.surface,
                              items: safeTeachers.map((t) {
                                final tid = t['id'] as String;
                                final tname = t['full_name'] as String? ?? 'Teacher';
                                return DropdownMenuItem<String>(
                                  value: tid,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                        child: Text(
                                          tname.isNotEmpty ? tname[0].toUpperCase() : 'T',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          tname,
                                          style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: isTeacher
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        final match = safeTeachers.firstWhere((t) => t['id'] == val, orElse: () => {});
                                        setState(() {
                                          _selectedTeacherId = val;
                                          _selectedTeacherName = match['full_name'] as String?;
                                          _conflictError = null;
                                        });
                                        _validateConflict();
                                      }
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subject Selection Dropdown
                        Text(
                          'Class Subject *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: effectiveSubjectId,
                              hint: Text('Select Subject', style: TextStyle(color: AppTheme.textMuted)),
                              dropdownColor: AppTheme.surface,
                              items: safeSubjects.map((sub) {
                                final id = sub['id'] as int;
                                final name = sub['name'] as String? ?? 'Subject';
                                final code = sub['subject_code'] as String? ?? '';
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(
                                    code.isNotEmpty ? '$code - $name' : name,
                                    style: TextStyle(color: AppTheme.text, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  final match = safeSubjects.firstWhere((s) => s['id'] == val, orElse: () => {});
                                  setState(() {
                                    _selectedSubjectId = val;
                                    _selectedSubjectName = match['name'] as String?;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Section Selection Dropdown with Custom Input Toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Class Section *',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isCustomSection = !_isCustomSection;
                                  if (_isCustomSection) {
                                    _customSectionController.text = _selectedSection ?? '';
                                  } else {
                                    if (_customSectionController.text.trim().isNotEmpty) {
                                      _selectedSection = _customSectionController.text.trim();
                                    }
                                  }
                                });
                              },
                              icon: Icon(_isCustomSection ? Icons.list_rounded : Icons.edit_note_rounded, size: 14, color: AppTheme.primary),
                              label: Text(
                                _isCustomSection ? 'Choose from list' : 'Type custom section',
                                style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_isCustomSection)
                          TextFormField(
                            controller: _customSectionController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Grade 12 - STEM A',
                              prefixIcon: const Icon(Icons.class_outlined, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: AppTheme.background,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600),
                            onChanged: (val) {
                              _selectedSection = val.trim();
                              _validateConflict();
                            },
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Section name cannot be empty';
                              return null;
                            },
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: effectiveSelectedSection,
                                hint: Text('Select Section', style: TextStyle(color: AppTheme.textMuted)),
                                dropdownColor: AppTheme.surface,
                                items: sectionOptions.map((sec) {
                                  return DropdownMenuItem<String>(
                                    value: sec,
                                    child: Text(
                                      sec,
                                      style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSection = val;
                                    _conflictError = null;
                                  });
                                  _validateConflict();
                                },
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Day of Week
                        Text(
                          'Day of Week *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _daysOfWeek.map((day) {
                            final isSel = _selectedDay == day;
                            return ChoiceChip(
                              label: Text(day),
                              selected: isSel,
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppTheme.text,
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                              backgroundColor: AppTheme.background,
                              side: BorderSide(color: isSel ? AppTheme.primary : AppTheme.border),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedDay = day;
                                    _conflictError = null;
                                  });
                                  _validateConflict();
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Start & End Time Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Start Time *',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: _pickStartTime,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.background,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time, size: 18, color: AppTheme.primary),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatDisplayTime(_startTime),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppTheme.text,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Time *',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: _pickEndTime,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.background,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time_filled, size: 18, color: AppTheme.primary),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatDisplayTime(_endTime),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppTheme.text,
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
                        const SizedBox(height: 16),

                        // Room / Classroom
                        Text(
                          'Classroom / Laboratory (Optional)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _roomController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Room 302, Science Lab 1, Audi 2',
                            prefixIcon: Icon(Icons.room_outlined, size: 18, color: AppTheme.textMuted),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onChanged: (_) => _validateConflict(),
                        ),
                        const SizedBox(height: 16),

                        // Color Preset
                        Text(
                          'Card Color Accent',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _colorPresets.map((preset) {
                            final hex = preset['hex'] as String;
                            final color = preset['color'] as Color;
                            final isSel = _selectedColor == hex;

                            return InkWell(
                              onTap: () => setState(() => _selectedColor = hex),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel ? Colors.white : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: isSel
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.5),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                                child: isSel
                                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Dialog Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isEdit ? 'Update Schedule' : 'Assign Schedule',
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
  }
}
