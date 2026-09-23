import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../data/teacher_repository.dart';
import '../data/teacher_schedule_repository.dart';
import 'components/create_edit_schedule_dialog.dart';

class TeacherScheduleScreen extends ConsumerStatefulWidget {
  const TeacherScheduleScreen({super.key});

  @override
  ConsumerState<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends ConsumerState<TeacherScheduleScreen> {
  String _selectedDay = 'All Days';
  String _selectedSection = 'All Handled Sections';
  bool _isGridView = true;

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
            Text('Remove Schedule', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove the schedule for "$subject" ($section)?',
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
              await ref.read(teacherSchedulesProvider.notifier).deleteSchedule(id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Class schedule removed')),
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
    ref.watch(themeProvider);
    final schedules = ref.watch(teacherSchedulesProvider);
    final sectionsAsync = ref.watch(teacherHandledSectionsProvider);
    final sections = sectionsAsync.value ?? [];

    final filtered = schedules.where((s) {
      if (_selectedDay != 'All Days' && s['day_of_week'] != _selectedDay) {
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
                                'TIMETABLE MANAGEMENT',
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
                                color: Colors.teal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${filtered.length} Scheduled',
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Class Scheduling & Timetable',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Organize weekly class hours, section schedules, and prevent room collisions',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    );

                    final actionButtons = Row(
                      mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
                      children: [
                        // View Toggle
                        Container(
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
                                  color: _isGridView ? AppTheme.primary : AppTheme.textMuted,
                                ),
                                onPressed: () => setState(() => _isGridView = true),
                              ),
                              IconButton(
                                iconSize: 18,
                                tooltip: 'Agenda Timeline List',
                                icon: Icon(
                                  Icons.view_agenda_outlined,
                                  color: !_isGridView ? AppTheme.primary : AppTheme.textMuted,
                                ),
                                onPressed: () => setState(() => _isGridView = false),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Add Class Button
                        if (isMobile)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => CreateEditScheduleDialog.show(
                                context,
                                defaultDay: _selectedDay != 'All Days' ? _selectedDay : null,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text(
                                'Schedule Class',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () => CreateEditScheduleDialog.show(
                              context,
                              defaultDay: _selectedDay != 'All Days' ? _selectedDay : null,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text(
                              'Schedule Class',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                      ],
                    );

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          headerTextColumn,
                          const SizedBox(height: 14),
                          actionButtons,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                    // Day Selector Chips
                    ..._days.map((day) {
                      final isSel = _selectedDay == day;
                      return ChoiceChip(
                        label: Text(day),
                        selected: isSel,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : AppTheme.text,
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
                else if (_isGridView)
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
              'No classes match your active filters. Click "Schedule Class" to add a timetable entry.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => CreateEditScheduleDialog.show(
                context,
                defaultDay: _selectedDay != 'All Days' ? _selectedDay : null,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Schedule Class Now'),
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
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => CreateEditScheduleDialog.show(context, defaultDay: day),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primary),
                      ),
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

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOngoing ? AppTheme.primary : AppTheme.border,
          width: isOngoing ? 1.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          // Left Color Accent Bar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 12, right: 12, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row: Section Badge + Ongoing Indicator + Menu
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
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
                    // Quick Action Menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 18, color: AppTheme.textMuted),
                      color: AppTheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onSelected: (val) {
                        if (val == 'edit') {
                          CreateEditScheduleDialog.show(context, initialSchedule: sched);
                        } else if (val == 'delete') {
                          _confirmDelete(sched);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                              const SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: AppTheme.error)),
                            ],
                          ),
                        ),
                      ],
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
                    Text(
                      '$startTime - $endTime',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    if (room != null && room.isNotEmpty) ...[
                      const Spacer(),
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
    );
  }

  Widget _buildAgendaList(List<Map<String, dynamic>> schedules) {
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

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOngoing ? AppTheme.primary : AppTheme.border,
              width: isOngoing ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Time & Day Block
              Container(
                width: 120,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: day == getCurrentDayOfWeek() ? AppTheme.primary : AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      startTime,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                    Text(
                      'to $endTime',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Subject & Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          subject,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                        if (isOngoing) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'LIVE NOW',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.success),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            section,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                          ),
                        ),
                        if (room != null && room.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.meeting_room_outlined, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            room,
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit Schedule',
                color: AppTheme.textSecondary,
                onPressed: () => CreateEditScheduleDialog.show(context, initialSchedule: sched),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                tooltip: 'Delete Schedule',
                onPressed: () => _confirmDelete(sched),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
