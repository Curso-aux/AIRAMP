import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/calendar/actual_calendar_view.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../student/presentation/components/student_schedule_widget.dart';
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

  static const List<Map<String, String>> _dayOptions = [
    {'label': 'All', 'full': 'All Days'},
    {'label': 'Mon', 'full': 'Monday'},
    {'label': 'Tue', 'full': 'Tuesday'},
    {'label': 'Wed', 'full': 'Wednesday'},
    {'label': 'Thu', 'full': 'Thursday'},
    {'label': 'Fri', 'full': 'Friday'},
    {'label': 'Sat', 'full': 'Saturday'},
  ];

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

  // Grid Configuration for Timetable Matrix: 7:00 AM to 9:00 PM (30 min slots)
  static const int _gridStartMinutes = 420; // 07:00 AM
  static const int _gridEndMinutes = 1260; // 09:00 PM
  static const double _slotHeight = 38.0;
  static const int _slotMinutes = 30;
  static const int _totalSlots = (_gridEndMinutes - _gridStartMinutes) ~/ _slotMinutes; // 28 slots

  final ScrollController _headerHorizontalController = ScrollController();
  final ScrollController _bodyHorizontalController = ScrollController();
  final ScrollController _verticalGridController = ScrollController();
  final ScrollController _timeColVerticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Synchronize horizontal scrolling between Day header and Matrix body
    _bodyHorizontalController.addListener(() {
      if (_headerHorizontalController.hasClients &&
          (_headerHorizontalController.offset - _bodyHorizontalController.offset).abs() > 0.5) {
        _headerHorizontalController.jumpTo(_bodyHorizontalController.offset);
      }
    });

    _headerHorizontalController.addListener(() {
      if (_bodyHorizontalController.hasClients &&
          (_bodyHorizontalController.offset - _headerHorizontalController.offset).abs() > 0.5) {
        _bodyHorizontalController.jumpTo(_headerHorizontalController.offset);
      }
    });

    // Synchronize vertical scrolling between Time column and Days grid
    _verticalGridController.addListener(() {
      if (_timeColVerticalController.hasClients &&
          (_timeColVerticalController.offset - _verticalGridController.offset).abs() > 0.5) {
        _timeColVerticalController.jumpTo(_verticalGridController.offset);
      }
    });

    _timeColVerticalController.addListener(() {
      if (_verticalGridController.hasClients &&
          (_verticalGridController.offset - _timeColVerticalController.offset).abs() > 0.5) {
        _verticalGridController.jumpTo(_timeColVerticalController.offset);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherSchedulesProvider.notifier).reload();
    });
  }

  @override
  void dispose() {
    _headerHorizontalController.dispose();
    _bodyHorizontalController.dispose();
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
    if (schedDay == null || schedDay.toLowerCase() != getCurrentDayOfWeek().toLowerCase()) return false;

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final startMinutes = _parseTimeToMinutes(sched['start_time'] as String?);
    final endMinutes = _parseTimeToMinutes(sched['end_time'] as String?);
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  void _scrollToDay(String dayName) {
    final idx = _days.indexWhere((d) => d.toLowerCase() == dayName.toLowerCase());
    if (idx >= 0 && _bodyHorizontalController.hasClients) {
      const colWidth = 110.0;
      final target = idx * colWidth;
      _bodyHorizontalController.animateTo(
        target.clamp(0.0, _bodyHorizontalController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
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
          _viewMode != ScheduleViewMode.grid &&
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Symmetrically Balanced Top Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              _viewMode == ScheduleViewMode.calendar
                                  ? 'Calendar'
                                  : (_viewMode == ScheduleViewMode.grid
                                      ? 'Timetable Grid'
                                      : 'Class Schedule'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                                letterSpacing: -0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${filtered.length} Classes',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: isDark ? 0.2 : 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Admin Assigned',
                                style: TextStyle(
                                  color: Colors.purple,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _viewMode == ScheduleViewMode.calendar
                              ? 'Monthly overview & class times'
                              : 'Assigned weekly hours & section timetable',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Anchored Top-Right View Switcher
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildViewIcon(
                          icon: Icons.grid_view_rounded,
                          mode: ScheduleViewMode.grid,
                          tooltip: 'Timetable Grid',
                        ),
                        _buildViewIcon(
                          icon: Icons.calendar_month_rounded,
                          mode: ScheduleViewMode.calendar,
                          tooltip: 'Monthly Calendar',
                        ),
                        _buildViewIcon(
                          icon: Icons.view_agenda_outlined,
                          mode: ScheduleViewMode.agenda,
                          tooltip: 'Agenda Timeline',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter Bar (Section Selector + Single-line Day Strip)
              if (_viewMode != ScheduleViewMode.calendar) ...[
                Row(
                  children: [
                    _buildSectionDropdown(sections),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _dayOptions.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final dayItem = _dayOptions[index];
                            final isSel = _selectedDay == dayItem['full'];
                            final isToday = dayItem['full'] == getCurrentDayOfWeek();

                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _selectedDay = dayItem['full']!);
                                if (_viewMode == ScheduleViewMode.grid) {
                                  if (dayItem['full'] == 'All Days') {
                                    if (_bodyHorizontalController.hasClients) {
                                      _bodyHorizontalController.animateTo(
                                        0.0,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                  } else {
                                    _scrollToDay(dayItem['full']!);
                                  }
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? AppTheme.primary : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel
                                        ? AppTheme.primary
                                        : (isToday
                                            ? AppTheme.primary.withValues(alpha: 0.5)
                                            : AppTheme.border),
                                  ),
                                ),
                                child: Text(
                                  dayItem['label']!,
                                  style: TextStyle(
                                    color: isSel
                                        ? (isDark ? const Color(0xFF0A1420) : Colors.white)
                                        : (isToday ? AppTheme.primary : AppTheme.text),
                                    fontSize: 12,
                                    fontWeight: isSel || isToday ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ] else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildSectionDropdown(sections),
                ),
                const SizedBox(height: 12),
              ],

              // Schedules Display Area: Expands to cover viewport
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: _buildEmptyState())
                    : (_viewMode == ScheduleViewMode.calendar
                        ? ActualCalendarView(
                            schedules: filtered,
                            isTeacher: true,
                            emptySubtitle: 'No assigned class schedules found.',
                            onScheduleTap: (sched) => _showClassDetailModal(context, sched, isDark),
                          )
                        : (_viewMode == ScheduleViewMode.grid
                            ? _buildTimetableGridMatrix(filtered, isDark)
                            : RefreshIndicator(
                                onRefresh: () async {
                                  await ref.read(teacherSchedulesProvider.notifier).reload();
                                },
                                child: SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: _buildAgendaList(filtered),
                                ),
                              ))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewIcon({
    required IconData icon,
    required ScheduleViewMode mode,
    required String tooltip,
  }) {
    final isSelected = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _viewMode = mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDropdown(List<String> sections) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSection,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.textSecondary),
          dropdownColor: AppTheme.surface,
          style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w600),
          items: ['All Handled Sections', ...sections].map((sec) {
            final isAll = sec == 'All Handled Sections';
            return DropdownMenuItem<String>(
              value: sec,
              child: Text(
                isAll ? 'All Sections' : sec,
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              HapticFeedback.lightImpact();
              setState(() => _selectedSection = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasActiveFilter = _selectedDay != 'All Days' || _selectedSection != 'All Handled Sections';
    final isDark = AppTheme.isDark;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AppEmptyState(
        icon: hasActiveFilter ? Icons.filter_alt_off_outlined : Icons.calendar_today_outlined,
        title: hasActiveFilter ? 'No Matching Schedules Found' : 'No Class Schedules Assigned',
        message: hasActiveFilter
            ? 'No classes match your active day or section filters. Tap below to clear filters and show all classes.'
            : 'Your schedule is maintained and assigned by school administration.',
        actionLabel: hasActiveFilter ? 'Reset Filters' : 'Refresh Schedule',
        actionIcon: hasActiveFilter ? Icons.clear_all_rounded : Icons.refresh_rounded,
        onAction: () {
          if (hasActiveFilter) {
            setState(() {
              _selectedDay = 'All Days';
              _selectedSection = 'All Handled Sections';
            });
          } else {
            ref.read(teacherSchedulesProvider.notifier).reload();
          }
        },
      ),
    );
  }

  /// Weekly Timetable Matrix with Clean Card Surface & Soft Halftone (matching Student schedule matrix)
  Widget _buildTimetableGridMatrix(List<Map<String, dynamic>> schedules, bool isDark) {
    const double colWidth = 110.0;
    const double timeColWidth = 54.0;
    const double headerHeight = 36.0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // Header Row with Time anchor + Day columns
          Row(
            children: [
              Container(
                width: timeColWidth,
                height: headerHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.inputBg,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(13)),
                  border: Border(
                    right: BorderSide(color: AppTheme.border),
                    bottom: BorderSide(color: AppTheme.border),
                  ),
                ),
                child: Text(
                  'TIME',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerHorizontalController,
                  physics: const ClampingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _dayLabels.map((lbl) {
                      final dayIndex = _dayLabels.indexOf(lbl);
                      final fullDay = _days[dayIndex];
                      final isToday = fullDay.toLowerCase() == getCurrentDayOfWeek().toLowerCase();
                      final isHighlighted = _selectedDay == fullDay;

                      return Container(
                        width: colWidth,
                        height: headerHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? AppTheme.primary.withValues(alpha: 0.12)
                              : (isToday ? AppTheme.primary.withValues(alpha: 0.05) : AppTheme.inputBg),
                          border: Border(
                            right: BorderSide(color: AppTheme.border),
                            bottom: BorderSide(color: AppTheme.border),
                          ),
                        ),
                        child: Text(
                          lbl,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isHighlighted || isToday ? AppTheme.primary : AppTheme.text,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          // Scrollable Grid Body
          Expanded(
            child: Row(
              children: [
                // Synchronized Time Column
                SizedBox(
                  width: timeColWidth,
                  child: ListView.builder(
                    controller: _timeColVerticalController,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _totalSlots,
                    itemBuilder: (context, idx) {
                      final slotMinute = _gridStartMinutes + (idx * _slotMinutes);
                      final hour = (slotMinute ~/ 60);
                      final minute = (slotMinute % 60);
                      final h = hour % 12 == 0 ? 12 : hour % 12;
                      final m = minute.toString().padLeft(2, '0');
                      final ampm = hour >= 12 ? 'P' : 'A';

                      return Container(
                        height: _slotHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: AppTheme.border),
                            bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)),
                          ),
                        ),
                        child: Text(
                          '$h:$m$ampm',
                          style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                        ),
                      );
                    },
                  ),
                ),

                // Horizontal & Vertical Scrollable Days Grid
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _bodyHorizontalController,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: colWidth * _days.length,
                      child: SingleChildScrollView(
                        controller: _verticalGridController,
                        physics: const ClampingScrollPhysics(),
                        child: SizedBox(
                          height: _slotHeight * _totalSlots,
                          child: Stack(
                            children: [
                              // Background grid lines
                              Positioned.fill(
                                child: Row(
                                  children: List.generate(_days.length, (dIdx) {
                                    final dayName = _days[dIdx];
                                    final isToday = dayName.toLowerCase() == getCurrentDayOfWeek().toLowerCase();
                                    final isHighlighted = _selectedDay == dayName;

                                    return Container(
                                      width: colWidth,
                                      decoration: BoxDecoration(
                                        color: isHighlighted
                                            ? AppTheme.primary.withValues(alpha: 0.04)
                                            : (isToday ? AppTheme.primary.withValues(alpha: 0.02) : Colors.transparent),
                                        border: Border(
                                          right: BorderSide(color: AppTheme.border),
                                        ),
                                      ),
                                      child: Column(
                                        children: List.generate(_totalSlots, (sIdx) {
                                          return Container(
                                            height: _slotHeight,
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    );
                                  }),
                                ),
                              ),

                              // Positioned Schedule Period Blocks
                              ...schedules.map((item) {
                                final dayStr = item['day_of_week'] as String? ?? '';
                                final dayIndex = _days.indexWhere((d) => d.toLowerCase() == dayStr.toLowerCase());
                                if (dayIndex < 0) return const SizedBox.shrink();

                                final startM = _parseTimeToMinutes(item['start_time'] as String?);
                                final endM = _parseTimeToMinutes(item['end_time'] as String?);
                                final durationM = (endM - startM).clamp(25, 480);

                                final top = ((startM - _gridStartMinutes) / _slotMinutes) * _slotHeight;
                                final height = (durationM / _slotMinutes) * _slotHeight;
                                final left = dayIndex * colWidth;

                                final subject = item['subject_name'] as String? ?? 'Class';
                                final section = item['section_name'] as String? ?? 'Section';
                                final room = item['room'] as String? ?? '';
                                final hexCode = item['color_code'] as String?;
                                final color = TimetableColorPalette.getSubjectColor(subject, hexCode, isDark);
                                final isOngoing = _isClassOngoing(item);

                                return Positioned(
                                  top: top + 1,
                                  left: left + 2,
                                  width: colWidth - 4,
                                  height: (height - 2).clamp(26.0, 500.0),
                                  child: GestureDetector(
                                    onTap: () => _showClassDetailModal(context, item, isDark),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isOngoing
                                                ? color
                                                : color.withValues(alpha: isDark ? 0.45 : 0.32),
                                            width: isOngoing ? 1.5 : 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          children: [
                                            // Soft Halftone Pattern in top-right
                                            HalftoneCardDecoration(
                                              color: color,
                                              width: 58,
                                              dotSpacing: 5.5,
                                              maxRadius: 2.6,
                                              baseOpacity: isDark ? 0.15 : 0.22,
                                            ),

                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Top row: Section Badge + LIVE indicator + Assigned Pill
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                                          decoration: BoxDecoration(
                                                            color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
                                                          ),
                                                          child: Text(
                                                            section,
                                                            style: TextStyle(
                                                              fontSize: 8.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: isDark ? Color.lerp(color, Colors.white, 0.25) : color,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ),
                                                      if (isOngoing)
                                                        Container(
                                                          width: 5,
                                                          height: 5,
                                                          margin: const EdgeInsets.only(left: 3),
                                                          decoration: BoxDecoration(
                                                            color: AppTheme.success,
                                                            shape: BoxShape.circle,
                                                          ),
                                                        ),
                                                      const Spacer(),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.background,
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                                                        ),
                                                        child: Text(
                                                          'Assigned',
                                                          style: TextStyle(fontSize: 7.5, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),

                                                  // Subject Name
                                                  Text(
                                                    subject,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.text,
                                                      height: 1.15,
                                                    ),
                                                    maxLines: height < 46 ? 1 : 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),

                                                  // Room
                                                  if (room.isNotEmpty && height >= 52) ...[
                                                    const SizedBox(height: 1.5),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.meeting_room_outlined,
                                                          size: 9,
                                                          color: AppTheme.textSecondary,
                                                        ),
                                                        const SizedBox(width: 2),
                                                        Flexible(
                                                          child: Text(
                                                            room,
                                                            style: TextStyle(
                                                              fontSize: 8,
                                                              fontWeight: FontWeight.w500,
                                                              color: AppTheme.textSecondary,
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
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClassDetailModal(BuildContext context, Map<String, dynamic> c, bool isDark) {
    final subject = c['subject_name'] as String? ?? 'Subject';
    final section = c['section_name'] as String? ?? 'Section';
    final room = c['room'] as String? ?? 'Designated Facility';
    final day = c['day_of_week'] as String? ?? '';
    final start = _formatDisplayTime(c['start_time'] as String?);
    final end = _formatDisplayTime(c['end_time'] as String?);
    final color = _parseColor(c['color_code'] as String?, AppTheme.primary);

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

                // Institutional Header: Neutral Subject Box + Badges + Title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: color.withValues(alpha: isDark ? 0.4 : 0.25),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: color,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                      Icons.lock_clock_outlined,
                                      size: 10,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Admin Assigned',
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
                  ],
                ),
                const SizedBox(height: 18),

                // Details Card (Section, Time, Room)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people_outline_rounded, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text('Handled Section', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const Spacer(),
                          Text(section, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text)),
                        ],
                      ),
                      Divider(height: 16, color: AppTheme.border.withValues(alpha: 0.5)),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text('Schedule Time', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const Spacer(),
                          Text('$start - $end', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text)),
                        ],
                      ),
                      Divider(height: 16, color: AppTheme.border.withValues(alpha: 0.5)),
                      Row(
                        children: [
                          Icon(Icons.meeting_room_outlined, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text('Classroom', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const Spacer(),
                          Text(room, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Administration Note Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Class schedule is designated and maintained by school administration.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Dismiss Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppTheme.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Close', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Agenda Timeline View
  Widget _buildAgendaList(List<Map<String, dynamic>> list) {
    final isDark = AppTheme.isDark;

    return Column(
      children: list.map((sched) {
        final subject = sched['subject_name'] as String? ?? 'Subject';
        final section = sched['section_name'] as String? ?? 'Section';
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
                              sched['day_of_week'] as String? ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (sched['day_of_week'] as String?)?.toLowerCase() == getCurrentDayOfWeek().toLowerCase()
                                    ? AppTheme.primary
                                    : AppTheme.text,
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

                      // Subject & Info - Full Width, No Truncation
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row: Section Badge + LIVE indicator + Admin Assigned pill
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
                                    ),
                                    child: Text(
                                      section,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Color.lerp(color, Colors.white, 0.25) : color,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                if (isOngoing) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                                const Spacer(),
                                // Admin Assigned Tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_clock_outlined, size: 10, color: AppTheme.textMuted),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Assigned',
                                        style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
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
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),

                            // Metadata: Room Chip
                            if (room != null && room.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.meeting_room_outlined, size: 12, color: AppTheme.textSecondary),
                                      const SizedBox(width: 3),
                                      Text(
                                        room,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
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
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
