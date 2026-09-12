import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/application/auth_provider.dart';
import 'components/admin_command_palette.dart';

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

  void _openCommandPalette() {
    AdminCommandPalette.show(context, onSelectTab: _onSelectTab);
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

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _openCommandPalette,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openCommandPalette,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
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
                      tooltip: 'Search (Ctrl+K)',
                      icon: Icon(Icons.search, color: AppTheme.text),
                      onPressed: _openCommandPalette,
                    ),
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
              // Persistent Responsive Sidebar with Smooth Hardware-Accelerated Clipping
              RepaintBoundary(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  width: effectiveCollapsed ? 76 : 260,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border(right: BorderSide(color: AppTheme.border, width: 1)),
                  ),
                  child: OverflowBox(
                    minWidth: 76,
                    maxWidth: 260,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 260,
                      child: _buildSidebarContent(
                        isCollapsed: effectiveCollapsed,
                        isDrawer: false,
                        currentUser: currentUser,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),
              ),

              // Main Content Area with Isolated RepaintBoundary
              Expanded(
                child: RepaintBoundary(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Navigation Bar (Stretches full width, pushing theme toggle and role badge to far right)
                      _buildTopBar(context, isDark, currentUser, isDesktop, constraints.maxWidth),
                      // Main View Content
                      Expanded(
                        child: widget.navigationShell,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  ),
);
  }

  Widget _buildTopBar(BuildContext context, bool isDark, dynamic currentUser, bool isDesktop, double screenWidth) {
    return Container(
      height: 64,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sidebar Toggle Button
          IconButton(
            tooltip: _isSidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
            icon: Icon(
              _isSidebarCollapsed ? Icons.menu_open : Icons.menu,
              color: AppTheme.textSecondary,
            ),
            onPressed: () {
              setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
            },
          ),
          const SizedBox(width: 8),

          // Breadcrumb Title (Non-flex so Spacer takes 100% of remaining space)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
            ],
          ),

          // Command Palette Quick Search Pill
          if (isDesktop) ...[
            const SizedBox(width: 16),
            InkWell(
              onTap: _openCommandPalette,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 16, color: AppTheme.textMuted),
                    if (screenWidth >= 1400) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Search or jump to...',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        'Ctrl K',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Spacer pushes theme toggle and role badge to the absolute far right
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
          padding: const EdgeInsets.symmetric(horizontal: 19),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
          ),
          child: Row(
            children: [
              // Logo: 38px width. With 19px left margin, center is at 19 + 19 = 38px (precisely 76 / 2)
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text, letterSpacing: 1),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                      Text(
                        'Web Admin Portal',
                        style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Navigation Items - SingleChildScrollView + Column for zero sliver overhead
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            child: Column(
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = activeIndex == index;

                final navItemWidget = InkWell(
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    _onSelectTab(index);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: AppTheme.primary.withValues(alpha: 0.4))
                          : Border.all(color: Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        // Fixed Leading Icon Box (56px width): With 10px list margin, icon center is at 10 + 28 = 38px
                        SizedBox(
                          width: 56,
                          child: Center(
                            child: Icon(
                              isSelected ? item.activeIcon : item.icon,
                              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                              size: 22,
                            ),
                          ),
                        ),
                        // Label & Selection Indicator Dot
                        Expanded(
                          child: Opacity(
                            opacity: isCollapsed ? 0.0 : 1.0,
                            child: Row(
                              children: [
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
                                    margin: const EdgeInsets.only(right: 14),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
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

        // Bottom User Card & Sign Out
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User Profile Section
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Center(
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primarySoft,
                          child: Text(
                            currentUser?.fullName.isNotEmpty == true ? currentUser.fullName[0].toUpperCase() : 'A',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
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
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Logout Action
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
                            child: Icon(Icons.logout, size: 18, color: AppTheme.error),
                          ),
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
