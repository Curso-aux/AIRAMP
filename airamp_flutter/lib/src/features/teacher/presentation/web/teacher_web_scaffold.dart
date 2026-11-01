import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/animations/app_page_transitions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/components/app_logo.dart';
import '../../../auth/application/auth_provider.dart';
import '../../data/teacher_repository.dart';
import '../../../../core/components/offline_sync_status_pill.dart';
import '../../../../core/components/user_avatar_widget.dart';

class TeacherNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const TeacherNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

class TeacherWebScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final Widget? floatingOverlay;

  const TeacherWebScaffold({
    super.key,
    required this.navigationShell,
    this.floatingOverlay,
  });

  @override
  ConsumerState<TeacherWebScaffold> createState() => _TeacherWebScaffoldState();
}

class _TeacherWebScaffoldState extends ConsumerState<TeacherWebScaffold> {
  bool _isSidebarCollapsed = false;

  final List<TeacherNavItem> _navItems = const [
    TeacherNavItem(
      label: 'Dashboard & Overview',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      route: '/teacher/dashboard',
    ),
    TeacherNavItem(
      label: 'Curriculum & Subjects',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
      route: '/teacher/subjects',
    ),
    TeacherNavItem(
      label: 'Class Scheduling',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month,
      route: '/teacher/schedule',
    ),
    TeacherNavItem(
      label: 'Students & Scores',
      icon: Icons.people_alt_outlined,
      activeIcon: Icons.people_alt,
      route: '/teacher/students',
    ),
    TeacherNavItem(
      label: 'Faculty Messages',
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      route: '/teacher/chat',
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
    return 'Faculty Portal';
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
            Text(
              'Sign Out',
              style: TextStyle(
                color: AppTheme.text,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end your faculty session?',
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
                context.go('/login');
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
    final effectiveCollapsed =
        _isSidebarCollapsed || (!isDesktop && screenWidth >= 800);

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
              clipBehavior: Clip.hardEdge,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: AppTheme.border, width: 1),
                  ),
                ),
                clipBehavior: Clip.hardEdge,
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
                      AppBranchTransition(
                        currentIndex: widget.navigationShell.currentIndex,
                        child: widget.navigationShell,
                      ),
                      if (widget.floatingOverlay != null)
                        widget.floatingOverlay!,
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
    required dynamic currentUser,
  }) {
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
            tooltip: _isSidebarCollapsed
                ? 'Expand Sidebar'
                : 'Collapse Sidebar',
            onPressed: () {
              setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
            },
          ),
          const SizedBox(width: 8),
          if (_isSidebarCollapsed || !isDesktop) ...[
            AppLogo.mark(size: 32, isDark: isDark),
            const SizedBox(width: 10),
          ],

          // Breadcrumbs
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Faculty Portal',
                style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
              ),
              Text(
                _getPageTitle(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Persistent Offline-Sync Status Indicator
          const OfflineSyncStatusPill(),
          const SizedBox(width: 12),

          // Section/Class selector quick view
          Consumer(
            builder: (context, ref, _) {
              final sectionsAsync = ref.watch(teacherHandledSectionsProvider);
              final sections = sectionsAsync.value ?? [];
              if (sections.isEmpty) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${sections.length} Handled Sections',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 12),

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
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: isDark ? AppTheme.warning : AppTheme.primary,
              ),
              onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            ),
          ),
          const SizedBox(width: 12),

          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school, size: 14, color: Colors.teal),
                SizedBox(width: 6),
                Text(
                  'FACULTY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                    letterSpacing: 0.5,
                  ),
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
    required dynamic currentUser,
    required bool isDark,
  }) {
    final activeIndex = widget.navigationShell.currentIndex;

    return Column(
      children: [
        // App Brand Header
        Container(
          height: 72,
          padding: isCollapsed
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 19),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.border, width: 1),
            ),
          ),
          child: isCollapsed
              ? Center(child: AppLogo.mark(size: 36, isDark: isDark))
              : Row(
                  children: [
                    AppLogo.mark(size: 38, isDark: isDark),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AIRAMP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.text,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Teacher Workspace',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
                    padding: isCollapsed
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              width: 1,
                            )
                          : null,
                    ),
                    child: isCollapsed
                        ? Center(
                            child: Icon(
                              isSelected ? item.activeIcon : item.icon,
                              size: 20,
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                            ),
                          )
                        : Row(
                            children: [
                              Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: 20,
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.text,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                onTap: () => context.go('/teacher/profile'),
                borderRadius: BorderRadius.circular(10),
                child: Tooltip(
                  message: 'View & Edit Profile',
                  child: Container(
                    height: 44,
                    padding: isCollapsed
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(horizontal: 4),
                    child: isCollapsed
                        ? Center(
                            child: UserAvatarWidget(
                              imageSource: currentUser?.profileImage,
                              fallbackInitial:
                                  currentUser?.fullName.isNotEmpty == true
                                  ? currentUser!.fullName[0].toUpperCase()
                                  : 'T',
                              size: 34,
                              backgroundColor: Colors.teal.withValues(
                                alpha: 0.15,
                              ),
                              textColor: Colors.teal,
                            ),
                          )
                        : Row(
                            children: [
                              SizedBox(
                                width: 44,
                                child: Center(
                                  child: UserAvatarWidget(
                                    imageSource: currentUser?.profileImage,
                                    fallbackInitial:
                                        currentUser?.fullName.isNotEmpty == true
                                        ? currentUser!.fullName[0].toUpperCase()
                                        : 'T',
                                    size: 36,
                                    backgroundColor: Colors.teal.withValues(
                                      alpha: 0.15,
                                    ),
                                    textColor: Colors.teal,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentUser?.fullName ??
                                            'Faculty Instructor',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.text,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        currentUser?.email ??
                                            'teacher@school.edu',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: AppTheme.textMuted,
                              ),
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
                          child: Center(
                            child: Icon(
                              Icons.logout,
                              size: 18,
                              color: AppTheme.error,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, size: 16, color: AppTheme.error),
                            const SizedBox(width: 8),
                            Text(
                              'Sign Out',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.error,
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
    );
  }
}
