import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/calendar/actual_calendar_view.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../teacher/data/teacher_schedule_repository.dart';
import '../../teacher/presentation/components/halftone_pattern.dart';
import 'components/student_schedule_widget.dart';

enum StudentScheduleViewMode { calendar, grid, agenda }

class StudentScheduleScreen extends ConsumerStatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  ConsumerState<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends ConsumerState<StudentScheduleScreen> {
  StudentScheduleViewMode _viewMode = StudentScheduleViewMode.grid;
  String _selectedDay = 'All Days';

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
      final user = ref.read(authProvider);
      final sec = user?.section?.trim();
      if (sec != null && sec.isNotEmpty) {
        ref.invalidate(sectionSchedulesProvider(sec));
      }
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

  void _showClassDetailModal(BuildContext context, Map<String, dynamic> c, bool isDark, String? sectionName) {
    final subject = c['subject_name'] as String? ?? 'Subject';
    final teacher = c['teacher_name'] as String? ?? 'Assigned Faculty';
    final room = c['room'] as String? ?? 'Designated Facility';
    final day = c['day_of_week'] as String? ?? '';
    final start = _formatDisplayTime(c['start_time'] as String?);
    final end = _formatDisplayTime(c['end_time'] as String?);
    final section = (sectionName != null && sectionName.isNotEmpty)
        ? sectionName
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
                _buildInstitutionalInfoTile(
                  icon: Icons.schedule_rounded,
                  category: 'CLASS PERIOD',
                  value: '$start - $end',
                  caption: '$day • Designated class hours',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),

                _buildInstitutionalInfoTile(
                  icon: Icons.person_outline_rounded,
                  category: 'FACULTY / INSTRUCTOR',
                  value: teacher,
                  caption: 'Assigned Subject Educator',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),

                _buildInstitutionalInfoTile(
                  icon: Icons.meeting_room_outlined,
                  category: 'CAMPUS FACILITY & ROOM',
                  value: room,
                  caption: 'Physical class venue & laboratory',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),

                _buildInstitutionalInfoTile(
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

  Widget _buildInstitutionalInfoTile({
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

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    AppTheme.setDark(isDark);

    final currentUser = ref.watch(authProvider);
    final studentSection = currentUser?.section?.trim();

    if (studentSection == null || studentSection.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(0, null),
                const SizedBox(height: 32),
                Expanded(
                  child: Center(
                    child: AppEmptyState(
                      icon: Icons.calendar_month_outlined,
                      title: 'No Section Assigned',
                      message: 'Please contact your school administrator or adviser to assign you to a section to view your calendar and timetable.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final schedulesAsync = ref.watch(sectionSchedulesProvider(studentSection));
    final schedules = schedulesAsync.value ?? [];

    final ongoingClass = schedules.cast<Map<String, dynamic>?>().firstWhere(
      (s) => s != null && _isClassOngoing(s),
      orElse: () => null,
    );

    final filtered = schedules.where((s) {
      if (_viewMode != StudentScheduleViewMode.calendar &&
          _selectedDay != 'All Days' &&
          s['day_of_week'] != _selectedDay) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean Top Header with Title, Section Badge & View Switcher (Picture 1)
              _buildHeader(filtered.length, studentSection),
              const SizedBox(height: 10),

              // Ongoing Class Banner (if live right now)
              if (ongoingClass != null) ...[
                _buildOngoingBanner(ongoingClass, isDark, studentSection),
                const SizedBox(height: 10),
              ],

              // Day Filter Pills with Checkmark on Active Selection (Picture 1)
              if (_viewMode != StudentScheduleViewMode.calendar) ...[
                _buildDayFilterRow(isDark),
                const SizedBox(height: 10),
              ],

              // Main Content Area: Expands to cover the full viewport below without dead white space
              Expanded(
                child: _viewMode == StudentScheduleViewMode.calendar
                    ? ActualCalendarView(
                        schedules: schedules,
                        isStudent: true,
                        emptySubtitle: 'No scheduled class periods for this section.',
                        onScheduleTap: (sched) => _showClassDetailModal(context, sched, isDark, studentSection),
                      )
                    : (_viewMode == StudentScheduleViewMode.grid
                        ? _buildTimetableGridMatrix(schedules, isDark, studentSection)
                        : RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(sectionSchedulesProvider(studentSection));
                              await ref.read(sectionSchedulesProvider(studentSection).future);
                            },
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 24),
                              child: _buildAgendaList(filtered, isDark, studentSection),
                            ),
                          )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int classCount, String? section) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _viewMode == StudentScheduleViewMode.calendar
                          ? 'Calendar'
                          : (_viewMode == StudentScheduleViewMode.grid
                              ? 'Timetable Grid'
                              : 'Class Agenda'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (section != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        section,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _viewMode == StudentScheduleViewMode.calendar
                    ? 'Monthly overview & class dates'
                    : (_viewMode == StudentScheduleViewMode.grid
                        ? 'Weekly section matrix & room locations'
                        : 'Chronological timeline & assigned subjects'),
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Symmetrically Anchored View Switcher (Calendar, Grid, Agenda)
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
                icon: Icons.calendar_month_rounded,
                mode: StudentScheduleViewMode.calendar,
                tooltip: 'Calendar View',
              ),
              _buildViewIcon(
                icon: Icons.grid_view_rounded,
                mode: StudentScheduleViewMode.grid,
                tooltip: 'Timetable Grid',
              ),
              _buildViewIcon(
                icon: Icons.view_agenda_rounded,
                mode: StudentScheduleViewMode.agenda,
                tooltip: 'Agenda View',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewIcon({
    required IconData icon,
    required StudentScheduleViewMode mode,
    required String tooltip,
  }) {
    final isActive = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _viewMode = mode);
        },
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? AppTheme.primary : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildOngoingBanner(Map<String, dynamic> sched, bool isDark, String? section) {
    final subject = sched['subject_name'] as String? ?? 'Subject';
    final teacher = sched['teacher_name'] as String? ?? 'Assigned Faculty';
    final room = sched['room'] as String? ?? 'Room 201';
    final start = _formatDisplayTime(sched['start_time'] as String?);
    final end = _formatDisplayTime(sched['end_time'] as String?);

    return InkWell(
      onTap: () => _showClassDetailModal(context, sched, isDark, section),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.success.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_circle_filled_rounded, color: AppTheme.success, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ONGOING CLASS NOW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$start - $end',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subject,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$teacher • $room',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildDayFilterRow(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _dayOptions.map((opt) {
          final isSelected = _selectedDay == opt['full'];
          final isToday = opt['full'] == getCurrentDayOfWeek();

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedDay = opt['full']!);
                if (_viewMode == StudentScheduleViewMode.grid) {
                  if (opt['full'] == 'All Days') {
                    if (_bodyHorizontalController.hasClients) {
                      _bodyHorizontalController.animateTo(
                        0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  } else {
                    _scrollToDay(opt['full']!);
                  }
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : (isToday
                            ? AppTheme.primary.withValues(alpha: 0.5)
                            : AppTheme.border),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: isDark ? const Color(0xFF0A1420) : Colors.white,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      opt['label']!,
                      style: TextStyle(
                        color: isSelected
                            ? (isDark ? const Color(0xFF0A1420) : Colors.white)
                            : (isToday ? AppTheme.primary : AppTheme.textSecondary),
                        fontSize: 12,
                        fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Weekly Timetable Matrix with Clean Card Surface & Soft Halftone (Full Viewport Coverage)
  Widget _buildTimetableGridMatrix(List<Map<String, dynamic>> schedules, bool isDark, String? section) {
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

          // Scrollable Grid Body - Expanded to seamlessly cover the entire lower screen
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
                              // Clean card surface, Halftone pattern in subject color, dark readable text, NO vertical red line!
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
                                final room = item['room'] as String? ?? '';
                                final teacher = item['teacher_name'] as String? ?? '';
                                final hexCode = item['color_code'] as String?;
                                final color = TimetableColorPalette.getSubjectColor(subject, hexCode, isDark);
                                final isOngoing = _isClassOngoing(item);

                                return Positioned(
                                  top: top + 1,
                                  left: left + 2,
                                  width: colWidth - 4,
                                  height: (height - 2).clamp(26.0, 500.0),
                                  child: GestureDetector(
                                    onTap: () => _showClassDetailModal(context, item, isDark, section),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          // Clean white/surface card background (NOT bright pink wash!)
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
                                            // Soft Halftone Pattern in top-right with subject color (matching Picture 2!)
                                            HalftoneCardDecoration(
                                              color: color,
                                              width: 58,
                                              dotSpacing: 5.5,
                                              maxRadius: 2.6,
                                              baseOpacity: isDark ? 0.15 : 0.22,
                                            ),

                                            // Content: dark readable text, NO vertical red line!
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          subject,
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppTheme.text,
                                                            height: 1.18,
                                                          ),
                                                          maxLines: height < 46 ? 1 : 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      if (isOngoing)
                                                        Container(
                                                          width: 6,
                                                          height: 6,
                                                          margin: const EdgeInsets.only(left: 3),
                                                          decoration: BoxDecoration(
                                                            color: AppTheme.success,
                                                            shape: BoxShape.circle,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  if (teacher.isNotEmpty && height >= 42) ...[
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
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                  if (room.isNotEmpty && height >= 56) ...[
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
                                                              fontSize: 8.5,
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

  /// Agenda Timeline View (matching Picture 2)
  Widget _buildAgendaList(List<Map<String, dynamic>> list, bool isDark, String? section) {
    if (list.isEmpty) {
      return _buildEmptyScheduleCard();
    }

    return Column(
      children: list.map((item) {
        return _buildScheduleCard(item, isDark, section);
      }).toList(),
    );
  }

  Widget _buildEmptyScheduleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: 10),
            Text(
              'No classes scheduled for ${_selectedDay == 'All Days' ? 'this section' : _selectedDay}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text),
            ),
            const SizedBox(height: 4),
            Text(
              'Periods assigned to your section will automatically appear here.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// The Institutional Schedule Card (matching Picture 2, NO vertical red line)
  Widget _buildScheduleCard(Map<String, dynamic> item, bool isDark, String? section) {
    final subject = item['subject_name'] as String? ?? 'Subject';
    final teacher = item['teacher_name'] as String? ?? 'Assigned Faculty';
    final room = item['room'] as String? ?? '';
    final day = item['day_of_week'] as String? ?? '';
    final start = _formatDisplayTime(item['start_time'] as String?);
    final end = _formatDisplayTime(item['end_time'] as String?);
    final isOngoing = _isClassOngoing(item);
    final hexCode = item['color_code'] as String?;
    final color = TimetableColorPalette.getSubjectColor(subject, hexCode, isDark);
    final sectionName = item['section_name'] as String? ?? section ?? 'Section';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _showClassDetailModal(context, item, isDark, sectionName),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isOngoing ? color : color.withValues(alpha: isDark ? 0.35 : 0.25),
                width: isOngoing ? 1.5 : 1.0,
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
                // Subtle Halftone Accent on card (matching Picture 2)
                HalftoneCardDecoration(
                  color: color,
                  width: 90,
                  baseOpacity: isDark ? 0.12 : 0.18,
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Time & Day Block
                      Container(
                        width: 78,
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
                                color: AppTheme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              start,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'to $end',
                              style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Subject & Info - Full spacious width without truncation
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row: Section Badge + LIVE indicator on left, Assigned Pill on right
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: isDark ? 0.20 : 0.10),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.25)),
                                    ),
                                    child: Text(
                                      sectionName,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Color.lerp(color, Colors.white, 0.3) : color,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                if (isOngoing) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'LIVE',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                // Admin Assigned Tag (at top right, leaving full width for text below)
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

                            // Full Subject Title (up to 2 lines so words are not cut off)
                            Text(
                              subject,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),

                            // Metadata: Room & Teacher with icons (Wrap prevents horizontal squishing)
                            Wrap(
                              spacing: 8,
                              runSpacing: 3,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (room.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.meeting_room_outlined, size: 12, color: AppTheme.textSecondary),
                                      const SizedBox(width: 3),
                                      Text(
                                        room,
                                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                if (teacher.isNotEmpty && teacher != 'Assigned Faculty')
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_outline_rounded, size: 12, color: AppTheme.textSecondary),
                                      const SizedBox(width: 3),
                                      Text(
                                        teacher,
                                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
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
        ),
      ),
    );
  }
}
