import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../teacher/data/teacher_schedule_repository.dart';
import '../../../../teacher/presentation/components/create_edit_schedule_dialog.dart';
import '../../../../teacher/presentation/components/halftone_pattern.dart';

class TeacherScheduleModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;

  const TeacherScheduleModal({
    super.key,
    required this.teacher,
  });

  static Future<void> show(BuildContext context, Map<String, dynamic> teacher) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TeacherScheduleModal(teacher: teacher),
    );
  }

  @override
  ConsumerState<TeacherScheduleModal> createState() => _TeacherScheduleModalState();
}

class _TeacherScheduleModalState extends ConsumerState<TeacherScheduleModal> {
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  String _selectedDay = 'All Days';

  static const List<String> _days = [
    'All Days',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    final teacherId = widget.teacher['id'] as String;
    final results = await DatabaseHelper().getClassSchedules(teacherId: teacherId);
    if (mounted) {
      setState(() {
        _schedules = results;
        _isLoading = false;
      });
    }
  }

  Color _parseColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.isEmpty) return fallback;
    try {
      final hex = hexString.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  String _formatDisplayTime(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return timeStr ?? '';
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final h = hour % 12 == 0 ? 12 : hour % 12;
      final m = minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $period';
    } catch (_) {
      return timeStr;
    }
  }

  void _confirmDelete(Map<String, dynamic> sched) {
    final id = sched['id'] as String;
    final subject = sched['subject_name'] as String? ?? 'Class';
    final section = sched['section_name'] as String? ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.error, size: 22),
            const SizedBox(width: 10),
            Text('Remove Schedule Entry', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove the class schedule for "$subject" ($section) from ${widget.teacher['full_name']}?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await DatabaseHelper().deleteClassSchedule(id);
              ref.invalidate(allClassSchedulesProvider);
              ref.invalidate(todayTeacherSchedulesProvider);
              ref.invalidate(teacherSchedulesProvider);
              await _loadSchedules();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Class schedule entry removed')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacherName = widget.teacher['full_name'] as String? ?? 'Teacher';
    final teacherEmail = widget.teacher['email'] as String? ?? '';
    final teacherId = widget.teacher['id'] as String;

    final filtered = _schedules.where((s) {
      if (_selectedDay != 'All Days' && s['day_of_week'] != _selectedDay) {
        return false;
      }
      return true;
    }).toList();

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                    child: Text(
                      teacherName.isNotEmpty ? teacherName[0].toUpperCase() : 'T',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              teacherName,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_schedules.length} Assigned Classes',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$teacherEmail • Assigned Schedule & Timetable (Admin Control)',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final updated = await CreateEditScheduleDialog.show(
                        context,
                        preselectedTeacherId: teacherId,
                        preselectedTeacherName: teacherName,
                      );
                      if (updated == true) {
                        await _loadSchedules();
                      }
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Assign Class'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Day of Week Filter Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _days.map((day) {
                    final isSel = _selectedDay == day;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(day),
                        selected: isSel,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: isSel
                              ? (AppTheme.isDark ? const Color(0xFF0A1420) : Colors.white)
                              : AppTheme.text,
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: AppTheme.background,
                        side: BorderSide(color: isSel ? AppTheme.primary : AppTheme.border),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedDay = day);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Content Area
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_month_outlined, size: 48, color: AppTheme.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'No class schedules assigned yet',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.text),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Click "Assign Class" to schedule teaching hours for $teacherName.',
                                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final updated = await CreateEditScheduleDialog.show(
                                      context,
                                      preselectedTeacherId: teacherId,
                                      preselectedTeacherName: teacherName,
                                    );
                                    if (updated == true) await _loadSchedules();
                                  },
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Assign Class Now'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            itemCount: filtered.length,
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 360,
                              mainAxisExtent: 140,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemBuilder: (context, index) {
                              final sched = filtered[index];
                              final subject = sched['subject_name'] as String? ?? 'Subject';
                              final section = sched['section_name'] as String? ?? 'Section';
                              final day = sched['day_of_week'] as String? ?? '';
                              final room = sched['room'] as String?;
                              final startTime = _formatDisplayTime(sched['start_time'] as String?);
                              final endTime = _formatDisplayTime(sched['end_time'] as String?);
                              final color = _parseColor(sched['color_code'] as String?, AppTheme.primary);

                              return ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: color.withValues(alpha: 0.3)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      // Halftone Pattern Accent
                                      HalftoneCardDecoration(
                                        color: color,
                                        width: 130,
                                        baseOpacity: 0.26,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Top Row: Section + Day + Admin Actions
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: color.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: color.withValues(alpha: 0.25)),
                                                  ),
                                                  child: Text(
                                                    section,
                                                    style: TextStyle(
                                                      color: color,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.background,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: AppTheme.border),
                                                  ),
                                                  child: Text(
                                                    day,
                                                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                const Spacer(),
                                                // Admin Edit & Delete
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                                  tooltip: 'Edit Schedule',
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                                  color: AppTheme.textSecondary,
                                                  onPressed: () async {
                                                    final updated = await CreateEditScheduleDialog.show(
                                                      context,
                                                      initialSchedule: sched,
                                                      preselectedTeacherId: teacherId,
                                                      preselectedTeacherName: teacherName,
                                                    );
                                                    if (updated == true) await _loadSchedules();
                                                  },
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                                                  tooltip: 'Remove Class',
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                                  onPressed: () => _confirmDelete(sched),
                                                ),
                                              ],
                                            ),

                                            // Subject Title
                                            Text(
                                              subject,
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.text),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),

                                            // Time & Room
                                            Row(
                                              children: [
                                                Icon(Icons.access_time, size: 13, color: AppTheme.textSecondary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$startTime - $endTime',
                                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                                ),
                                                if (room != null && room.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Icon(Icons.room_outlined, size: 13, color: AppTheme.textMuted),
                                                  const SizedBox(width: 2),
                                                  Flexible(
                                                    child: Text(
                                                      room,
                                                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
