import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/calendar/actual_calendar_view.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../data/teacher_repository.dart';
import '../data/teacher_schedule_repository.dart';
import 'components/halftone_pattern.dart';

enum ScheduleViewMode { grid, calendar, agenda }

class TeacherScheduleScreen extends ConsumerStatefulWidget {
  const TeacherScheduleScreen({super.key});

  @override
  ConsumerState<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends ConsumerState<TeacherScheduleScreen> {
  String _selectedDay = 'All Days';
  String _selectedSection = 'All Handled Sections';
  ScheduleViewMode _viewMode = ScheduleViewMode.grid;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherSchedulesProvider.notifier).reload();
    });
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

  bool _isClassOngoing(Map<String, dynamic> sched) {
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

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    AppTheme.setDark(isDark);
    final schedules = ref.watch(teacherSchedulesProvider);
    final sectionsAsync = ref.watch(teacherHandledSectionsProvider);
    final sections = sectionsAsync.value ?? [];

    final filtered = schedules.where((s) {
      if (_viewMode != ScheduleViewMode.calendar &&
          _selectedDay != 'All Days' &&
          s['day_of_week'] != _selectedDay) {
        return false;
      }
      if (_selectedSection != 'All Handled Sections' &&
          (s['section_name'] as String?)?.toLowerCase().trim() != _selectedSection.toLowerCase().trim()) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(teacherSchedulesProvider.notifier).reload();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Title and Add Button
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 640;

                    final headerTextColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _viewMode == ScheduleViewMode.calendar
                                    ? 'MONTHLY CALENDAR'
                                    : 'WEEKLY TIMETABLE',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.tealAccent.withValues(alpha: 0.15)
                                    : Colors.teal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${filtered.length} Scheduled',
                                style: TextStyle(
                                  color: isDark ? Colors.tealAccent : Colors.teal,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFFA855F7).withValues(alpha: 0.15)
                                    : Colors.purple.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Admin Assigned',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFA855F7) : Colors.purple,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _viewMode == ScheduleViewMode.calendar
                              ? 'Interactive Calendar'
                              : 'Class Schedule & Timetable',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _viewMode == ScheduleViewMode.calendar
                              ? 'Browse class schedule by calendar days, view daily hours, and check active classes'
                              : 'View your assigned weekly class hours, section schedules, and classroom allocations',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    );

                    final actionButtons = Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            iconSize: 18,
                            tooltip: 'Weekly Timetable Grid',
                            icon: Icon(
                              Icons.grid_view_rounded,
                              color: _viewMode == ScheduleViewMode.grid ? AppTheme.primary : AppTheme.textMuted,
                            ),
                            onPressed: () => setState(() => _viewMode = ScheduleViewMode.grid),
                          ),
                          IconButton(
                            iconSize: 18,
                            tooltip: 'Monthly Calendar Mode',
                            icon: Icon(
                              Icons.calendar_month_rounded,
                              color: _viewMode == ScheduleViewMode.calendar ? AppTheme.primary : AppTheme.textMuted,
                            ),
                            onPressed: () => setState(() => _viewMode = ScheduleViewMode.calendar),
                          ),
                          IconButton(
                            iconSize: 18,
                            tooltip: 'Agenda Timeline List',
                            icon: Icon(
                              Icons.view_agenda_outlined,
                              color: _viewMode == ScheduleViewMode.agenda ? AppTheme.primary : AppTheme.textMuted,
                            ),
                            onPressed: () => setState(() => _viewMode = ScheduleViewMode.agenda),
                          ),
                        ],
                      ),
                    );

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          headerTextColumn,
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: actionButtons,
                          ),
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: headerTextColumn),
                        const SizedBox(width: 16),
                        actionButtons,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Filter Row (Days of Week + Handled Section selector)
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_viewMode != ScheduleViewMode.calendar)
                      // Day Selector Chips
                      ..._days.map((day) {
                        final isSel = _selectedDay == day;
                        return ChoiceChip(
                          label: Text(day),
                          selected: isSel,
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: isSel
                                ? (isDark ? const Color(0xFF0A1420) : Colors.white)
                                : AppTheme.text,
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          ),
                          backgroundColor: AppTheme.surface,
                          side: BorderSide(
                            color: isSel ? AppTheme.primary : AppTheme.border,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedDay = day);
                            }
                          },
                        );
                      }),

                    // Section Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSection,
                          dropdownColor: AppTheme.surface,
                          style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w600),
                          items: [
                            'All Handled Sections',
                            ...sections,
                          ].map((sec) {
                            return DropdownMenuItem<String>(
                              value: sec,
                              child: Text(sec),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSection = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Schedules Display Area
                if (filtered.isEmpty)
                  _buildEmptyState()
                else if (_viewMode == ScheduleViewMode.calendar)
                  ActualCalendarView(
                    schedules: filtered,
                    isTeacher: true,
                  )
                else if (_viewMode == ScheduleViewMode.grid)
                  _buildTimetableGrid(filtered)
                else
                  _buildAgendaList(filtered),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.calendar_today_outlined, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              'No class schedules found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.text),
            ),
            const SizedBox(height: 6),
            Text(
              'No classes match your active filters. Your schedule is maintained and assigned by school administration.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableGrid(List<Map<String, dynamic>> schedules) {
    // If "All Days" is selected, group by day
    final daysToDisplay = _selectedDay == 'All Days'
        ? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
        : [_selectedDay];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: daysToDisplay.map((day) {
        final daySchedules = schedules.where((s) => s['day_of_week'] == day).toList();
        if (_selectedDay == 'All Days' && daySchedules.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 18,
                      color: day == getCurrentDayOfWeek() ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: day == getCurrentDayOfWeek() ? AppTheme.primary : AppTheme.text,
                      ),
                    ),
                    if (day == getCurrentDayOfWeek()) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'TODAY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${daySchedules.length} Classes',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),

              // Cards Grid
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: daySchedules.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No classes scheduled for $day',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth >= 900
                              ? 3
                              : constraints.maxWidth >= 550
                                  ? 2
                                  : 1;

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: daySchedules.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 1.8,
                            ),
                            itemBuilder: (context, index) {
                              return _buildScheduleCard(daySchedules[index]);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> sched) {
    final subject = sched['subject_name'] as String? ?? 'Subject';
    final section = sched['section_name'] as String? ?? 'Section';
    final room = sched['room'] as String?;
    final startTime = _formatDisplayTime(sched['start_time'] as String?);
    final endTime = _formatDisplayTime(sched['end_time'] as String?);
    final color = _parseColor(sched['color_code'] as String?, AppTheme.primary);
    final isOngoing = _isClassOngoing(sched);
    final isDark = AppTheme.isDark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOngoing ? color : color.withValues(alpha: isDark ? 0.35 : 0.25),
            width: isOngoing ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.08 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Halftone Dot Matrix Accent (Replaces AI slop vertical bar)
            HalftoneCardDecoration(
              color: color,
              width: 140,
              baseOpacity: isDark ? 0.18 : 0.28,
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top row: Section Badge + Ongoing Indicator + Admin Assigned pill
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.25)),
                        ),
                        child: Text(
                          section,
                          style: TextStyle(
                            color: isDark ? Color.lerp(color, Colors.white, 0.25) : color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isOngoing) ...[
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
                                'ONGOING',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.background.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_clock_outlined, size: 10, color: AppTheme.textMuted),
                            const SizedBox(width: 3),
                            Text('Assigned', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Subject Title
                  Text(
                    subject,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Bottom row: Time + Room
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$startTime - $endTime',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (room != null && room.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.room_outlined, size: 14, color: AppTheme.textMuted),
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
  }

  Widget _buildAgendaList(List<Map<String, dynamic>> schedules) {
    final isDark = AppTheme.isDark;
    return Column(
      children: schedules.map((sched) {
        final subject = sched['subject_name'] as String? ?? 'Subject';
        final section = sched['section_name'] as String? ?? 'Section';
        final day = sched['day_of_week'] as String? ?? '';
        final room = sched['room'] as String?;
        final startTime = _formatDisplayTime(sched['start_time'] as String?);
        final endTime = _formatDisplayTime(sched['end_time'] as String?);
        final color = _parseColor(sched['color_code'] as String?, AppTheme.primary);
        final isOngoing = _isClassOngoing(sched);

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isOngoing ? color : color.withValues(alpha: isDark ? 0.35 : 0.25),
                width: isOngoing ? 1.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                // Subtle Halftone Accent on Agenda card
                HalftoneCardDecoration(
                  color: color,
                  width: 90,
                  baseOpacity: isDark ? 0.12 : 0.18,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Time & Day Block
                      Container(
                        width: 82,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: day == getCurrentDayOfWeek() ? AppTheme.primary : AppTheme.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              startTime,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.text),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'to $endTime',
                              style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Subject & Info
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
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.text,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isOngoing) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'LIVE',
                                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.success),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: color.withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      section,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                if (room != null && room.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.meeting_room_outlined, size: 12, color: AppTheme.textSecondary),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      room,
                                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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

                      // Admin Assigned Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_clock_outlined, size: 12, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              'Assigned',
                              style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
