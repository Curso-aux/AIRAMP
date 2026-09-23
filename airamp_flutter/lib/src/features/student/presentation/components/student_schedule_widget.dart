import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../teacher/data/teacher_schedule_repository.dart';

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
  static const List<Map<String, Color>> lightPalettes = [
    // Pastel Blue (like BA-3102 in user image)
    {
      'bg': Color(0xFFE8F0FE),
      'border': Color(0xFF3B82F6),
      'text': Color(0xFF1E40AF),
    },
    // Pastel Purple (like IT 3116 in user image)
    {
      'bg': Color(0xFFF3E8FF),
      'border': Color(0xFF8B5CF6),
      'text': Color(0xFF581C87),
    },
    // Pastel Coral / Pink (like CC 3105 in user image)
    {
      'bg': Color(0xFFFFE4E6),
      'border': Color(0xFFF43F5E),
      'text': Color(0xFF9F1239),
    },
    // Pastel Mint / Green (like IT 3114 in user image)
    {
      'bg': Color(0xFFDCFCE7),
      'border': Color(0xFF10B981),
      'text': Color(0xFF065F46),
    },
    // Pastel Peach / Orange (like IT 3115 in user image)
    {
      'bg': Color(0xFFFEF3C7),
      'border': Color(0xFFF59E0B),
      'text': Color(0xFF92400E),
    },
    // Pastel Cyan
    {
      'bg': Color(0xFFCCFBF1),
      'border': Color(0xFF06B6D4),
      'text': Color(0xFF155E75),
    },
  ];

  static Map<String, Color> getColors(String subjectName, String? hexColor, bool isDark) {
    if (hexColor != null && hexColor.isNotEmpty) {
      try {
        final hex = hexColor.replaceAll('#', '');
        final base = Color(int.parse('FF$hex', radix: 16));
        if (isDark) {
          return {
            'bg': base.withValues(alpha: 0.22),
            'border': base,
            'text': Colors.white,
          };
        } else {
          return {
            'bg': base.withValues(alpha: 0.14),
            'border': base,
            'text': Color.lerp(base, Colors.black, 0.45) ?? base,
          };
        }
      } catch (_) {}
    }

    final index = (subjectName.hashCode.abs()) % lightPalettes.length;
    final p = lightPalettes[index];
    if (isDark) {
      final border = p['border']!;
      return {
        'bg': border.withValues(alpha: 0.22),
        'border': border,
        'text': Colors.white,
      };
    }
    return p;
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
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_outlined, color: Colors.amber, size: 24),
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
        // Section Header with Student's assigned Section badge and Timetable button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
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
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Class Schedule",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Text(
                              "Section: ",
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Prominent Full Timetable Button
            ElevatedButton.icon(
              onPressed: () => _openTimetableModal(context),
              icon: const Icon(Icons.grid_view_rounded, size: 14),
              label: const Text('Timetable Grid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                Text(
                  'Loading your schedule...',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event_note_rounded, color: Colors.blue, size: 22),
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
                            'You have ${allSchedules.length} class(es) scheduled this week for Section $studentSection.',
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
  bool _isMobileAgendaView = false;

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

  void _showClassDetailModal(BuildContext context, Map<String, dynamic> c, bool isDark) {
    final subject = c['subject_name'] as String? ?? 'Subject';
    final teacher = c['teacher_name'] as String? ?? 'Instructor';
    final room = c['room'] as String? ?? 'N/A';
    final day = c['day_of_week'] as String? ?? '';
    final start = c['start_time'] as String? ?? '';
    final end = c['end_time'] as String? ?? '';
    final hexCode = c['color_code'] as String?;
    final colors = TimetableColorPalette.getColors(subject, hexCode, isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: colors['border'], shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subject,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors['bg'],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors['border']!),
                  ),
                  child: Text(
                    day,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors['text']),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.access_time_rounded, 'Class Time', '$start - $end'),
            const SizedBox(height: 10),
            _buildDetailRow(Icons.person_pin_rounded, 'Teacher', teacher),
            const SizedBox(height: 10),
            _buildDetailRow(Icons.meeting_room_outlined, 'Room / Lab', room),
            const SizedBox(height: 10),
            _buildDetailRow(Icons.school_outlined, 'Assigned Section', widget.sectionName ?? 'N/A'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),
        ),
      ],
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
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          children: [
            // ── Top Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: const BorderSide(color: Color(0xFF10B981), width: 3), // Green accent line like screenshot
                  bottom: BorderSide(color: AppTheme.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.grid_on_rounded, color: AppTheme.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Class Timetable Schedule',
                          style: TextStyle(
                            fontSize: isMobile ? 15 : 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                        Row(
                          children: [
                            Text('Section: ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
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
                            if (!isMobile) ...[
                              Text(' • Visual Weekly Matrix', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isMobile) ...[
                    // Mobile Toggle: Grid vs Agenda
                    IconButton(
                      tooltip: _isMobileAgendaView ? 'Switch to Full Matrix Grid' : 'Switch to Agenda List',
                      icon: Icon(
                        _isMobileAgendaView ? Icons.grid_view_rounded : Icons.view_agenda_outlined,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _isMobileAgendaView = !_isMobileAgendaView),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Refresh Schedule',
                    icon: Icon(Icons.refresh_rounded, color: AppTheme.primary, size: 20),
                    onPressed: () {
                      if (studentSection != null && studentSection.isNotEmpty) {
                        ref.invalidate(sectionSchedulesProvider(studentSection));
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Quick Day Jump Navigation ───────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.background.withValues(alpha: 0.5),
                border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text('Jump to: ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('ALL (Grid)'),
                      selected: _activeDayJump == 'ALL',
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        fontSize: 10,
                        fontWeight: _activeDayJump == 'ALL' ? FontWeight.bold : FontWeight.normal,
                        color: _activeDayJump == 'ALL' ? Colors.black : AppTheme.text,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
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

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(lbl),
                          selected: isSel,
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            fontSize: 10,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? Colors.black : AppTheme.text,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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

            // ── Timetable Matrix Content ────────────────────────────
            Expanded(
              child: (studentSection == null || studentSection.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school_outlined, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'No Section Assigned',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.text),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You must be enrolled in a section to view your timetable.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
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
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy_rounded, size: 48, color: AppTheme.textMuted),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No Classes Scheduled for Section $studentSection',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.text),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Teachers have not uploaded any class schedules for this section yet.',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 16),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (_isMobileAgendaView) {
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
                                final colors = TimetableColorPalette.getColors(subject, hexCode, isDark);

                                return Positioned(
                                  top: topPos,
                                  left: 2,
                                  right: 2,
                                  height: blockHeight,
                                  child: GestureDetector(
                                    onTap: () => _showClassDetailModal(context, c, isDark),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: colors['bg'],
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: colors['border']!, width: 1.2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            subject,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: colors['text'],
                                              height: 1.1,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (blockHeight >= 44 && teacher.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              teacher,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w500,
                                                color: colors['text']!.withValues(alpha: 0.85),
                                                height: 1.1,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (blockHeight >= 62 && room.isNotEmpty) ...[
                                            const SizedBox(height: 1),
                                            Text(
                                              room,
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w500,
                                                color: colors['text']!.withValues(alpha: 0.75),
                                                height: 1.1,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
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
                      final colors = TimetableColorPalette.getColors(subject, hexCode, isDark);

                      return GestureDetector(
                        onTap: () => _showClassDetailModal(context, c, isDark),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors['bg'],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors['border']!, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: colors['border']!.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      start,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: colors['text'],
                                      ),
                                    ),
                                    Text(
                                      end,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: colors['text']!.withValues(alpha: 0.8),
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
                                        color: colors['text'],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$teacher • Room: $room',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors['text']!.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: colors['border']),
                            ],
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
