import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/teacher_repository.dart';
import '../../data/teacher_schedule_repository.dart';

class ClassOverviewWidget extends ConsumerStatefulWidget {
  const ClassOverviewWidget({super.key});

  @override
  ConsumerState<ClassOverviewWidget> createState() => _ClassOverviewWidgetState();
}

class _ClassOverviewWidgetState extends ConsumerState<ClassOverviewWidget> {
  String _activeSection = 'All Handled Sections';
  String _activityFilter = 'All'; // 'All', 'Active', 'Pending', 'Needs Help'
  bool _isCollapsed = false; // Collapse entire student list to keep dashboard minimal
  bool _showAllStudents = false; // Show 3 by default vs all

  @override
  Widget build(BuildContext context) {
    final handledSectionsAsync = ref.watch(teacherHandledSectionsProvider);
    final sections = handledSectionsAsync.value ?? [];
    final students = ref.watch(teacherStudentsProvider);

    // Filter students by section
    final sectionStudents = students.where((s) {
      if (_activeSection == 'All Handled Sections' || _activeSection == 'All Sections') {
        return true;
      }
      final sec = (s['section'] as String?)?.toLowerCase().trim() ?? '';
      return sec == _activeSection.toLowerCase().trim();
    }).toList();

    // Categorize activity status
    final activeStudents = <Map<String, dynamic>>[];
    final pendingStudents = <Map<String, dynamic>>[];
    final needsHelpStudents = <Map<String, dynamic>>[];

    for (final s in sectionStudents) {
      final completed = (s['completed_los'] as num?)?.toInt() ?? 0;
      final enrolled = (s['enrolled_subjects'] as num?)?.toInt() ?? 0;

      if (completed >= 3 || (enrolled > 0 && completed >= enrolled)) {
        activeStudents.add(s);
      } else if (completed >= 1) {
        pendingStudents.add(s);
      } else {
        needsHelpStudents.add(s);
      }
    }

    final filteredStudents = _activityFilter == 'Active'
        ? activeStudents
        : _activityFilter == 'Pending'
            ? pendingStudents
            : _activityFilter == 'Needs Help'
                ? needsHelpStudents
                : sectionStudents;

    // Prioritize actionable students (needs help / pending first)
    final sortedStudents = List<Map<String, dynamic>>.from(filteredStudents)
      ..sort((a, b) {
        final aComp = (a['completed_los'] as num?)?.toInt() ?? 0;
        final bComp = (b['completed_los'] as num?)?.toInt() ?? 0;
        return aComp.compareTo(bComp);
      });

    final displayStudents = _showAllStudents
        ? sortedStudents
        : sortedStudents.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title, Subtitle, and Collapse Toggle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.dashboard_customize_outlined, size: 20, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Overview & Student Activity',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time student progress & submission health',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  color: AppTheme.textMuted,
                  size: 22,
                ),
                tooltip: _isCollapsed ? 'Expand Student List' : 'Collapse Student List',
                onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dropdown Selectors Row: Section Selector & Status Filter Dropdown
          Row(
            children: [
              // Section Selector Dropdown
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _activeSection,
                      dropdownColor: AppTheme.surface,
                      style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w600),
                      items: [
                        'All Handled Sections',
                        ...sections,
                      ].map((sec) {
                        return DropdownMenuItem<String>(
                          value: sec,
                          child: Text(sec, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _activeSection = val;
                            _showAllStudents = false;
                          });
                          ref.read(teacherStudentsProvider.notifier).reload(
                                section: val == 'All Handled Sections' ? null : val,
                              );
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Activity Status Dropdown Filter
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _activityFilter,
                      dropdownColor: AppTheme.surface,
                      style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Status', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Active', child: Text('On Track', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Pending', child: Text('Pending', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Needs Help', child: Text('Needs Help', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _activityFilter = val;
                            _showAllStudents = false;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status Category Pills / Quick Filter Counters
          Row(
            children: [
              Expanded(
                child: _buildStatusFilterCard(
                  label: 'Total',
                  count: sectionStudents.length,
                  filterKey: 'All',
                  color: AppTheme.textSecondary,
                  icon: Icons.people_alt_outlined,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildStatusFilterCard(
                  label: 'On Track',
                  count: activeStudents.length,
                  filterKey: 'Active',
                  color: AppTheme.success,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildStatusFilterCard(
                  label: 'Pending',
                  count: pendingStudents.length,
                  filterKey: 'Pending',
                  color: AppTheme.warning,
                  icon: Icons.hourglass_top_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildStatusFilterCard(
                  label: 'Needs Help',
                  count: needsHelpStudents.length,
                  filterKey: 'Needs Help',
                  color: AppTheme.error,
                  icon: Icons.error_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Student Activity List or Collapsed State
          if (_isCollapsed)
            InkWell(
              onTap: () => setState(() => _isCollapsed = false),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.unfold_more, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Showing ${filteredStudents.length} students (Collapsed) • Tap to view',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
            )
          else if (filteredStudents.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.person_search_outlined, size: 32, color: AppTheme.textMuted),
                  const SizedBox(height: 6),
                  Text(
                    'No students match "$_activityFilter" in $_activeSection',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayStudents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final student = displayStudents[index];
                return _buildStudentRow(student, context);
              },
            ),

            const SizedBox(height: 12),

            // Controls: Show More / Show Less & View All in Roster
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (sortedStudents.length > 3)
                  InkWell(
                    onTap: () => setState(() => _showAllStudents = !_showAllStudents),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showAllStudents ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showAllStudents
                                ? 'Show Less'
                                : 'Show More (${sortedStudents.length - 3} more)',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),

                TextButton.icon(
                  onPressed: () => context.go('/teacher/students?section=$_activeSection'),
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: Text(
                    'View All (${sectionStudents.length}) in Roster',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusFilterCard({
    required String label,
    required int count,
    required String filterKey,
    required Color color,
    required IconData icon,
  }) {
    final isSel = _activityFilter == filterKey;

    return InkWell(
      onTap: () => setState(() => _activityFilter = filterKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? color.withValues(alpha: 0.12) : AppTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? color : AppTheme.border,
            width: isSel ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSel ? color : AppTheme.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                color: isSel ? color : AppTheme.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> student, BuildContext context) {
    final name = (student['full_name'] as String?) ?? 'Student';
    final section = (student['section'] as String?) ?? 'Section';
    final completed = (student['completed_los'] as num?)?.toInt() ?? 0;
    final enrolled = (student['enrolled_subjects'] as num?)?.toInt() ?? 1;

    Color statusColor;
    String statusLabel;
    if (completed >= 3 || (enrolled > 0 && completed >= enrolled)) {
      statusColor = AppTheme.success;
      statusLabel = 'On Track';
    } else if (completed >= 1) {
      statusColor = AppTheme.warning;
      statusLabel = 'Pending Work';
    } else {
      statusColor = AppTheme.error;
      statusLabel = 'Needs Attention';
    }

    return InkWell(
      onTap: () => context.go('/teacher/scores'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Avatar, Name & Section, Status Badge
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        section,
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Activity Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: Progress indicator & activities completed
            Row(
              children: [
                Text(
                  'Activities: $completed completed',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: enrolled > 0 ? (completed / (enrolled * 3)).clamp(0.0, 1.0) : 0.0,
                      backgroundColor: AppTheme.border,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14, color: AppTheme.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's Class Schedule Banner Widget
class TodayScheduleBanner extends ConsumerWidget {
  const TodayScheduleBanner({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayTeacherSchedulesProvider);
    final todayName = getCurrentDayOfWeek();

    return todayAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (schedules) {
        if (schedules.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
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
                  child: Icon(Icons.free_cancellation_outlined, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Classes Scheduled for Today ($todayName)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.text),
                      ),
                      Text(
                        'You have no assigned class hours for today. Click below to view the full timetable.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/teacher/schedule'),
                  child: const Text('View Timetable'),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withValues(alpha: 0.15),
                AppTheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    "Today's Class Schedule ($todayName)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.text,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.go('/teacher/schedule'),
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: const Text('Manage Timetable', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: schedules.map((sched) {
                    final subject = sched['subject_name'] as String? ?? 'Subject';
                    final section = sched['section_name'] as String? ?? 'Section';
                    final room = sched['room'] as String? ?? 'Classroom';
                    final start = _formatDisplayTime(sched['start_time'] as String?);
                    final end = _formatDisplayTime(sched['end_time'] as String?);

                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$section • $start - $end • $room',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
