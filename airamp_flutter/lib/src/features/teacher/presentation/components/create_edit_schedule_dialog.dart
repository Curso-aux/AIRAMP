import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/animations/app_transitions.dart';
import '../../../../core/components/aira_action_toast.dart';
import '../../../../core/components/aira_search_picker_modal.dart';
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
  int? _selectedSectionId;
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
      _selectedSectionId = init['section_id'] as int?;
      _selectedSection = (init['section_name'] as String?)?.trim();
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
      AiraActionToast.show(
        context,
        title: 'Teacher Required',
        message: 'Please select an instructor/teacher to assign.',
        type: AiraToastType.warning,
      );
      return;
    }
    if (_selectedSubjectId == null || _selectedSubjectName == null) {
      AiraActionToast.show(
        context,
        title: 'Subject Required',
        message: 'Please select a subject for this class.',
        type: AiraToastType.warning,
      );
      return;
    }
    final sectionToSave = _selectedSection?.trim() ?? '';
    if (sectionToSave.isEmpty) {
      AiraActionToast.show(
        context,
        title: 'Section Required',
        message: 'Please select a class section from the school directory.',
        type: AiraToastType.warning,
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

      final schedulePayload = <String, dynamic>{
        'teacher_id': _selectedTeacherId!,
        'teacher_name': _selectedTeacherName!,
        'subject_id': _selectedSubjectId!,
        'subject_name': _selectedSubjectName!,
        'section_id': _selectedSectionId,
        'section_name': _selectedSection!,
        'day_of_week': _selectedDay,
        'start_time': startTimeStr,
        'end_time': endTimeStr,
        'room': roomStr.isNotEmpty ? roomStr : null,
        'color_code': _selectedColor,
      };

      if (widget.initialSchedule != null) {
        await DatabaseHelper().updateClassSchedule(
          widget.initialSchedule!['id'] as String,
          schedulePayload,
        );
      } else {
        await DatabaseHelper().createClassSchedule(schedulePayload);
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
      AiraActionToast.showSuccess(
        context,
        title: widget.initialSchedule != null ? 'Schedule Updated' : 'Schedule Assigned',
        message: widget.initialSchedule != null
            ? 'Class schedule updated successfully.'
            : 'Schedule assigned to $_selectedTeacherName successfully.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _conflictError = 'Failed to save schedule: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildSearchSelectorField({
    required String label,
    required String? valueTitle,
    String? valueSubtitle,
    Widget? leading,
    String hintText = 'Tap to select',
    VoidCallback? onTap,
    bool isLocked = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isLocked) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 11, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Assigned to you',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: isLocked ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isLocked ? AppTheme.surface : AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        valueTitle ?? hintText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: valueTitle != null ? FontWeight.w600 : FontWeight.normal,
                          color: valueTitle != null ? AppTheme.text : AppTheme.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (valueSubtitle != null && valueSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          valueSubtitle,
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!isLocked)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.search_rounded, size: 15, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.textMuted),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
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

    // Section options: combine school sections, handled sections of teacher, and initial schedule section
    final Map<String, Map<String, dynamic>> sectionMap = {};
    for (final sec in allSections) {
      final name = (sec['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        sectionMap[name] = Map<String, dynamic>.from(sec);
      }
    }
    if (widget.initialSchedule != null) {
      final initSec = (widget.initialSchedule!['section_name'] as String?)?.trim();
      if (initSec != null && initSec.isNotEmpty && !sectionMap.containsKey(initSec)) {
        sectionMap[initSec] = {
          'id': widget.initialSchedule!['section_id'],
          'name': initSec,
          'grade': '',
          'room': widget.initialSchedule!['room'],
          'student_count': 0,
        };
      }
    }
    for (final sec in teacherMatch['handled_sections'] as List? ?? []) {
      final s = sec.toString().trim();
      if (s.isNotEmpty && !sectionMap.containsKey(s)) {
        sectionMap[s] = {'id': null, 'name': s, 'grade': '', 'student_count': 0};
      }
    }
    if (sectionMap.isEmpty) {
      for (final s in ['Grade 12 - Sapphire', 'STEM 12-A', 'STEM 12-B', 'ABM 12-A', 'HUMSS 12-A', 'Grade 10 - Emerald']) {
        sectionMap[s] = {'id': null, 'name': s, 'grade': '', 'student_count': 0};
      }
    }

    if (_selectedSection == null || !sectionMap.containsKey(_selectedSection)) {
      _selectedSection = sectionMap.isNotEmpty ? sectionMap.keys.first : null;
      if (_selectedSection != null) {
        _selectedSectionId = sectionMap[_selectedSection]?['id'] as int?;
      }
    } else if (_selectedSectionId == null && sectionMap.containsKey(_selectedSection)) {
      _selectedSectionId = sectionMap[_selectedSection]?['id'] as int?;
    }

    // Active display data
    final activeTeacher = safeTeachers.firstWhere(
      (t) => t['id'] == effectiveTeacherId,
      orElse: () => {},
    );
    final activeTeacherName = _selectedTeacherName ?? (activeTeacher['full_name'] as String?);
    final activeTeacherEmail = activeTeacher['email'] as String? ?? (isTeacher ? currentUser?.email : null);

    final activeSubject = safeSubjects.firstWhere(
      (s) => s['id'] == effectiveSubjectId,
      orElse: () => {},
    );
    final activeSubjectCode = activeSubject['subject_code'] as String? ?? '';
    final activeSubjectName = _selectedSubjectName ?? (activeSubject['name'] as String?);
    final activeSubjectDisplay = activeSubjectName != null
        ? (activeSubjectCode.isNotEmpty ? '$activeSubjectCode - $activeSubjectName' : activeSubjectName)
        : null;

    final activeSectionData = _selectedSection != null ? sectionMap[_selectedSection] : null;
    final activeSectionGrade = (activeSectionData?['grade'] as String?)?.trim() ?? '';
    final activeSectionRoom = (activeSectionData?['room'] as String?)?.trim() ?? '';
    final activeSectionStudents = activeSectionData?['student_count'] as int? ?? 0;
    final List<String> activeSectionSubDetails = [];
    if (activeSectionGrade.isNotEmpty) activeSectionSubDetails.add('Grade $activeSectionGrade');
    if (activeSectionStudents > 0) activeSectionSubDetails.add('$activeSectionStudents Students');
    if (activeSectionRoom.isNotEmpty) activeSectionSubDetails.add('Room: $activeSectionRoom');
    final activeSectionSubtitle = activeSectionSubDetails.isNotEmpty
        ? activeSectionSubDetails.join(' • ')
        : (_selectedSection != null ? 'Connected to Student Directory' : null);

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

                        // Searchable Faculty / Teacher Selection
                        _buildSearchSelectorField(
                          label: 'Assigned Faculty / Instructor *',
                          valueTitle: activeTeacherName,
                          valueSubtitle: activeTeacherEmail,
                          hintText: 'Search or select instructor...',
                          isLocked: isTeacher,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                            child: Text(
                              (activeTeacherName != null && activeTeacherName.isNotEmpty)
                                  ? activeTeacherName[0].toUpperCase()
                                  : 'T',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          onTap: () async {
                            final items = safeTeachers.map((t) {
                              final tid = t['id'] as String;
                              final tname = t['full_name'] as String? ?? 'Teacher';
                              final email = t['email'] as String? ?? '';
                              final dept = (t['department'] as String?) ?? (t['role'] as String?) ?? 'Faculty';
                              return AiraSearchPickerItem<String>(
                                value: tid,
                                title: tname,
                                subtitle: email.isNotEmpty ? email : dept,
                                badge: dept != 'Faculty' ? dept : null,
                                searchKeywords: [tname, email, dept, tid],
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                  child: Text(
                                    tname.isNotEmpty ? tname[0].toUpperCase() : 'T',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList();

                            final selected = await AiraSearchPickerModal.show<String>(
                              context: context,
                              title: 'Select Faculty / Instructor',
                              searchHint: 'Search teacher name, email, or dept...',
                              items: items,
                              selectedValue: _selectedTeacherId,
                              emptyMessage: 'No instructors found in directory.',
                            );

                            if (selected != null) {
                              final match = safeTeachers.firstWhere((t) => t['id'] == selected, orElse: () => {});
                              setState(() {
                                _selectedTeacherId = selected;
                                _selectedTeacherName = match['full_name'] as String?;
                                _conflictError = null;
                              });
                              _validateConflict();
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Searchable Subject Selection
                        _buildSearchSelectorField(
                          label: 'Class Subject *',
                          valueTitle: activeSubjectDisplay,
                          valueSubtitle: activeSubject['description'] as String?,
                          hintText: 'Search or select subject...',
                          leading: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.menu_book_rounded, color: AppTheme.primary, size: 16),
                          ),
                          onTap: () async {
                            final items = safeSubjects.map((sub) {
                              final sid = sub['id'] as int;
                              final sname = sub['name'] as String? ?? 'Subject';
                              final scode = sub['subject_code'] as String? ?? '';
                              final sgrade = sub['grade_level'] != null && sub['grade_level'].toString().isNotEmpty
                                  ? 'Grade ${sub['grade_level']}'
                                  : null;
                              final sdesc = sub['description'] as String? ?? '';
                              return AiraSearchPickerItem<int>(
                                value: sid,
                                title: scode.isNotEmpty ? '$scode - $sname' : sname,
                                subtitle: sdesc.isNotEmpty ? sdesc : (scode.isNotEmpty ? 'Subject Code: $scode' : null),
                                badge: sgrade,
                                searchKeywords: [sname, scode, sdesc, ?sgrade],
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.menu_book_rounded, color: AppTheme.primary, size: 16),
                                ),
                              );
                            }).toList();

                            final selected = await AiraSearchPickerModal.show<int>(
                              context: context,
                              title: 'Select Class Subject',
                              searchHint: 'Search subject name or course code...',
                              items: items,
                              selectedValue: _selectedSubjectId,
                              emptyMessage: 'No subjects found matching your search.',
                            );

                            if (selected != null) {
                              final match = safeSubjects.firstWhere((s) => s['id'] == selected, orElse: () => {});
                              setState(() {
                                _selectedSubjectId = selected;
                                _selectedSubjectName = match['name'] as String?;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Searchable Class Section Selection
                        _buildSearchSelectorField(
                          label: 'Class Section *',
                          valueTitle: _selectedSection,
                          valueSubtitle: activeSectionSubtitle,
                          hintText: 'Search or select classroom section...',
                          leading: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.groups_rounded, color: AppTheme.accent, size: 16),
                          ),
                          onTap: () async {
                            final items = sectionMap.values.map((sec) {
                              final sname = sec['name'] as String;
                              final sgrade = (sec['grade'] as String?)?.trim() ?? '';
                              final sroom = (sec['room'] as String?)?.trim() ?? '';
                              final studentCount = sec['student_count'] as int? ?? 0;

                              final List<String> details = [];
                              if (sgrade.isNotEmpty) details.add('Grade $sgrade');
                              if (studentCount > 0) details.add('$studentCount Students');
                              if (sroom.isNotEmpty) details.add('Room: $sroom');
                              final subtitle = details.isNotEmpty ? details.join(' • ') : 'School Directory Section';

                              return AiraSearchPickerItem<String>(
                                value: sname,
                                title: sname,
                                subtitle: subtitle,
                                badge: sgrade.isNotEmpty ? 'Grade $sgrade' : null,
                                searchKeywords: [sname, sgrade, sroom, if (studentCount > 0) '$studentCount students'],
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.groups_rounded, color: AppTheme.accent, size: 16),
                                ),
                              );
                            }).toList();

                            final selected = await AiraSearchPickerModal.show<String>(
                              context: context,
                              title: 'Select Class Section',
                              searchHint: 'Search section name, grade level, or room...',
                              items: items,
                              selectedValue: _selectedSection,
                              emptyMessage: 'No class section found in school directory matching your search.',
                            );

                            if (selected != null) {
                              final secData = sectionMap[selected];
                              setState(() {
                                _selectedSection = selected;
                                _selectedSectionId = secData?['id'] as int?;
                                final assignedRoom = secData?['room'] as String?;
                                if (assignedRoom != null && assignedRoom.isNotEmpty && _roomController.text.trim().isEmpty) {
                                  _roomController.text = assignedRoom;
                                }
                                _conflictError = null;
                              });
                              _validateConflict();
                            }
                          },
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
                          maxLength: 30,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          decoration: InputDecoration(
                            hintText: 'e.g. Room 302, Science Lab 1, Audi 2',
                            counterText: '',
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
