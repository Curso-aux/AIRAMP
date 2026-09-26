import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../../features/teacher/presentation/components/halftone_pattern.dart';

/// Reusable, interactive "Actual Calendar" view for AIRAMP.
/// Works seamlessly across Student, Teacher, and Admin portals.
class ActualCalendarView extends StatefulWidget {
  final List<Map<String, dynamic>> schedules;
  final DateTime? initialDate;
  final bool isTeacher;
  final bool isAdmin;
  final bool isStudent;
  final void Function(Map<String, dynamic> schedule)? onScheduleTap;
  final void Function(Map<String, dynamic> schedule)? onEditSchedule;
  final void Function(Map<String, dynamic> schedule)? onDeleteSchedule;
  final VoidCallback? onAddSchedule;
  final String? emptySubtitle;

  const ActualCalendarView({
    super.key,
    required this.schedules,
    this.initialDate,
    this.isTeacher = false,
    this.isAdmin = false,
    this.isStudent = false,
    this.onScheduleTap,
    this.onEditSchedule,
    this.onDeleteSchedule,
    this.onAddSchedule,
    this.emptySubtitle,
  });

  @override
  State<ActualCalendarView> createState() => _ActualCalendarViewState();
}

class _ActualCalendarViewState extends State<ActualCalendarView> {
  late DateTime _displayedMonth;
  late DateTime _selectedDate;

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = widget.initialDate ?? DateTime(now.year, now.month, now.day);
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  void _goToPreviousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
      _displayedMonth = DateTime(now.year, now.month, 1);
    });
  }

  String _getDayOfWeekName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday: return 'Monday';
      case DateTime.tuesday: return 'Tuesday';
      case DateTime.wednesday: return 'Wednesday';
      case DateTime.thursday: return 'Thursday';
      case DateTime.friday: return 'Friday';
      case DateTime.saturday: return 'Saturday';
      case DateTime.sunday: return 'Sunday';
      default: return '';
    }
  }

  List<Map<String, dynamic>> _getSchedulesForDate(DateTime date) {
    final dayName = _getDayOfWeekName(date).toLowerCase();
    final matches = widget.schedules.where((s) {
      final schedDay = (s['day_of_week'] as String?)?.trim().toLowerCase();
      return schedDay == dayName;
    }).toList();

    matches.sort((a, b) {
      final aTime = a['start_time'] as String? ?? '00:00';
      final bTime = b['start_time'] as String? ?? '00:00';
      return aTime.compareTo(bTime);
    });

    return matches;
  }

  bool _isClassOngoing(Map<String, dynamic> sched, DateTime date) {
    final now = DateTime.now();
    if (date.year != now.year || date.month != now.month || date.day != now.day) {
      return false;
    }
    final schedDay = sched['day_of_week'] as String?;
    if (schedDay == null || schedDay.toLowerCase() != _getDayOfWeekName(now).toLowerCase()) {
      return false;
    }

    final nowMinutes = now.hour * 60 + now.minute;
    final startParts = (sched['start_time'] as String? ?? '').split(':');
    final endParts = (sched['end_time'] as String? ?? '').split(':');
    if (startParts.length < 2 || endParts.length < 2) return false;

    final startMinutes = int.tryParse(startParts[0]) ?? 0;
    final startMinPart = int.tryParse(startParts[1]) ?? 0;
    final endMinutes = int.tryParse(endParts[0]) ?? 0;
    final endMinPart = int.tryParse(endParts[1]) ?? 0;

    final totalStart = startMinutes * 60 + startMinPart;
    final totalEnd = endMinutes * 60 + endMinPart;

    return nowMinutes >= totalStart && nowMinutes < totalEnd;
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

  String _calculateDuration(String? start, String? end) {
    if (start == null || end == null || !start.contains(':') || !end.contains(':')) return '';
    try {
      final sParts = start.split(':');
      final eParts = end.split(':');
      final sMin = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
      final eMin = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
      final diff = eMin - sMin;
      if (diff <= 0) return '';
      final hours = diff ~/ 60;
      final mins = diff % 60;
      if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
      if (hours > 0) return '${hours}h';
      return '${mins}m';
    } catch (_) {
      return '';
    }
  }

  Color _getSubjectColor(String subjectName, String? hexColor, bool isDark) {
    if (hexColor != null && hexColor.isNotEmpty) {
      try {
        final hex = hexColor.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    const fallbackPalette = [
      Color(0xFF10B981), // Emerald
      Color(0xFF3B82F6), // Blue
      Color(0xFF8B5CF6), // Purple
      Color(0xFFF59E0B), // Amber
      Color(0xFFEC4899), // Pink
      Color(0xFF06B6D4), // Cyan
      Color(0xFFF97316), // Orange
    ];
    return fallbackPalette[subjectName.hashCode.abs() % fallbackPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    AppTheme.setDark(isDark);
    final selectedDaySchedules = _getSchedulesForDate(_selectedDate);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 780;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Calendar Card
              SizedBox(
                width: 380,
                child: _buildCalendarCard(isDark),
              ),
              const SizedBox(width: 20),
              // Right Column: Day Schedule Breakdown
              Expanded(
                child: _buildDaySchedulePanel(selectedDaySchedules, isDark),
              ),
            ],
          );
        }

        // Mobile / Compact Layout: Stacked
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalendarCard(isDark),
            const SizedBox(height: 20),
            _buildDaySchedulePanel(selectedDaySchedules, isDark),
          ],
        );
      },
    );
  }

  Widget _buildCalendarCard(bool isDark) {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    final monthName = _monthNames[month - 1];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final totalDaysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayWeekday = DateTime(year, month, 1).weekday; // 1 = Monday, 7 = Sunday
    final startOffset = firstDayWeekday % 7; // Sunday = 0
    final prevMonthTotalDays = DateTime(year, month, 0).day;

    final totalCells = (startOffset + totalDaysInMonth > 35) ? 42 : 35;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Header Bar with Prev/Next and Today
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$monthName $year',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_getDayOfWeekName(_selectedDate)}, ${_monthNames[_selectedDate.month - 1].substring(0, 3)} ${_selectedDate.day}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Today Button
              InkWell(
                onTap: _goToToday,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.today_rounded, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Prev Month
              InkWell(
                onTap: _goToPreviousMonth,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Icon(Icons.chevron_left_rounded, size: 18, color: AppTheme.text),
                ),
              ),
              const SizedBox(width: 6),
              // Next Month
              InkWell(
                onTap: _goToNextMonth,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Weekday Labels Row
          Row(
            children: _weekdays.map((day) {
              final isWeekend = day == 'Sun' || day == 'Sat';
              return Expanded(
                child: Center(
                  child: Text(
                    day.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isWeekend
                          ? AppTheme.textMuted
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              DateTime cellDate;
              bool isCurrentMonth = false;

              if (index < startOffset) {
                final dayNum = prevMonthTotalDays - startOffset + 1 + index;
                cellDate = DateTime(year, month - 1, dayNum);
              } else if (index < startOffset + totalDaysInMonth) {
                final dayNum = index - startOffset + 1;
                cellDate = DateTime(year, month, dayNum);
                isCurrentMonth = true;
              } else {
                final dayNum = index - (startOffset + totalDaysInMonth) + 1;
                cellDate = DateTime(year, month + 1, dayNum);
              }

              final isSelected = cellDate.year == _selectedDate.year &&
                  cellDate.month == _selectedDate.month &&
                  cellDate.day == _selectedDate.day;

              final isToday = cellDate.year == today.year &&
                  cellDate.month == today.month &&
                  cellDate.day == today.day;

              final cellSchedules = _getSchedulesForDate(cellDate);
              final hasClasses = cellSchedules.isNotEmpty;
              final hasOngoing = cellSchedules.any((s) => _isClassOngoing(s, cellDate));

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = cellDate;
                    if (!isCurrentMonth) {
                      _displayedMonth = DateTime(cellDate.year, cellDate.month, 1);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : (isToday
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : (isDark ? Colors.transparent : Colors.transparent)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : (isToday
                              ? AppTheme.primary.withValues(alpha: 0.6)
                              : Colors.transparent),
                      width: isToday ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Day Number
                      Text(
                        '${cellDate.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: (isSelected || isToday)
                              ? FontWeight.bold
                              : (isCurrentMonth ? FontWeight.w600 : FontWeight.normal),
                          color: isSelected
                              ? (isDark ? const Color(0xFF0A1420) : Colors.white)
                              : (isCurrentMonth
                                  ? AppTheme.text
                                  : AppTheme.textMuted.withValues(alpha: 0.4)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Class dots / indicators
                      if (hasClasses)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasOngoing)
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              )
                            else
                              ...cellSchedules.take(3).map((sched) {
                                final color = _getSubjectColor(
                                  sched['subject_name'] as String? ?? '',
                                  sched['color_code'] as String?,
                                  isDark,
                                );
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : color,
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }),
                            if (cellSchedules.length > 3)
                              Text(
                                '+',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppTheme.primary,
                                ),
                              ),
                          ],
                        )
                      else
                        const SizedBox(height: 5),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Legend Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('Ongoing Class', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('Scheduled', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primary, width: 1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text('Today', style: TextStyle(fontSize: 8, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySchedulePanel(List<Map<String, dynamic>> schedules, bool isDark) {
    final now = DateTime.now();
    final isSelectedToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final dayOfWeek = _getDayOfWeekName(_selectedDate);
    final formattedDate = '${_monthNames[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.event_available_rounded, size: 20, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dayOfWeek,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                        if (isSelectedToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'TODAY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              // Class count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceLight : AppTheme.lightSurfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  '${schedules.length} ${schedules.length == 1 ? 'Class' : 'Classes'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              if (widget.onAddSchedule != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Assign Class Schedule',
                  icon: Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
                  onPressed: widget.onAddSchedule,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Schedules List or Empty State
          if (schedules.isEmpty)
            _buildDayEmptyState(dayOfWeek)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: schedules.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final sched = schedules[index];
                return _buildScheduleItemCard(sched, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDayEmptyState(String dayOfWeek) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              'No Classes on $dayOfWeek',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.emptySubtitle ?? 'There are no recurring class schedules assigned for this day of the week.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            if (widget.onAddSchedule != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: widget.onAddSchedule,
                icon: const Icon(Icons.add, size: 16),
                label: Text('Assign Class on $dayOfWeek'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItemCard(Map<String, dynamic> sched, bool isDark) {
    final subject = sched['subject_name'] as String? ?? 'Subject';
    final section = sched['section_name'] as String? ?? '';
    final teacher = sched['teacher_name'] as String? ?? '';
    final room = sched['room'] as String? ?? '';
    final start = sched['start_time'] as String? ?? '';
    final end = sched['end_time'] as String? ?? '';
    final hexCode = sched['color_code'] as String?;
    final color = _getSubjectColor(subject, hexCode, isDark);
    final isOngoing = _isClassOngoing(sched, _selectedDate);

    final now = DateTime.now();
    final isSelectedToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final dayOfWeek = _getDayOfWeekName(_selectedDate);

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
            // Halftone Card Decoration on top-right
            HalftoneCardDecoration(
              color: color,
              width: 90,
              baseOpacity: isDark ? 0.12 : 0.18,
            ),
            InkWell(
              onTap: () => widget.onScheduleTap?.call(sched),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Time & Day Block (matching Agenda View / Picture 2)
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
                            dayOfWeek,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelectedToday ? AppTheme.primary : AppTheme.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatDisplayTime(start),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'to ${_formatDisplayTime(end)}',
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
                              if (section.isNotEmpty)
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
                              if (room.isNotEmpty) ...[
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
                              if (!widget.isTeacher && teacher.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.person_outline_rounded, size: 12, color: AppTheme.textSecondary),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    teacher,
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

                    // Right side: Assigned pill & Admin action buttons
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
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
                        if (widget.isAdmin && (widget.onEditSchedule != null || widget.onDeleteSchedule != null)) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onEditSchedule != null)
                                IconButton(
                                  iconSize: 16,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Edit Schedule',
                                  icon: Icon(Icons.edit_outlined, color: AppTheme.primary),
                                  onPressed: () => widget.onEditSchedule!(sched),
                                ),
                              if (widget.onDeleteSchedule != null) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  iconSize: 16,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Delete Schedule',
                                  icon: Icon(Icons.delete_outline, color: AppTheme.error),
                                  onPressed: () => widget.onDeleteSchedule!(sched),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text, Color accentColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accentColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }
}
