import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/offline_sync_status_pill.dart';
import '../../../core/theme/theme_provider.dart';
import '../../admin/data/admin_repository.dart';
import '../../auth/application/auth_provider.dart';
import '../data/super_admin_repository.dart';
import 'super_admin_theme.dart';
import 'tabs/super_admin_overview_tab.dart';
import 'tabs/super_admin_campuses_tab.dart';
import 'tabs/super_admin_admins_tab.dart';
import 'tabs/super_admin_security_tab.dart';

class SuperAdminPortalScreen extends ConsumerStatefulWidget {
  const SuperAdminPortalScreen({super.key});

  @override
  ConsumerState<SuperAdminPortalScreen> createState() => _SuperAdminPortalScreenState();
}

class _SuperAdminPortalScreenState extends ConsumerState<SuperAdminPortalScreen> {
  int _activeTabIndex = 0;
  bool _isSidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(schoolsListProvider.notifier).loadSchools();
      ref.read(schoolAdminsProvider.notifier).loadAdmins();
    });
  }

  void _openAddCampusDialog(GovernanceTheme gTheme) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String selectedStatus = 'active';
    String? selectedAdminId;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final admins = ref.watch(schoolAdminsProvider);
            return AlertDialog(
              backgroundColor: gTheme.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: gTheme.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: gTheme.primaryBorder),
                    ),
                    child: Icon(Icons.add_business_outlined, color: gTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Register New Campus / School',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: gTheme.textPrimary),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Provision a multi-tenant institutional school campus with dedicated school_id scoping.',
                        style: TextStyle(fontSize: 13, color: gTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        maxLength: 80,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'School / Campus Name *',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.school_outlined, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeCtrl,
                        maxLength: 15,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'School Identifier Code *',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.tag_rounded, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressCtrl,
                        maxLength: 150,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Campus Physical Address',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.location_on_outlined, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedStatus,
                              dropdownColor: gTheme.surfaceElevated,
                              style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Operational Status',
                                labelStyle: TextStyle(color: gTheme.textSecondary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'active', child: Text('Active Campus')),
                                DropdownMenuItem(value: 'inactive', child: Text('Inactive / Onboarding')),
                              ],
                              onChanged: (val) => setDialogState(() => selectedStatus = val ?? 'active'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: selectedAdminId,
                              dropdownColor: gTheme.surfaceElevated,
                              style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Assigned Administrator',
                                labelStyle: TextStyle(color: gTheme.textSecondary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('None (Assign Later)')),
                                ...admins.map((a) => DropdownMenuItem(
                                  value: a['id'] as String,
                                  child: Text(
                                    a['full_name'] as String? ?? 'Admin',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                              ],
                              onChanged: (val) => setDialogState(() => selectedAdminId = val),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: gTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final code = codeCtrl.text.trim().toUpperCase();
                    if (name.isEmpty || code.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('School name and code are required.')),
                      );
                      return;
                    }
                    Navigator.of(dialogCtx).pop();
                    try {
                      await ref.read(schoolsListProvider.notifier).addSchool(
                        name: name,
                        code: code,
                        address: addressCtrl.text.trim(),
                        adminId: selectedAdminId,
                        status: selectedStatus,
                      );
                      ref.invalidate(superAdminStatsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Registered campus "$name" ($code) successfully.'),
                            backgroundColor: gTheme.successText,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: gTheme.dangerText),
                        );
                      }
                    }
                  },
                  child: const Text('Register Campus'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openAddAdminDialog(GovernanceTheme gTheme) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'admin';
    String selectedSchool = 'sch_main';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final schools = ref.watch(schoolsListProvider);
            return AlertDialog(
              backgroundColor: gTheme.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: gTheme.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: gTheme.primaryBorder),
                    ),
                    child: Icon(Icons.person_add_outlined, color: gTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Provision Administrator Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: gTheme.textPrimary),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Provision access credentials for a campus administrator or system super-admin.',
                        style: TextStyle(fontSize: 13, color: gTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        maxLength: 50,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.badge_outlined, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        maxLength: 50,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Official Email *',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.email_outlined, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: userCtrl,
                        maxLength: 30,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Username (Optional)',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.alternate_email, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passCtrl,
                        maxLength: 16,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        obscureText: true,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Temporary Password *',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.lock_outline, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        dropdownColor: gTheme.surfaceElevated,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Administrative Authority',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.security, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Campus Administrator (Single Campus)'),
                          ),
                          DropdownMenuItem(
                            value: 'super_admin',
                            child: Text('Super Administrator (Global Master)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      if (selectedRole == 'admin' && schools.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: schools.any((s) => s['id'] == selectedSchool)
                              ? selectedSchool
                              : (schools.first['id'] as String?),
                          dropdownColor: gTheme.surfaceElevated,
                          style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Assigned Campus Scope',
                            labelStyle: TextStyle(color: gTheme.textSecondary),
                            prefixIcon: Icon(Icons.account_balance_outlined, size: 18, color: gTheme.textSecondary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: schools.map((s) {
                            return DropdownMenuItem(
                              value: s['id'] as String,
                              child: Text('${s['name']} (${s['code']})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedSchool = val);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: gTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final email = emailCtrl.text.trim();
                    final pass = passCtrl.text;
                    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name, email, and password are required.')),
                      );
                      return;
                    }
                    Navigator.of(dialogCtx).pop();
                    try {
                      await ref.read(schoolAdminsProvider.notifier).addAdmin(
                        fullName: name,
                        email: email,
                        password: pass,
                        username: userCtrl.text.trim().isNotEmpty ? userCtrl.text.trim() : null,
                        role: selectedRole,
                        schoolId: selectedRole == 'super_admin' ? 'sch_main' : selectedSchool,
                      );
                      ref.invalidate(superAdminStatsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Provisioned administrator "$name" successfully.'),
                            backgroundColor: gTheme.successText,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: gTheme.dangerText),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Provision Admin'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, GovernanceTheme gTheme) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: gTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: gTheme.dangerText, size: 22),
            const SizedBox(width: 10),
            Text('Sign Out from Governance Portal', style: TextStyle(color: gTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to end your Super Administrator session?',
          style: TextStyle(color: gTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: Text('Cancel', style: TextStyle(color: gTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: gTheme.dangerText, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'Overview & Global Metrics';
      case 1:
        return 'Campus Management & Access';
      case 2:
        return 'Administrator Directory & Roles';
      case 3:
        return 'Security Architecture & Audit';
      default:
        return 'Super Admin Governance';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.isDark;
    final gTheme = GovernanceTheme(isDark);
    final currentUser = ref.watch(authProvider);

    final navItems = [
      _NavDescriptor('Overview & Metrics', Icons.dashboard_outlined, Icons.dashboard_rounded),
      _NavDescriptor('Campuses & Schools', Icons.account_balance_outlined, Icons.account_balance_rounded),
      _NavDescriptor('Administrator Accounts', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings_rounded),
      _NavDescriptor('Security & Audit Log', Icons.verified_user_outlined, Icons.verified_user_rounded),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: gTheme.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;
          final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1080;
          final effectiveCollapsed = isTablet || _isSidebarCollapsed;

          if (isMobile) {
            return Scaffold(
              backgroundColor: gTheme.canvas,
              appBar: AppBar(
                backgroundColor: gTheme.surface,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.menu_rounded, color: gTheme.textPrimary),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                title: Text(
                  _getTabTitle(_activeTabIndex),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: gTheme.textPrimary),
                ),
                actions: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: OfflineSyncStatusPill(compact: true),
                  ),
                  IconButton(
                    icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: gTheme.textPrimary),
                    onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                  ),
                ],
              ),
              drawer: Drawer(
                backgroundColor: gTheme.surface,
                child: _buildSidebarContent(
                  gTheme: gTheme,
                  isCollapsed: false,
                  isDrawer: true,
                  currentUser: currentUser,
                  navItems: navItems,
                ),
              ),
              body: _buildActiveTabContent(gTheme),
            );
          }

          return Row(
            children: [
              // ── Persistent Responsive Sidebar ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: effectiveCollapsed ? 76 : 260,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: gTheme.surface,
                  border: Border(right: BorderSide(color: gTheme.border, width: 1)),
                ),
                child: OverflowBox(
                  minWidth: 76,
                  maxWidth: 260,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 260,
                    child: _buildSidebarContent(
                      gTheme: gTheme,
                      isCollapsed: effectiveCollapsed,
                      isDrawer: false,
                      currentUser: currentUser,
                      navItems: navItems,
                    ),
                  ),
                ),
              ),

              // ── Main Work Area ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Governance Bar
                    _buildTopBar(context, gTheme, currentUser),
                    // Active Tab Content
                    Expanded(
                      child: _buildActiveTabContent(gTheme),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveTabContent(GovernanceTheme gTheme) {
    switch (_activeTabIndex) {
      case 0:
        return SuperAdminOverviewTab(
          onNavigateTab: (index) => setState(() => _activeTabIndex = index),
          onOpenAddCampusDialog: () => _openAddCampusDialog(gTheme),
          onOpenAddAdminDialog: () => _openAddAdminDialog(gTheme),
        );
      case 1:
        return SuperAdminCampusesTab(
          onOpenAddCampusDialog: () => _openAddCampusDialog(gTheme),
        );
      case 2:
        return SuperAdminAdminsTab(
          onOpenAddAdminDialog: () => _openAddAdminDialog(gTheme),
        );
      case 3:
        return SuperAdminSecurityTab();
      default:
        return SuperAdminOverviewTab(
          onNavigateTab: (index) => setState(() => _activeTabIndex = index),
          onOpenAddCampusDialog: () => _openAddCampusDialog(gTheme),
          onOpenAddAdminDialog: () => _openAddAdminDialog(gTheme),
        );
    }
  }

  Widget _buildTopBar(BuildContext context, GovernanceTheme gTheme, dynamic currentUser) {
    return Container(
      height: 64,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: gTheme.surface,
        border: Border(bottom: BorderSide(color: gTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: _isSidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
            icon: Icon(
              _isSidebarCollapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
              color: gTheme.textSecondary,
              size: 20,
            ),
            onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
          ),
          const SizedBox(width: 8),

          // Breadcrumb Title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Governance',
                style: TextStyle(fontSize: 13, color: gTheme.textMuted, fontWeight: FontWeight.w500),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right_rounded, size: 16, color: gTheme.textMuted),
              ),
              Text(
                _getTabTitle(_activeTabIndex),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: gTheme.textPrimary),
              ),
            ],
          ),

          const Spacer(),

          // Offline-Sync Status Indicator
          const OfflineSyncStatusPill(),
          const SizedBox(width: 14),

          // Theme Toggle
          Container(
            decoration: BoxDecoration(
              color: gTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: gTheme.border),
            ),
            child: IconButton(
              iconSize: 18,
              tooltip: gTheme.isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              icon: Icon(
                gTheme.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: gTheme.textPrimary,
              ),
              onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            ),
          ),
          const SizedBox(width: 14),

          // Formal Institutional Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: gTheme.primarySubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: gTheme.primaryBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 13, color: gTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'SUPER ADMIN',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: gTheme.primary, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent({
    required GovernanceTheme gTheme,
    required bool isCollapsed,
    required bool isDrawer,
    required dynamic currentUser,
    required List<_NavDescriptor> navItems,
  }) {
    return Column(
      children: [
        // Brand Header
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: gTheme.border, width: 1)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: gTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: gTheme.primaryBorder),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.shield_outlined, color: gTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: isCollapsed ? 0.0 : 1.0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AIRAMP',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: gTheme.textPrimary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'Institutional Governance',
                        style: TextStyle(fontSize: 11, color: gTheme.textMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Navigation Items List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            itemCount: navItems.length,
            itemBuilder: (context, index) {
              final item = navItems[index];
              final isSelected = _activeTabIndex == index;

              final navItemWidget = InkWell(
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  setState(() => _activeTabIndex = index);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? gTheme.primarySubtle : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected ? Border.all(color: gTheme.primaryBorder) : Border.all(color: Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      // Active indicator bar
                      Container(
                        width: 3.5,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isSelected ? gTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Center(
                          child: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected ? gTheme.primary : gTheme.textSecondary,
                            size: 19,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Opacity(
                          opacity: isCollapsed ? 0.0 : 1.0,
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? gTheme.textPrimary : gTheme.textSecondary,
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
                padding: const EdgeInsets.only(bottom: 4),
                child: isCollapsed
                    ? Tooltip(message: item.title, child: navItemWidget)
                    : navItemWidget,
              );
            },
          ),
        ),

        // Bottom User Card & Sign Out
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: gTheme.surface,
            border: Border(top: BorderSide(color: gTheme.border, width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Center(
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: gTheme.surfaceSubtle,
                          child: Icon(Icons.person_outline_rounded, color: gTheme.textSecondary, size: 18),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Opacity(
                        opacity: isCollapsed ? 0.0 : 1.0,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentUser?.fullName ?? 'Super Administrator',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: gTheme.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                currentUser?.email ?? 'aira@admin',
                                style: TextStyle(fontSize: 11, color: gTheme.textMuted),
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
              InkWell(
                onTap: () => _confirmLogout(context, gTheme),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: gTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: gTheme.border),
                  ),
                  child: isCollapsed
                      ? Tooltip(
                          message: 'Sign Out',
                          child: Center(child: Icon(Icons.logout_rounded, size: 16, color: gTheme.textSecondary)),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, size: 15, color: gTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'Sign Out',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: gTheme.textSecondary),
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

class _NavDescriptor {
  final String title;
  final IconData icon;
  final IconData activeIcon;

  _NavDescriptor(this.title, this.icon, this.activeIcon);
}
