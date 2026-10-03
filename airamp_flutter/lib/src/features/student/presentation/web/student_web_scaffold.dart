import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/application/auth_provider.dart';
import '../components/student_announcements_sheet.dart';
import '../components/student_schedule_widget.dart';

class StudentNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const StudentNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

class StudentWebScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final Widget? floatingOverlay;

  const StudentWebScaffold({
    super.key,
    required this.navigationShell,
    this.floatingOverlay,
  });

  @override
  ConsumerState<StudentWebScaffold> createState() => _StudentWebScaffoldState();
}

class _StudentWebScaffoldState extends ConsumerState<StudentWebScaffold> {
  bool _isSidebarCollapsed = false;

  static const Color _studentAccent = Color(0xFF0284C7); // Sky / Cyan blue

  final List<StudentNavItem> _navItems = const [
    StudentNavItem(
      label: 'Dashboard & Overview',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      route: '/student/home',
    ),
    StudentNavItem(
      label: 'Enrolled Courses',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
      route: '/student/courses',
    ),
    StudentNavItem(
      label: 'Academic Progress',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
      route: '/student/progress',
    ),
    StudentNavItem(
      label: 'Quizzes & Tasks',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
      route: '/student/quiz-history',
    ),
    StudentNavItem(
      label: 'Messages & Chat',
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      route: '/student/chat',
    ),
  ];

  void _onSelectTab(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  String _getPageTitle() {
    final currentIndex = widget.navigationShell.currentIndex;
    if (currentIndex >= 0 && currentIndex < _navItems.length) {
      return _navItems[currentIndex].label;
    }
    return 'Student Portal';
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.error, size: 22),
            const SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to end your student session?',
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
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/student/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final isDark = AppTheme.isDark;
    final currentUser = ref.watch(authProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;
    final effectiveCollapsed = _isSidebarCollapsed || (!isDesktop && screenWidth >= 800);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Desktop Collapsible Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: effectiveCollapsed ? 76 : 260,
            child: Material(
              color: AppTheme.surface,
              elevation: 0,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: AppTheme.border, width: 1)),
                ),
                child: _buildSidebarContent(
                  isCollapsed: effectiveCollapsed,
                  currentUser: currentUser,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // Main View Content
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                _buildHeaderBar(
                  isDesktop: isDesktop,
                  screenWidth: screenWidth,
                  isDark: isDark,
                  currentUser: currentUser,
                ),

                // Routed Page Body
                Expanded(
                  child: Stack(
                    children: [
                      widget.navigationShell,
                      if (widget.floatingOverlay != null) widget.floatingOverlay!,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar({
    required bool isDesktop,
    required double screenWidth,
    required bool isDark,
    required User? currentUser,
  }) {
    final section = currentUser?.section?.toString() ?? '';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isSidebarCollapsed ? Icons.menu_open : Icons.menu,
              color: AppTheme.textSecondary,
            ),
            tooltip: _isSidebarCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
            onPressed: () {
              setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
            },
          ),
          const SizedBox(width: 8),

          // Breadcrumbs
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Student Portal',
                style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
              ),
              Text(
                _getPageTitle(),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
            ],
          ),

          const Spacer(),

          // Section Badge
          if (section.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.class_outlined, size: 16, color: _studentAccent),
                  const SizedBox(width: 6),
                  Text(
                    section,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Timetable / Schedule Shortcut Button
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: 'Class Schedule',
              icon: const Icon(Icons.calendar_month_outlined, color: _studentAccent),
              onPressed: () {
                if (section.isNotEmpty) {
                  showStudentTimetableModal(context, initialSection: section);
                } else {
                  showStudentTimetableModal(context);
                }
              },
            ),
          ),
          const SizedBox(width: 10),

          // Announcements Sheet Button
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: 'Announcements',
              icon: Icon(Icons.campaign_outlined, color: AppTheme.warning),
              onPressed: () => showStudentAnnouncementsFromRef(context, ref),
            ),
          ),
          const SizedBox(width: 10),

          // Theme Toggle
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? AppTheme.warning : _studentAccent),
              onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            ),
          ),
          const SizedBox(width: 12),

          // Learner Access Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _studentAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _studentAccent.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_rounded, size: 14, color: _studentAccent),
                SizedBox(width: 6),
                Text(
                  'LEARNER ACCESS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _studentAccent, letterSpacing: 0.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent({
    required bool isCollapsed,
    required User? currentUser,
    required bool isDark,
  }) {
    final activeIndex = widget.navigationShell.currentIndex;

    return Column(
      children: [
        // App Brand Header
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 19),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_studentAccent, Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Opacity(
                  opacity: isCollapsed ? 0.0 : 1.0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AIRAMP',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.text, letterSpacing: 0.5),
                        maxLines: 1,
                      ),
                      Text(
                        'Student Workspace',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Navigation Items
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = activeIndex == index;

                final navItemWidget = InkWell(
                  onTap: () => _onSelectTab(index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? _studentAccent.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: _studentAccent.withValues(alpha: 0.35), width: 1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          size: 20,
                          color: isSelected ? _studentAccent : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Opacity(
                            opacity: isCollapsed ? 0.0 : 1.0,
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? _studentAccent : AppTheme.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: isCollapsed
                      ? Tooltip(
                          message: item.label,
                          preferBelow: false,
                          waitDuration: const Duration(milliseconds: 250),
                          child: navItemWidget,
                        )
                      : navItemWidget,
                );
              }),
            ),
          ),
        ),

        // Bottom User Profile & Sign Out
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => context.push('/student/profile'),
                borderRadius: BorderRadius.circular(10),
                child: Tooltip(
                  message: 'View & Edit Profile',
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Center(
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: _studentAccent.withValues(alpha: 0.15),
                              child: Text(
                                currentUser?.fullName.isNotEmpty == true ? currentUser!.fullName[0].toUpperCase() : 'S',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: _studentAccent),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Opacity(
                            opacity: isCollapsed ? 0.0 : 1.0,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentUser?.fullName ?? 'Student',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    currentUser != null && currentUser.username.isNotEmpty
                                        ? '@${currentUser.username}'
                                        : (currentUser != null && currentUser.id.isNotEmpty
                                            ? 'ID: ${currentUser.id}'
                                            : 'Student'),
                                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (!isCollapsed)
                          Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _confirmLogout(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isCollapsed
                      ? Tooltip(
                          message: 'Sign Out',
                          preferBelow: false,
                          waitDuration: const Duration(milliseconds: 250),
                          child: Center(child: Icon(Icons.logout, size: 18, color: AppTheme.error)),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, size: 16, color: AppTheme.error),
                            const SizedBox(width: 8),
                            Text(
                              'Sign Out',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.error),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
