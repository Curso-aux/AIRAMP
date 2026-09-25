import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_helper.dart';
import '../../../admin/data/admin_repository.dart';
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
    return showDialog<bool>(
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
      _selectedSection = init['section_name'] as String?;
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
    });
  }

  @override
  void dispose() {
    _roomController.dispose();
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
    if (_selectedSection == null || _selectedSection!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or specify a class section')),
      );
      return;
    }

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
    final teachers = ref.watch(adminTeachersProvider);
    final allSubjects = ref.watch(subjectsProvider);
    final allSections = ref.watch(sectionsProvider);

    final isEdit = widget.initialSchedule != null;

    // Auto-select initial teacher if needed
    if (_selectedTeacherId == null && teachers.isNotEmpty) {
      _selectedTeacherId = teachers.first['id'] as String?;
      _selectedTeacherName = teachers.first['full_name'] as String?;
    }

    // Determine subjects to offer: if teacher selected, optionally prioritize their assigned subjects
    final teacherMatch = teachers.firstWhere(
      (t) => t['id'] == _selectedTeacherId,
      orElse: () => {},
    );
    final teacherAssignedSubjects = (teacherMatch['assigned_subjects'] as List? ?? []);

    final List<Map<String, dynamic>> availableSubjects = allSubjects;

    // Default subject if not set
    if (_selectedSubjectId == null && availableSubjects.isNotEmpty) {
      if (teacherAssignedSubjects.isNotEmpty) {
        final firstAssigned = teacherAssignedSubjects.first as Map;
        _selectedSubjectId = firstAssigned['id'] as int?;
        _selectedSubjectName = firstAssigned['name'] as String?;
      } else {
        _selectedSubjectId = availableSubjects.first['id'] as int?;
        _selectedSubjectName = availableSubjects.first['name'] as String?;
      }
    }

    // Section options: combine handled sections of teacher with school sections
    final Set<String> sectionOptions = {};
    for (final sec in teacherMatch['handled_sections'] as List? ?? []) {
      sectionOptions.add(sec.toString());
    }
    for (final sec in allSections) {
      final name = sec['name'] as String?;
      if (name != null && name.isNotEmpty) sectionOptions.add(name);
    }
    if (sectionOptions.isEmpty) {
      sectionOptions.addAll(['STEM 12-A', 'STEM 12-B', 'ABM 12-A', 'HUMSS 12-A']);
    }

    if (_selectedSection == null && sectionOptions.isNotEmpty) {
      _selectedSection = sectionOptions.first;
    }

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
                            'Assign faculty instructor, subject, section, time slot & room',
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
                          'Assign to Faculty / Teacher *',
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
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedTeacherId,
                              hint: Text('Select Instructor', style: TextStyle(color: AppTheme.textMuted)),
                              dropdownColor: AppTheme.surface,
                              items: teachers.map((t) {
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
                              onChanged: (val) {
                                if (val != null) {
                                  final match = teachers.firstWhere((t) => t['id'] == val, orElse: () => {});
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
                              value: _selectedSubjectId,
                              hint: Text('Select Subject', style: TextStyle(color: AppTheme.textMuted)),
                              dropdownColor: AppTheme.surface,
                              items: availableSubjects.map((sub) {
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
                                  final match = availableSubjects.firstWhere((s) => s['id'] == val);
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

                        // Section Selection Dropdown
                        Text(
                          'Class Section *',
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
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedSection,
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
