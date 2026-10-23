import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/components/calendar/actual_calendar_view.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../teacher/data/teacher_schedule_repository.dart';
import '../../../teacher/presentation/components/halftone_pattern.dart';

enum StudentModalViewMode { grid, calendar, agenda }

/// Helper function to open the student's timetable modal
void showStudentTimetableModal(
  BuildContext context, {
  String? sectionName,
  String? initialSection,
}) {
  final targetSection = (sectionName != null && sectionName.trim().isNotEmpty)
      ? sectionName.trim()
      : (initialSection != null && initialSection.trim().isNotEmpty
          ? initialSection.trim()
          : null);

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => WeeklyTimetableDialog(
      sectionName: targetSection,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMETABLE COLOR PALETTE (Matches the university schedule matrix in user's image)
// ─────────────────────────────────────────────────────────────────────────────
class TimetableColorPalette {
  /// Saturated 7-color fallback palette matching ActualCalendarView exactly.
  static const List<Color> fallbackPalette = [
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink (matches 1st pic in calendar)
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
  ];

  /// Returns the canonical subject color matching the calendar card.
  static Color getSubjectColor(String subjectName, String? hexColor, bool isDark) {
    if (hexColor != null && hexColor.isNotEmpty) {
      try {
        final hex = hexColor.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    return fallbackPalette[subjectName.hashCode.abs() % fallbackPalette.length];
  }

  /// Backward-compatible map for components accessing background and border tints.
  static Map<String, Color> getColors(String subjectName, String? hexColor, bool isDark) {
    final color = getSubjectColor(subjectName, hexColor, isDark);
    return {
      'base': color,
      'bg': isDark ? color.withValues(alpha: 0.16) : color.withValues(alpha: 0.08),
      'border': isDark ? color.withValues(alpha: 0.45) : color.withValues(alpha: 0.35),
      'text': color,
      'accent': color,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT SCHEDULE WIDGET (DASHBOARD HUB)
// ─────────────────────────────────────────────────────────────────────────────
class StudentScheduleWidget extends ConsumerStatefulWidget {
  final String? sectionName;

  const StudentScheduleWidget({super.key, this.sectionName});

  @override
  ConsumerState<StudentScheduleWidget> createState() => _StudentScheduleWidgetState();
}

class _StudentScheduleWidgetState extends ConsumerState<StudentScheduleWidget> {
  bool _isCalendarMode = false;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sec = widget.sectionName?.trim();
      if (sec != null && sec.isNotEmpty) {
        ref.invalidate(sectionSchedulesProvider(sec));
      }
    });
  }

  @override
  void didUpdateWidget(covariant StudentScheduleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sectionName != oldWidget.sectionName) {
      final sec = widget.sectionName?.trim();
      if (sec != null && sec.isNotEmpty) {
        ref.invalidate(sectionSchedulesProvider(sec));
      }
    }
  }

  bool _isOngoing(Map<String, dynamic> sched) {
    final schedDay = sched['day_of_week'] as String?;
    if (schedDay != getCurrentDayOfWeek()) return false;

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final startParts = (sched['start_time'] as String? ?? '').split(':');
    final endParts = (sched['end_time'] as String? ?? '').split(':');
    if (startParts.length < 2 || endParts.length < 2) return false;

    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  bool _isPast(Map<String, dynamic> sched) {
    final schedDay = sched['day_of_week'] as String?;
    if (schedDay != getCurrentDayOfWeek()) return false;

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final endParts = (sched['end_time'] as String? ?? '').split(':');
    if (endParts.length < 2) return false;

    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    return nowMinutes >= endMinutes;
  }

  void _openTimetableModal(BuildContext context) {
    showStudentTimetableModal(context, sectionName: widget.sectionName);
  }

  @override
  Widget build(BuildContext context) {
    final studentSection = widget.sectionName?.trim();

    // If student has no section assigned yet
    if (studentSection == null || studentSection.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.school_outlined, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Section Assigned',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Please contact your school administrator or teacher to assign you to a section to view your timetable.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final schedulesAsync = ref.watch(sectionSchedulesProvider(studentSection));
    final today = getCurrentDayOfWeek();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row: Title and Timetable Grid button
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Class Schedule",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Open Full Timetable Grid',
              icon: Icon(Icons.grid_view_rounded, size: 20, color: AppTheme.primary),
              onPressed: () => _openTimetableModal(context),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Subtitle row: Section Info & View Mode Toggle (responsive Wrap)
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(
                  "Section: ",
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    studentSection,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                Text(' • $today', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
            // View Mode Toggle (Today vs Calendar)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => setState(() => _isCalendarMode = false),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: !_isCalendarMode ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_day_outlined,
                            size: 13,
                            color: !_isCalendarMode ? AppTheme.primary : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Today',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: !_isCalendarMode ? FontWeight.bold : FontWeight.normal,
                              color: !_isCalendarMode ? AppTheme.primary : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _isCalendarMode = true),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isCalendarMode ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 13,
                            color: _isCalendarMode ? AppTheme.primary : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Calendar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _isCalendarMode ? FontWeight.bold : FontWeight.normal,
                              color: _isCalendarMode ? AppTheme.primary : AppTheme.textMuted,
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
        const SizedBox(height: 12),

        // Body Content
        schedulesAsync.when(
          loading: () => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Loading your schedule...',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          error: (err, _) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.textMuted, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Unable to load schedule. Tap Timetable Grid to check.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () => _openTimetableModal(context),
                  child: const Text('Open', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          data: (allSchedules) {
            if (_isCalendarMode) {
              if (allSchedules.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 44, color: AppTheme.textMuted),
                        const SizedBox(height: 10),
                        Text(
                          'No Class Schedules Found',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your teachers have not uploaded class schedules for Section $studentSection yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ActualCalendarView(
                schedules: allSchedules,
                isStudent: true,
                emptySubtitle: 'No classes scheduled for Section $studentSection on this day.',
              );
            }

            // Case 1: No schedules uploaded for this student's section at all
            if (allSchedules.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.event_note_rounded, color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No Classes Uploaded for Section $studentSection',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your teachers have not uploaded weekly class schedules for your section yet.',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            final todaySchedules = allSchedules.where((s) => s['day_of_week'] == today).toList();

            // Case 2: Has weekly schedules, but none for today
            if (todaySchedules.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.event_available_rounded, color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No Classes Today ($today)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            allSchedules.length == 1
                                ? 'You have 1 class scheduled this week for $studentSection.'
                                : 'You have ${allSchedules.length} classes scheduled this week for $studentSection.',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openTimetableModal(context),
                      icon: const Icon(Icons.grid_view_rounded, size: 12),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      label: Text('View Grid', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                    ),
                  ],
                ),
              );
            }

            // Case 3: Today's scheduled classes exist
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Column(
              children: todaySchedules.map((sched) {
                final subject = sched['subject_name'] as String? ?? 'Subject';
                final teacher = sched['teacher_name'] as String? ?? 'Instructor';
                final room = sched['room'] as String? ?? 'Classroom';
                final start = _formatDisplayTime(sched['start_time'] as String?);
                final end = _formatDisplayTime(sched['end_time'] as String?);
                final hexCode = sched['color_code'] as String?;
                final colors = TimetableColorPalette.getColors(subject, hexCode, isDark);
                final ongoing = _isOngoing(sched);
                final past = _isPast(sched);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ongoing
                          ? AppTheme.primary
                          : (past ? AppTheme.border.withValues(alpha: 0.5) : AppTheme.border),
                      width: ongoing ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Time indicator pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors['bg'],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors['border']!.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_filled_rounded, size: 12, color: colors['border']),
                                const SizedBox(width: 4),
                                Text(
                                  start,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colors['text'],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              end,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: colors['text']!.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Class Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    subject,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: past ? AppTheme.textMuted : AppTheme.text,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (ongoing) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: AppTheme.success,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'HAPPENING NOW',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (past) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.border.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'FINISHED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 10,
                              runSpacing: 2,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_pin_rounded, size: 13, color: AppTheme.textSecondary),
                                    const SizedBox(width: 3),
                                    Text(
                                      teacher,
                                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.meeting_room_outlined, size: 13, color: AppTheme.textSecondary),
                                    const SizedBox(width: 3),
                                    Text(
                                      room,
                                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEEKLY TIMETABLE DIALOG (THE FULL MATRIX GRID AS REQUESTED IN USER SCREENSHOT)
// ─────────────────────────────────────────────────────────────────────────────
class WeeklyTimetableDialog extends ConsumerStatefulWidget {
  final String? sectionName;

  const WeeklyTimetableDialog({
    super.key,
    required this.sectionName,
  });

  @override
  ConsumerState<WeeklyTimetableDialog> createState() => _WeeklyTimetableDialogState();
}

class _WeeklyTimetableDialogState extends ConsumerState<WeeklyTimetableDialog> {
  // Days represented in the timetable matrix
  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  static const List<String> _dayLabels = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
  ];

  // Grid Configuration:
  // Starts at 7:00 AM (420 minutes)
  // Ends at 9:00 PM (1260 minutes)
  static const int _gridStartMinutes = 420; // 07:00 AM
  static const int _gridEndMinutes = 1260; // 09:00 PM
  static const double _slotHeight = 36.0; // Height per 30-minute block
  static const int _slotMinutes = 30;
  static const int _totalSlots = (_gridEndMinutes - _gridStartMinutes) ~/ _slotMinutes; // 28 slots

  // Scroll controllers for synchronization
  final ScrollController _horizontalGridController = ScrollController();
  final ScrollController _verticalGridController = ScrollController();
  final ScrollController _timeColVerticalController = ScrollController();

  // Active day filter for mobile jump / agenda view
  String _activeDayJump = 'ALL';
  StudentModalViewMode _modalViewMode = StudentModalViewMode.grid;

  @override
  void initState() {
    super.initState();
    // Synchronize vertical scroll between Time column and Days grid
    _verticalGridController.addListener(() {
      if (_timeColVerticalController.hasClients &&
          _timeColVerticalController.offset != _verticalGridController.offset) {
        _timeColVerticalController.jumpTo(_verticalGridController.offset);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sec = widget.sectionName?.trim();
      if (sec != null && sec.isNotEmpty) {
        ref.invalidate(sectionSchedulesProvider(sec));
      }
    });
  }

  @override
  void dispose() {
    _horizontalGridController.dispose();
    _verticalGridController.dispose();
    _timeColVerticalController.dispose();
    super.dispose();
  }

  bool _isOngoing(Map<String, dynamic> sched) {
    final now = DateTime.now();
    final today = getCurrentDayOfWeek();
    final schedDay = sched['day_of_week'] as String?;
    if (schedDay == null || schedDay.toLowerCase() != today.toLowerCase()) return false;

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = _parseTimeToMinutes(sched['start_time'] as String?);
    final endMinutes = _parseTimeToMinutes(sched['end_time'] as String?);
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
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

  int _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return _gridStartMinutes;
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return hour * 60 + minute;
    } catch (_) {
      return _gridStartMinutes;
    }
  }

  String _formatSlotLabel(int slotIndex) {
    final startM = _gridStartMinutes + slotIndex * _slotMinutes;
    final endM = startM + _slotMinutes;

    String fmt(int totalM) {
      final h = (totalM ~/ 60) % 12 == 0 ? 12 : (totalM ~/ 60) % 12;
      final m = (totalM % 60).toString().padLeft(2, '0');
      return '$h:$m';
    }

    return '${fmt(startM)}-${fmt(endM)}';
  }

  void _scrollToDayIndex(int dayIndex, double colWidth) {
    if (!_horizontalGridController.hasClients) return;
    final target = dayIndex * colWidth;
    _horizontalGridController.animateTo(
      target.clamp(0.0, _horizontalGridController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  String _formatTimeDisplay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'TBA';
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final h12 = hour % 12 == 0 ? 12 : hour % 12;
        return '$h12:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (_) {}
    return timeStr;
  }

  void _showClassDetailModal(BuildContext context, Map<String, dynamic> c, bool isDark) {
    final subject = c['subject_name'] as String? ?? 'Subject';
    final teacher = c['teacher_name'] as String? ?? 'Assigned Faculty';
    final room = c['room'] as String? ?? 'Designated Facility';
    final day = c['day_of_week'] as String? ?? '';
    final start = _formatTimeDisplay(c['start_time'] as String?);
    final end = _formatTimeDisplay(c['end_time'] as String?);
    final section = (widget.sectionName != null && widget.sectionName!.isNotEmpty)
        ? widget.sectionName!
        : (c['section_name'] as String? ?? 'Grade 10 - Emerald');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Institutional Header: Neutral Identity Box + Badges + Title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Neutral Subject Icon Box (Subtle Slate, no bright neon colors)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF334155),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Header Details: Calm Slate Badges + Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tag row: Clean neutral Day Badge + Official Status Badge
                          Row(
                            children: [
                              if (day.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    day,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 10,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Official Class',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // Full Subject Title
                          Text(
                            subject,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Academic Timetable Schedule',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Top-right Close Icon Button
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(ctx).pop();
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Icon(Icons.close_rounded, size: 15, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(height: 1, thickness: 1, color: AppTheme.border.withValues(alpha: 0.5)),
                const SizedBox(height: 14),

                // Institutional Information Cards - Quiet, Monochromatic Slate
                _buildModalInfoTile(
                  icon: Icons.schedule_rounded,
                  category: 'CLASS PERIOD',
                  value: '$start - $end',
                  caption: '$day • Designated class hours',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),

                _buildModalInfoTile(
                  icon: Icons.person_outline_rounded,
                  category: 'FACULTY / INSTRUCTOR',
                  value: teacher,
                  caption: 'Assigned Subject Educator',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),

                _buildModalInfoTile(
                  icon: Icons.meeting_room_outlined,
                  category: 'CAMPUS FACILITY & ROOM',
                  value: room,
                  caption: 'Physical class venue & laboratory',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),

                _buildModalInfoTile(
                  icon: Icons.school_outlined,
                  category: 'ASSIGNED SECTION',
                  value: section,
                  caption: 'Official student cohort & class group',
                  isDark: isDark,
                ),

                const SizedBox(height: 18),

                // Neutral Executive Button (Deep Slate 900 in light, Clean Charcoal in dark)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF222F42) : const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Close Overview',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalInfoTile({
    required IconData icon,
    required String category,
    required String value,
    required String caption,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141C2B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF26354A) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF2F7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF2E3E55) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalModeSelector({bool isMobile = false}) {
    final isDark = AppTheme.isDark;
    return Container(
      padding: EdgeInsets.all(isMobile ? 2.5 : 3.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16253B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeSelectorButton(
            mode: StudentModalViewMode.grid,
            icon: Icons.grid_view_rounded,
            tooltip: 'Weekly Timetable Matrix',
            label: 'Grid',
            isMobile: isMobile,
          ),
          _buildModeSelectorButton(
            mode: StudentModalViewMode.calendar,
            icon: Icons.calendar_month_rounded,
            tooltip: 'Monthly Calendar Mode',
            label: 'Calendar',
            isMobile: isMobile,
          ),
          _buildModeSelectorButton(
            mode: StudentModalViewMode.agenda,
            icon: Icons.view_agenda_outlined,
            tooltip: 'Agenda Timeline List',
            label: 'Agenda',
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectorButton({
    required StudentModalViewMode mode,
    required IconData icon,
    required String tooltip,
    required String label,
    bool isMobile = false,
  }) {
    final isSelected = _modalViewMode == mode;
    final isDark = AppTheme.isDark;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _modalViewMode = mode),
          borderRadius: BorderRadius.circular(7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 11,
              vertical: isMobile ? 4.5 : 5.5,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppTheme.surfaceLight : Colors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: isMobile ? 12 : 13,
                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                ),
                SizedBox(width: isMobile ? 3 : 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 10.5 : 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF1E293B))
                        : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentSection = widget.sectionName?.trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return Dialog(
      backgroundColor: AppTheme.surface,
      clipBehavior: Clip.antiAlias,
      elevation: isDark ? 16 : 8,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          children: [
            // ── Top Header ──────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surface : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle for mobile
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        // Row 1 on Mobile: Icon, Title & Section, Refresh & Close
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.primary.withValues(alpha: 0.22),
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.grid_on_rounded, color: AppTheme.primary, size: 17),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Class Timetable Schedule',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.2,
                                      color: AppTheme.text,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 4,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        'Section: ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(
                                            color: AppTheme.primary.withValues(alpha: 0.25),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          studentSection != null && studentSection.isNotEmpty ? studentSection : 'No Section',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Tooltip(
                              message: 'Refresh Schedule',
                              child: Material(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    if (studentSection != null && studentSection.isNotEmpty) {
                                      ref.invalidate(sectionSchedulesProvider(studentSection));
                                    }
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: Icon(Icons.refresh_rounded, color: AppTheme.primary, size: 18),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Close',
                              child: Material(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: Icon(Icons.close, color: AppTheme.textMuted, size: 18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Row 2 on Mobile: Mode Selector Pill
                        Center(
                          child: _buildModalModeSelector(isMobile: isMobile),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.22),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.grid_on_rounded, color: AppTheme.primary, size: 19),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Class Timetable Schedule',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                  color: AppTheme.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 5,
                                children: [
                                  Text(
                                    'Section: ',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppTheme.primary.withValues(alpha: 0.25),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      studentSection != null && studentSection.isNotEmpty ? studentSection : 'No Section',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    ' • Visual Weekly Matrix',
                                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildModalModeSelector(),
                        const SizedBox(width: 10),
                        Tooltip(
                          message: 'Refresh Schedule',
                          child: Material(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                if (studentSection != null && studentSection.isNotEmpty) {
                                  ref.invalidate(sectionSchedulesProvider(studentSection));
                                }
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                child: Icon(Icons.refresh_rounded, color: AppTheme.primary, size: 19),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Close',
                          child: Material(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                child: Icon(Icons.close, color: AppTheme.textMuted, size: 19),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            if (_modalViewMode != StudentModalViewMode.calendar) ...[
              // ── Quick Day Jump Navigation ───────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surface.withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Jump to: ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        showCheckmark: false,
                        label: const Text('ALL (Grid)'),
                        selected: _activeDayJump == 'ALL',
                        selectedColor: AppTheme.primary,
                        backgroundColor: isDark ? AppTheme.surfaceLight : Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 10.5,
                          fontWeight: _activeDayJump == 'ALL' ? FontWeight.w700 : FontWeight.w500,
                          color: _activeDayJump == 'ALL' ? Colors.black : AppTheme.textSecondary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: _activeDayJump == 'ALL'
                                ? Colors.transparent
                                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07)),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        visualDensity: VisualDensity.compact,
                        onSelected: (val) {
                          if (val) {
                            setState(() => _activeDayJump = 'ALL');
                            if (_horizontalGridController.hasClients) {
                              _horizontalGridController.animateTo(0,
                                  duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      ...List.generate(_days.length, (idx) {
                        final day = _days[idx];
                        final lbl = _dayLabels[idx];
                        final isSel = _activeDayJump == day;
                        final isToday = day == getCurrentDayOfWeek();

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            showCheckmark: false,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(lbl),
                                if (isToday) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSel ? Colors.black : AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            selected: isSel,
                            selectedColor: AppTheme.primary,
                            backgroundColor: isDark ? AppTheme.surfaceLight : Colors.white,
                            labelStyle: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel ? Colors.black : AppTheme.textSecondary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSel
                                    ? Colors.transparent
                                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07)),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            visualDensity: VisualDensity.compact,
                            onSelected: (val) {
                              if (val) {
                                setState(() => _activeDayJump = day);
                                const colW = 130.0;
                                _scrollToDayIndex(idx, colW);
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],

            // ── Timetable Matrix Content ────────────────────────────
            Expanded(
              child: (studentSection == null || studentSection.isEmpty)
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(alpha: 0.18),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.school_outlined,
                                    size: 24,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Section Assigned',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: -0.2,
                                  color: AppTheme.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'You must be enrolled in a section to view your timetable.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ref.watch(sectionSchedulesProvider(studentSection)).when(
                        loading: () => Center(
                          child: CircularProgressIndicator(color: AppTheme.primary),
                        ),
                        error: (err, _) => Center(
                          child: Text('Error loading timetable: $err', style: TextStyle(color: AppTheme.error)),
                        ),
                        data: (schedules) {
                          if (schedules.isEmpty) {
                            return Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 380),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.08),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppTheme.primary.withValues(alpha: 0.18),
                                            width: 1.5,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.event_busy_rounded,
                                            size: 24,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No Classes Scheduled for Section $studentSection',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          letterSpacing: -0.2,
                                          color: AppTheme.text,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Teachers have not uploaded any class schedules for this section yet.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          ref.invalidate(sectionSchedulesProvider(studentSection));
                                        },
                                        icon: const Icon(Icons.refresh_rounded, size: 16),
                                        label: const Text('Refresh Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          foregroundColor: Colors.black,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          if (_modalViewMode == StudentModalViewMode.calendar) {
                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: ActualCalendarView(
                                schedules: schedules,
                                isStudent: true,
                                onScheduleTap: (c) => _showClassDetailModal(context, c, isDark),
                              ),
                            );
                          }

                          if (_modalViewMode == StudentModalViewMode.agenda) {
                            return _buildMobileAgendaView(schedules, isDark);
                          }

                          return _buildFullMatrixGrid(schedules, isDark, screenWidth);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Full Timetable Matrix Grid (Matches User's Uploaded Image) ────────────
  Widget _buildFullMatrixGrid(List<Map<String, dynamic>> schedules, bool isDark, double screenWidth) {
    const timeColWidth = 76.0;
    // On mobile, day columns have a comfortable min-width of 130px; on desktop/tablet, expand to fill
    final availableGridWidth = screenWidth > 800 ? (screenWidth - timeColWidth - 80) : (_days.length * 130.0);
    final dayColWidth = (availableGridWidth / _days.length).clamp(120.0, 220.0);
    final totalGridWidth = timeColWidth + (_days.length * dayColWidth);
    final totalGridHeight = _totalSlots * _slotHeight;

    final gridBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _horizontalGridController,
      child: SizedBox(
        width: totalGridWidth,
        child: Column(
          children: [
            // ── Sticky Header Row: TIME \ DAY | MON | TUE | WED | THU | FRI | SAT ──
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surface : const Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: AppTheme.border, width: 1.5)),
              ),
              child: Row(
                children: [
                  // TIME \ DAY cell
                  Container(
                    width: timeColWidth,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: gridBorderColor, width: 1.5)),
                    ),
                    child: Text(
                      'TIME \\ DAY',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  // Day headers
                  ...List.generate(_days.length, (idx) {
                    final dayName = _days[idx];
                    final dayLabel = _dayLabels[idx];
                    final classCount = schedules.where((s) => s['day_of_week'] == dayName).length;
                    final isToday = dayName == getCurrentDayOfWeek();

                    return Container(
                      width: dayColWidth,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday ? AppTheme.primary.withValues(alpha: 0.08) : Colors.transparent,
                        border: Border(right: BorderSide(color: gridBorderColor, width: 1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isToday ? AppTheme.primary : AppTheme.text,
                            ),
                          ),
                          if (classCount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: (isToday ? AppTheme.primary : AppTheme.textSecondary).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$classCount',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isToday ? AppTheme.primary : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // ── Grid Body: Time slots on left + Day columns on right ──
            Expanded(
              child: SingleChildScrollView(
                controller: _verticalGridController,
                child: SizedBox(
                  height: totalGridHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time Labels Column
                      SizedBox(
                        width: timeColWidth,
                        child: Column(
                          children: List.generate(_totalSlots, (slotIdx) {
                            return Container(
                              height: _slotHeight,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: gridBorderColor, width: 0.8),
                                  right: BorderSide(color: gridBorderColor, width: 1.5),
                                ),
                              ),
                              child: Text(
                                _formatSlotLabel(slotIdx),
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      // Days Columns with Class Blocks
                      ...List.generate(_days.length, (dayIdx) {
                        final dayName = _days[dayIdx];
                        final daySchedules = schedules.where((s) => s['day_of_week'] == dayName).toList();
                        final isToday = dayName == getCurrentDayOfWeek();

                        return Container(
                          width: dayColWidth,
                          height: totalGridHeight,
                          decoration: BoxDecoration(
                            color: isToday ? AppTheme.primary.withValues(alpha: 0.02) : Colors.transparent,
                            border: Border(right: BorderSide(color: gridBorderColor, width: 1)),
                          ),
                          child: Stack(
                            children: [
                              // Background Horizontal slot lines
                              Column(
                                children: List.generate(_totalSlots, (_) {
                                  return Container(
                                    height: _slotHeight,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(color: gridBorderColor, width: 0.6),
                                      ),
                                    ),
                                  );
                                }),
                              ),

                              // Positioned Class Blocks
                              ...daySchedules.map((c) {
                                final startMinutes = _parseTimeToMinutes(c['start_time'] as String?);
                                final endMinutes = _parseTimeToMinutes(c['end_time'] as String?);

                                // Clamp within grid boundaries
                                final effectiveStart = startMinutes.clamp(_gridStartMinutes, _gridEndMinutes);
                                final effectiveEnd = endMinutes.clamp(_gridStartMinutes, _gridEndMinutes);
                                final duration = (effectiveEnd - effectiveStart).clamp(20, 600);

                                final topPos = (effectiveStart - _gridStartMinutes) * (_slotHeight / _slotMinutes);
                                final blockHeight = (duration * (_slotHeight / _slotMinutes) - 2.0).clamp(26.0, 500.0);

                                final subject = c['subject_name'] as String? ?? 'Subject';
                                final teacher = c['teacher_name'] as String? ?? '';
                                final room = c['room'] as String? ?? '';
                                final hexCode = c['color_code'] as String?;
                                final color = TimetableColorPalette.getSubjectColor(subject, hexCode, isDark);
                                final isOngoing = _isOngoing(c);

                                return Positioned(
                                  top: topPos,
                                  left: 2,
                                  right: 2,
                                  height: blockHeight,
                                  child: GestureDetector(
                                    onTap: () => _showClassDetailModal(context, c, isDark),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isOngoing
                                                ? color
                                                : color.withValues(alpha: isDark ? 0.40 : 0.28),
                                            width: isOngoing ? 1.5 : 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          children: [
                                            // Halftone Card Decoration on top-right (matching Calendar view Image 1)
                                            HalftoneCardDecoration(
                                              color: color,
                                              width: 55,
                                              dotSpacing: 6.0,
                                              maxRadius: 2.8,
                                              baseOpacity: isDark ? 0.12 : 0.18,
                                            ),

                                            // Class content text
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    subject,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.text,
                                                      height: 1.15,
                                                    ),
                                                    textAlign: TextAlign.start,
                                                    maxLines: blockHeight < 48 ? 1 : 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (blockHeight >= 44 && teacher.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.person_outline_rounded,
                                                          size: 9.5,
                                                          color: AppTheme.textSecondary,
                                                        ),
                                                        const SizedBox(width: 2.5),
                                                        Flexible(
                                                          child: Text(
                                                            teacher,
                                                            style: TextStyle(
                                                              fontSize: 8.5,
                                                              fontWeight: FontWeight.w500,
                                                              color: AppTheme.textSecondary,
                                                              height: 1.1,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                  if (blockHeight >= 64 && room.isNotEmpty) ...[
                                                    const SizedBox(height: 1.5),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.meeting_room_outlined,
                                                          size: 9.5,
                                                          color: AppTheme.textSecondary,
                                                        ),
                                                        const SizedBox(width: 2.5),
                                                        Flexible(
                                                          child: Text(
                                                            room,
                                                            style: TextStyle(
                                                              fontSize: 8,
                                                              fontWeight: FontWeight.w500,
                                                              color: AppTheme.textSecondary,
                                                              height: 1.1,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mobile Agenda List View (Alternative for Quick 1-Thumb Phone Scanning) ──
  Widget _buildMobileAgendaView(List<Map<String, dynamic>> schedules, bool isDark) {
    final activeDay = _activeDayJump == 'ALL' ? getCurrentDayOfWeek() : _activeDayJump;
    final dayClasses = schedules.where((s) => s['day_of_week'] == activeDay).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$activeDay Schedule',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              Text(
                '${dayClasses.length} class(es)',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: dayClasses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_rounded, size: 40, color: AppTheme.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'No scheduled classes for $activeDay',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select another day tab above to view scheduled classes.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: dayClasses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final c = dayClasses[idx];
                      final subject = c['subject_name'] as String? ?? 'Subject';
                      final teacher = c['teacher_name'] as String? ?? 'Instructor';
                      final room = c['room'] as String? ?? 'N/A';
                      final start = c['start_time'] as String? ?? '';
                      final end = c['end_time'] as String? ?? '';
                      final hexCode = c['color_code'] as String?;
                      final color = TimetableColorPalette.getSubjectColor(subject, hexCode, isDark);
                      final isOngoing = _isOngoing(c);

                      return GestureDetector(
                        onTap: () => _showClassDetailModal(context, c, isDark),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isOngoing
                                    ? color
                                    : color.withValues(alpha: isDark ? 0.35 : 0.25),
                                width: isOngoing ? 1.5 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Halftone Card Decoration on top-right (matching Picture 1)
                                HalftoneCardDecoration(
                                  color: color,
                                  width: 90,
                                  baseOpacity: isDark ? 0.12 : 0.18,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Time block (matching Calendar View)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: color.withValues(alpha: 0.20)),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              _formatDisplayTime(start),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                              ),
                                            ),
                                            Text(
                                              'to ${_formatDisplayTime(end)}',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w500,
                                                color: color.withValues(alpha: 0.8),
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
                                              subject,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppTheme.text,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Icon(Icons.person_outline_rounded, size: 11, color: AppTheme.textSecondary),
                                                const SizedBox(width: 2.5),
                                                Flexible(
                                                  child: Text(
                                                    teacher,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppTheme.textSecondary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (room.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Icon(Icons.meeting_room_outlined, size: 11, color: AppTheme.textSecondary),
                                                  const SizedBox(width: 2),
                                                  Flexible(
                                                    child: Text(
                                                      room,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: AppTheme.textSecondary,
                                                      ),
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
                                      Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textMuted),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
