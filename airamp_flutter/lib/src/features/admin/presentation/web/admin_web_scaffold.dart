import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/application/auth_provider.dart';

class AdminWebScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AdminWebScaffold({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<AdminWebScaffold> createState() => _AdminWebScaffoldState();
}

class _AdminWebScaffoldState extends ConsumerState<AdminWebScaffold> {
  bool _isSidebarCollapsed = false;

  final List<AdminNavItem> _navItems = const [
    AdminNavItem(
      label: 'Analytics & Overview',
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
      route: '/admin/dashboard',
    ),
    AdminNavItem(
      label: 'Student Directory',
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      route: '/admin/students',
    ),
    AdminNavItem(
      label: 'Faculty & Teachers',
      icon: Icons.badge_outlined,
      activeIcon: Icons.badge,
      route: '/admin/teachers',
    ),
    AdminNavItem(
      label: 'Subjects & Courses',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
      route: '/admin/subjects',
    ),
    AdminNavItem(
      label: 'Enrollment Keys',
      icon: Icons.key_outlined,
      activeIcon: Icons.key,
      route: '/admin/keys',
    ),
    AdminNavItem(
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign,
      route: '/admin/announcements',
    ),
    AdminNavItem(
      label: 'Quiz Scores & Results',
      icon: Icons.assignment_turned_in_outlined,
      activeIcon: Icons.assignment_turned_in,
      route: '/admin/scores',
    ),
    AdminNavItem(
      label: 'Class Sections',
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups,
      route: '/admin/sections',
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
    return 'Admin Management';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final isDark = AppTheme.isDark;
    final currentUser = ref.watch(authProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        final isTablet = constraints.maxWidth >= 720 && constraints.maxWidth < 1024;
        final isMobile = constraints.maxWidth < 720;

        final effectiveCollapsed = isTablet || _isSidebarCollapsed;

        if (isMobile) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            appBar: AppBar(
              backgroundColor: AppTheme.surface,
              elevation: 0,
              title: Text(
                _getPageTitle(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              actions: [
                IconButton(
                  tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: AppTheme.text),
                  onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                ),
              ],
            ),
            drawer: Drawer(
              backgroundColor: AppTheme.surface,
              child: _buildSidebarContent(
                isCollapsed: false,
                isDrawer: true,
                currentUser: currentUser,
                isDark: isDark,
              ),
            ),
            body: widget.navigationShell,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
              ),
              child: BottomNavigationBar(
                backgroundColor: AppTheme.surface,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppTheme.primary,
                unselectedItemColor: AppTheme.textMuted,
                showUnselectedLabels: true,
                selectedFontSize: 10,
                unselectedFontSize: 10,
                currentIndex: widget.navigationShell.currentIndex.clamp(0, 4),
                onTap: _onSelectTab,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
                  BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Students'),
                  BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Subjects'),
                  BottomNavigationBarItem(icon: Icon(Icons.key), label: 'Keys'),
                  BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'Notices'),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Row(
            children: [
              // Persistent Responsive Sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: effectiveCollapsed ? 76 : 260,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(right: BorderSide(color: AppTheme.border, width: 1)),
                ),
                child: _buildSidebarContent(
                  isCollapsed: effectiveCollapsed,
                  isDrawer: false,
                  currentUser: currentUser,
                  isDark: isDark,
                ),
              ),

              // Main Content Area
              Expanded(
                child: Column(
                  children: [
                    // Top Navigation Bar
                    _buildTopBar(context, isDark, currentUser, isDesktop),
                    // Main View Content
                    Expanded(
                      child: widget.navigationShell,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, dynamic currentUser, bool isDesktop) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          // Sidebar Toggle Button
          IconButton(
            icon: Icon(
              _isSidebarCollapsed ? Icons.menu_open : Icons.menu,
              color: AppTheme.textSecondary,
            ),
            onPressed: () {
              setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
            },
          ),
          const SizedBox(width: 8),

          // Breadcrumb Title
          Text(
            'Portal',
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
          ),
          Text(
            _getPageTitle(),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),

          const Spacer(),

          // Theme Toggle Icon
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? AppTheme.warning : AppTheme.primary),
              onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            ),
          ),
          const SizedBox(width: 12),

          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  currentUser?.role == 'super_admin' ? 'SUPER ADMIN' : 'ADMINISTRATOR',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
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
    required bool isDrawer,
    required dynamic currentUser,
    required bool isDark,
  }) {
    final activeIndex = widget.navigationShell.currentIndex;

    return Column(
      children: [
        // App Brand Header
        Container(
          height: 72,
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 20),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'A',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AIRAMP',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text, letterSpacing: 1),
                      ),
                      Text(
                        'Web Admin Portal',
                        style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Navigation Items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = activeIndex == index;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    _onSelectTab(index);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCollapsed ? 12 : 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: AppTheme.primary.withValues(alpha: 0.4))
                          : Border.all(color: Colors.transparent),
                    ),
                    child: Row(
                      mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                          size: 22,
                        ),
                        if (!isCollapsed) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppTheme.text : AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Bottom User Card & Actions
        Container(
          padding: EdgeInsets.all(isCollapsed ? 10 : 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
          ),
          child: Column(
            children: [
              if (!isCollapsed) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primarySoft,
                      child: Text(
                        currentUser?.fullName.isNotEmpty == true ? currentUser.fullName[0].toUpperCase() : 'A',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser?.fullName ?? 'Administrator',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            currentUser?.email ?? 'admin@airamp.edu',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              // Logout Action
              InkWell(
                onTap: () => _confirmLogout(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, size: 16, color: AppTheme.error),
                      if (!isCollapsed) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Sign Out',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.error),
                        ),
                      ],
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

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout_rounded, color: AppTheme.error, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Sign Out',
              style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of the Admin Console?',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go(kIsWeb ? '/admin/login' : '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class AdminNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const AdminNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}
