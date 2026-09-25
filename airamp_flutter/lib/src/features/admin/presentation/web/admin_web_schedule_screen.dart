import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../teacher/data/teacher_schedule_repository.dart';
import '../../../teacher/presentation/components/create_edit_schedule_dialog.dart';
import '../../../teacher/presentation/components/halftone_pattern.dart';
import '../../data/admin_repository.dart';

class AdminWebScheduleScreen extends ConsumerStatefulWidget {
  const AdminWebScheduleScreen({super.key});

  @override
  ConsumerState<AdminWebScheduleScreen> createState() => _AdminWebScheduleScreenState();
}

class _AdminWebScheduleScreenState extends ConsumerState<AdminWebScheduleScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTeacher = 'All Faculty';
  String _selectedDay = 'All Days';
  String _selectedSection = 'All Sections';
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
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminTeachersProvider.notifier).loadTeachers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final teacher = sched['teacher_name'] as String? ?? 'Faculty';

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
          'Are you sure you want to remove the schedule for "$subject" ($section) assigned to $teacher?',
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
              ref.invalidate(scheduledSectionsProvider);
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
    ref.watch(themeProvider);
    final schedulesAsync = ref.watch(allClassSchedulesProvider);
    final teachers = ref.watch(adminTeachersProvider);
    final sectionsList = ref.watch(sectionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: schedulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading schedules: $err')),
        data: (allSchedules) {
          // Filters
          final filtered = allSchedules.where((s) {
            if (_selectedDay != 'All Days' && s['day_of_week'] != _selectedDay) {
              return false;
            }
            if (_selectedTeacher != 'All Faculty' && s['teacher_id'] != _selectedTeacher) {
              return false;
            }
            if (_selectedSection != 'All Sections' &&
                (s['section_name'] as String?)?.toLowerCase().trim() != _selectedSection.toLowerCase().trim()) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final sub = (s['subject_name'] as String? ?? '').toLowerCase();
              final sec = (s['section_name'] as String? ?? '').toLowerCase();
              final room = (s['room'] as String? ?? '').toLowerCase();
              final teach = (s['teacher_name'] as String? ?? '').toLowerCase();
              if (!sub.contains(_searchQuery) &&
                  !sec.contains(_searchQuery) &&
                  !room.contains(_searchQuery) &&
                  !teach.contains(_searchQuery)) {
                return false;
              }
            }
            return true;
          }).toList();

          // Metrics
          final totalClasses = allSchedules.length;
          final uniqueTeachersCount = allSchedules.map((s) => s['teacher_id']).toSet().length;
          final uniqueSectionsCount = allSchedules.map((s) => s['section_name']).toSet().length;
          final uniqueRoomsCount = allSchedules
              .map((s) => s['room'] as String?)
              .where((r) => r != null && r.isNotEmpty)
              .toSet()
              .length;

          // Unique sections from database
          final Set<String> availableSections = {'All Sections'};
          for (final s in allSchedules) {
            final name = s['section_name'] as String?;
            if (name != null && name.isNotEmpty) availableSections.add(name);
          }
          for (final sec in sectionsList) {
            final name = sec['name'] as String?;
            if (name != null && name.isNotEmpty) availableSections.add(name);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allClassSchedulesProvider);
              await ref.read(adminTeachersProvider.notifier).loadTeachers();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Master Timetable & Class Schedules',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Administer school timetable, faculty teaching hours, class section allocations, and room reservations',
                              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => CreateEditScheduleDialog.show(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Assign Class Schedule'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                          minimumSize: const Size(0, 42),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // KPI Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 800;
                      final cardWidth = isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2;

                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildKpiCard(
                            title: 'Total Classes',
                            value: '$totalClasses',
                            icon: Icons.calendar_month_outlined,
                            color: AppTheme.primary,
                            width: cardWidth,
                          ),
                          _buildKpiCard(
                            title: 'Scheduled Faculty',
                            value: '$uniqueTeachersCount',
                            icon: Icons.badge_outlined,
                            color: Colors.blue,
                            width: cardWidth,
                          ),
                          _buildKpiCard(
                            title: 'Active Sections',
                            value: '$uniqueSectionsCount',
                            icon: Icons.groups_outlined,
                            color: Colors.purple,
                            width: cardWidth,
                          ),
                          _buildKpiCard(
                            title: 'Classroom Venues',
                            value: '$uniqueRoomsCount',
                            icon: Icons.meeting_room_outlined,
                            color: Colors.orange,
                            width: cardWidth,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Filter & Search Toolbar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Search bar, Teacher Filter, Section Filter, View toggle
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Search field
                            SizedBox(
                              width: 260,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search subject, faculty, room...',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  isDense: true,
                                ),
                              ),
                            ),

                            // Faculty Dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedTeacher,
                                  dropdownColor: AppTheme.surface,
                                  style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: 'All Faculty',
                                      child: Text('All Faculty Members'),
                                    ),
                                    ...teachers.map((t) {
                                      final tid = t['id'] as String;
                                      final tname = t['full_name'] as String? ?? 'Teacher';
                                      return DropdownMenuItem<String>(
                                        value: tid,
                                        child: Text(tname),
                                      );
                                    }),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedTeacher = val);
                                  },
                                ),
                              ),
                            ),

                            // Section Dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSection,
                                  dropdownColor: AppTheme.surface,
                                  style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600),
                                  items: availableSections.map((sec) {
                                    return DropdownMenuItem<String>(
                                      value: sec,
                                      child: Text(sec),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedSection = val);
                                  },
                                ),
                              ),
                            ),

                            // View Toggle
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    iconSize: 18,
                                    tooltip: 'Grid View',
                                    icon: Icon(
                                      Icons.grid_view_rounded,
                                      color: _isGridView ? AppTheme.primary : AppTheme.textMuted,
                                    ),
                                    onPressed: () => setState(() => _isGridView = true),
                                  ),
                                  IconButton(
                                    iconSize: 18,
                                    tooltip: 'Timeline Agenda',
                                    icon: Icon(
                                      Icons.view_agenda_outlined,
                                      color: !_isGridView ? AppTheme.primary : AppTheme.textMuted,
                                    ),
                                    onPressed: () => setState(() => _isGridView = false),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row 2: Day of Week Pills
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
                                    color: isSel ? Colors.white : AppTheme.text,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Schedules Display
                  if (filtered.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 54, color: AppTheme.textMuted),
                            const SizedBox(height: 16),
                            Text(
                              'No class schedules found',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No classes match your selected filters. Click below to assign a new class schedule.',
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => CreateEditScheduleDialog.show(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Assign Class Schedule'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_isGridView)
                    _buildAdminGrid(filtered)
                  else
                    _buildAdminAgendaList(filtered),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminGrid(List<Map<String, dynamic>> schedules) {
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
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${daySchedules.length} Classes',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primary),
                      tooltip: 'Assign Class on $day',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => CreateEditScheduleDialog.show(context, defaultDay: day),
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
                          final crossAxisCount = constraints.maxWidth >= 1000
                              ? 3
                              : constraints.maxWidth >= 600
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
                              childAspectRatio: 1.7,
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
    final teacher = sched['teacher_name'] as String? ?? 'Faculty';
    final room = sched['room'] as String?;
    final startTime = _formatDisplayTime(sched['start_time'] as String?);
    final endTime = _formatDisplayTime(sched['end_time'] as String?);
    final color = _parseColor(sched['color_code'] as String?, AppTheme.primary);
    final isOngoing = _isClassOngoing(sched);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOngoing ? color : color.withValues(alpha: 0.25),
            width: isOngoing ? 1.5 : 1,
          ),
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
            // Halftone Dot Matrix Accent with Card Color
            HalftoneCardDecoration(
              color: color,
              width: 140,
              baseOpacity: 0.28,
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top row: Section Badge + Ongoing Indicator + Admin Action Menu
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
                                'LIVE',
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
                      // Admin Edit & Delete Popup
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
                                Text('Edit Schedule'),
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

                  // Faculty Assignment Pill
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                        child: Text(
                          teacher.isNotEmpty ? teacher[0].toUpperCase() : 'T',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          teacher,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Bottom row: Time + Room
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$startTime - $endTime',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
  }

  Widget _buildAdminAgendaList(List<Map<String, dynamic>> schedules) {
    return Column(
      children: schedules.map((sched) {
        final subject = sched['subject_name'] as String? ?? 'Subject';
        final section = sched['section_name'] as String? ?? 'Section';
        final teacher = sched['teacher_name'] as String? ?? 'Faculty';
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
                color: isOngoing ? color : color.withValues(alpha: 0.25),
                width: isOngoing ? 1.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                HalftoneCardDecoration(
                  color: color,
                  width: 100,
                  baseOpacity: 0.20,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Time & Day Block
                      Container(
                        width: 86,
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
                      const SizedBox(width: 12),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    subject,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.text),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: color.withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    section,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.person_outline, size: 13, color: AppTheme.textSecondary),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    teacher,
                                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (room != null && room.isNotEmpty) ...[
                                  const SizedBox(width: 8),
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

                      // Admin Actions
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        tooltip: 'Edit Schedule',
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        color: AppTheme.textSecondary,
                        onPressed: () => CreateEditScheduleDialog.show(context, initialSchedule: sched),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                        tooltip: 'Delete Schedule',
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _confirmDelete(sched),
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

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
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
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
