import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/teacher_repository.dart';
import '../../data/teacher_schedule_repository.dart';

class CreateEditScheduleDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialSchedule;
  final String? defaultDay;

  const CreateEditScheduleDialog({
    super.key,
    this.initialSchedule,
    this.defaultDay,
  });

  static Future<bool?> show(
    BuildContext context, {
    Map<String, dynamic>? initialSchedule,
    String? defaultDay,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateEditScheduleDialog(
        initialSchedule: initialSchedule,
        defaultDay: defaultDay,
      ),
    );
  }

  @override
  ConsumerState<CreateEditScheduleDialog> createState() => _CreateEditScheduleDialogState();
}

class _CreateEditScheduleDialogState extends ConsumerState<CreateEditScheduleDialog> {
  final _formKey = GlobalKey<FormState>();

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
      _selectedSubjectId = init['subject_id'] as int?;
      _selectedSubjectName = init['subject_name'] as String?;
      _selectedSection = init['section_name'] as String?;
      _selectedDay = (init['day_of_week'] as String?) ?? 'Monday';
      _roomController.text = (init['room'] as String?) ?? '';
      _selectedColor = (init['color_code'] as String?) ?? '#0D9488';

      _startTime = _parseTime(init['start_time'] as String?) ?? const TimeOfDay(hour: 8, minute: 0);
      _endTime = _parseTime(init['end_time'] as String?) ?? const TimeOfDay(hour: 9, minute: 30);
    } else if (widget.defaultDay != null && _daysOfWeek.contains(widget.defaultDay)) {
      _selectedDay = widget.defaultDay!;
    }
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
        // Default auto-adjust end time to +1.5h if end is before start
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
    final check = await ref.read(teacherSchedulesProvider.notifier).checkConflict(
          dayOfWeek: _selectedDay,
          startTime: _formatTime(_startTime),
          endTime: _formatTime(_endTime),
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
    if (_selectedSubjectId == null || _selectedSubjectName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an assigned subject')),
      );
      return;
    }
    if (_selectedSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class section')),
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

      Map<String, dynamic> result;
      if (widget.initialSchedule != null) {
        result = await ref.read(teacherSchedulesProvider.notifier).updateSchedule(
              id: widget.initialSchedule!['id'] as String,
              subjectId: _selectedSubjectId!,
              subjectName: _selectedSubjectName!,
              sectionName: _selectedSection!,
              dayOfWeek: _selectedDay,
              startTime: startTimeStr,
              endTime: endTimeStr,
              room: roomStr.isNotEmpty ? roomStr : null,
              colorCode: _selectedColor,
            );
      } else {
        result = await ref.read(teacherSchedulesProvider.notifier).addSchedule(
              subjectId: _selectedSubjectId!,
              subjectName: _selectedSubjectName!,
              sectionName: _selectedSection!,
              dayOfWeek: _selectedDay,
              startTime: startTimeStr,
              endTime: endTimeStr,
              room: roomStr.isNotEmpty ? roomStr : null,
              colorCode: _selectedColor,
            );
      }

      if (!mounted) return;

      if (result['hasConflict'] == true) {
        setState(() {
          _isSaving = false;
          _conflictError = result['reason'] as String? ?? 'Time conflict detected!';
        });
        return;
      }

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.initialSchedule != null
                ? 'Class schedule updated successfully'
                : 'Class schedule created successfully',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save schedule: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(teacherSubjectsProvider);
    final sectionsAsync = ref.watch(teacherHandledSectionsProvider);
    final sections = sectionsAsync.value ?? [];

    final isEdit = widget.initialSchedule != null;

    // Default subject if single
    if (_selectedSubjectId == null && subjects.isNotEmpty) {
      _selectedSubjectId = subjects.first['id'] as int?;
      _selectedSubjectName = subjects.first['name'] as String?;
    }
    // Default section if single
    if (_selectedSection == null && sections.isNotEmpty) {
      _selectedSection = sections.first;
    }

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
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
                            isEdit ? 'Edit Class Schedule' : 'Schedule New Class',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                            ),
                          ),
                          Text(
                            'Assign subject, handled section, time window & room',
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

                        // Subject Selection Dropdown
                        Text(
                          'Assigned Subject *',
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
                              items: subjects.map((sub) {
                                return DropdownMenuItem<int>(
                                  value: sub['id'] as int,
                                  child: Text(
                                    sub['name'] as String? ?? 'Subject',
                                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  final match = subjects.firstWhere((s) => s['id'] == val);
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
                              items: sections.map((sec) {
                                return DropdownMenuItem<String>(
                                  value: sec,
                                  child: Text(
                                    sec,
                                    style: TextStyle(color: AppTheme.text, fontSize: 14),
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
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.text),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
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
                                          Icon(Icons.access_time_filled, size: 18, color: AppTheme.textSecondary),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatDisplayTime(_endTime),
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.text),
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

                        // Room / Venue Field
                        Text(
                          'Classroom / Laboratory / Venue',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _roomController,
                          style: TextStyle(color: AppTheme.text, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'e.g. Room 302, Science Lab, AVR',
                            hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            prefixIcon: Icon(Icons.meeting_room_outlined, color: AppTheme.textSecondary, size: 20),
                            filled: true,
                            fillColor: AppTheme.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.border),
                            ),
                          ),
                          onChanged: (_) {
                            _conflictError = null;
                            _validateConflict();
                          },
                        ),
                        const SizedBox(height: 16),

                        // Card Color Accent Picker
                        Text(
                          'Timetable Card Accent Color',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: _colorPresets.map((preset) {
                            final hex = preset['hex'] as String;
                            final color = preset['color'] as Color;
                            final isSel = _selectedColor == hex;

                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: InkWell(
                                onTap: () => setState(() => _selectedColor = hex),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: isSel
                                        ? Border.all(color: Colors.white, width: 3)
                                        : Border.all(color: Colors.transparent),
                                    boxShadow: isSel
                                        ? [
                                            BoxShadow(
                                              color: color.withValues(alpha: 0.5),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: isSel
                                      ? const Center(
                                          child: Icon(Icons.check, size: 16, color: Colors.white),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              isEdit ? 'Save Changes' : 'Create Schedule',
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
