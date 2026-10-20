import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../auth/application/auth_provider.dart';
import '../../data/super_admin_repository.dart';
import '../super_admin_theme.dart';

class SuperAdminOverviewTab extends ConsumerWidget {
  final void Function(int tabIndex) onNavigateTab;
  final VoidCallback onOpenAddCampusDialog;
  final VoidCallback onOpenAddAdminDialog;

  const SuperAdminOverviewTab({
    super.key,
    required this.onNavigateTab,
    required this.onOpenAddCampusDialog,
    required this.onOpenAddAdminDialog,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final gTheme = GovernanceTheme(themeState.isDark);
    final statsAsync = ref.watch(superAdminStatsProvider);
    final schools = ref.watch(schoolsListProvider);
    final admins = ref.watch(schoolAdminsProvider);
    final currentUser = ref.watch(authProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Formal Institutional Header ──
              _buildExecutiveBanner(context, gTheme, currentUser),
              const SizedBox(height: 24),

              // ── Key Governance Metrics (4 Cards) ──
              statsAsync.when(
                loading: () => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(color: gTheme.primary)),
                ),
                error: (e, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: gTheme.dangerBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: gTheme.dangerBorder),
                  ),
                  child: Text('Error loading governance metrics: $e', style: TextStyle(color: gTheme.dangerText)),
                ),
                data: (stats) => _buildMetricsGrid(context, gTheme, stats),
              ),
              const SizedBox(height: 24),

              // ── Quick Governance Action Strip ──
              _buildQuickActionsStrip(context, gTheme),
              const SizedBox(height: 28),

              // ── Multi-Tenant Campuses Fleet Overview ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_outlined, size: 20, color: gTheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Institutional Campuses & Scopes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: gTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Global multi-tenant network. Inspect any institutional campus with scoped jurisdiction.',
                        style: TextStyle(fontSize: 13, color: gTheme.textSecondary),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => onNavigateTab(1), // Go to Campuses tab
                    icon: Icon(Icons.arrow_forward_rounded, size: 16, color: gTheme.primary),
                    label: Text('View All Campuses', style: TextStyle(color: gTheme.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Campuses Preview Grid
              if (schools.isEmpty)
                _buildEmptyState(gTheme, 'No institutional campuses registered yet.')
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;
                    final itemWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: schools.take(4).map((school) {
                        return SizedBox(
                          width: itemWidth,
                          child: _buildCampusSummaryCard(context, ref, gTheme, school, admins),
                        );
                      }).toList(),
                    );
                  },
                ),
              const SizedBox(height: 28),

              // ── Campus Administrative Governance & Access Distribution ──
              _buildAccessGovernanceSection(context, gTheme, schools, admins),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveBanner(BuildContext context, GovernanceTheme gTheme, User? currentUser) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: gTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: gTheme.isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;

          final headerText = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: gTheme.primaryBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 12, color: gTheme.primary),
                    const SizedBox(width: 5),
                    Text(
                      'INSTITUTIONAL GOVERNANCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: gTheme.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'System Governance & Multi-Tenant Administration',
                style: TextStyle(
                  color: gTheme.textPrimary,
                  fontSize: isNarrow ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Active Session: ${currentUser?.fullName ?? "Super Administrator"} (${currentUser?.email ?? "aira@admin"}) • Master Institutional Scope',
                style: TextStyle(color: gTheme.textSecondary, fontSize: 13),
              ),
            ],
          );

          final addBtns = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: onOpenAddCampusDialog,
                icon: const Icon(Icons.add_business_outlined, size: 16),
                label: const Text('Register Campus'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onOpenAddAdminDialog,
                icon: Icon(Icons.person_add_outlined, size: 16, color: gTheme.textPrimary),
                label: Text('Provision Admin', style: TextStyle(color: gTheme.textPrimary)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: gTheme.surfaceSubtle,
                  side: BorderSide(color: gTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerText,
                const SizedBox(height: 16),
                addBtns,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: headerText),
              const SizedBox(width: 20),
              addBtns,
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, GovernanceTheme gTheme, Map<String, dynamic> stats) {
    final items = [
      _MetricTileData(
        label: 'Registered Campuses',
        value: stats['total_schools']?.toString() ?? '1',
        icon: Icons.account_balance_outlined,
        tag: 'Multi-Tenant Scopes',
      ),
      _MetricTileData(
        label: 'Administrator Accounts',
        value: stats['total_admins']?.toString() ?? '2',
        icon: Icons.admin_panel_settings_outlined,
        tag: '${stats['school_admins'] ?? 0} School • ${stats['super_admins'] ?? 0} Super',
      ),
      _MetricTileData(
        label: 'Active Faculty Teachers',
        value: stats['total_teachers']?.toString() ?? '0',
        icon: Icons.badge_outlined,
        tag: 'Across All Campuses',
      ),
      _MetricTileData(
        label: 'Enrolled Students',
        value: stats['total_students']?.toString() ?? '0',
        icon: Icons.people_outline_rounded,
        tag: '${stats['total_sections'] ?? 0} Class Sections',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= 960) {
          return Row(
            children: items.map((tile) {
              final isLast = items.last == tile;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 12),
                  child: _buildMetricTile(gTheme, tile),
                ),
              );
            }).toList(),
          );
        }

        final cardWidth = width < 540 ? width : (width - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((tile) => SizedBox(width: cardWidth, child: _buildMetricTile(gTheme, tile))).toList(),
        );
      },
    );
  }

  Widget _buildMetricTile(GovernanceTheme gTheme, _MetricTileData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: gTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: gTheme.isDark ? 0.15 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: gTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: gTheme.border),
                ),
                child: Icon(data.icon, color: gTheme.primary, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: gTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.tag,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: gTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: gTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: TextStyle(fontSize: 12, color: gTheme.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsStrip(BuildContext context, GovernanceTheme gTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: gTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gTheme.border),
      ),
      child: Row(
        children: [
          Icon(Icons.explore_outlined, size: 18, color: gTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            'Quick Governance Navigation:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: gTheme.textPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickPill(
                    gTheme: gTheme,
                    icon: Icons.account_balance_outlined,
                    label: 'Campus Scopes',
                    onTap: () => onNavigateTab(1),
                  ),
                  const SizedBox(width: 8),
                  _buildQuickPill(
                    gTheme: gTheme,
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Admin Directory',
                    onTap: () => onNavigateTab(2),
                  ),
                  const SizedBox(width: 8),
                  _buildQuickPill(
                    gTheme: gTheme,
                    icon: Icons.verified_user_outlined,
                    label: 'Security & Access Log',
                    onTap: () => onNavigateTab(3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPill({
    required GovernanceTheme gTheme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: gTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: gTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: gTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: gTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampusSummaryCard(
    BuildContext context,
    WidgetRef ref,
    GovernanceTheme gTheme,
    Map<String, dynamic> school,
    List<Map<String, dynamic>> admins,
  ) {
    final schoolId = school['id'] as String;
    final name = school['name'] as String? ?? 'Campus';
    final code = school['code'] as String? ?? 'N/A';
    final address = school['address'] as String? ?? 'Address not specified';
    final status = school['status'] as String? ?? 'active';
    final adminId = school['admin_id'] as String?;

    final assignedAdmin = admins.firstWhere(
      (a) => a['id'] == adminId,
      orElse: () => <String, dynamic>{},
    );
    final adminName = assignedAdmin['full_name'] as String? ?? (adminId != null ? 'Admin $adminId' : 'Unassigned');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: gTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: gTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: gTheme.border),
                ),
                child: Text(
                  code,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: gTheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: gTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'active' ? gTheme.successBg : gTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: status == 'active' ? gTheme.successBorder : gTheme.border),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: status == 'active' ? gTheme.successText : gTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: gTheme.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(fontSize: 12, color: gTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.manage_accounts_outlined, size: 14, color: gTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                'Campus Admin: ',
                style: TextStyle(fontSize: 12, color: gTheme.textMuted),
              ),
              Text(
                adminName,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: gTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: gTheme.border),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Scope: $schoolId',
                style: TextStyle(fontSize: 11, color: gTheme.textMuted, fontFamily: 'monospace'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(superAdminSelectedSchoolProvider.notifier).state = schoolId;
                  context.go('/admin/dashboard');
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 13),
                label: const Text('Enter Campus View'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: gTheme.primary,
                  side: BorderSide(color: gTheme.primaryBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccessGovernanceSection(
    BuildContext context,
    GovernanceTheme gTheme,
    List<Map<String, dynamic>> schools,
    List<Map<String, dynamic>> admins,
  ) {
    final schoolAdmins = admins.where((a) => a['role'] == 'admin').toList();
    final superAdmins = admins.where((a) => a['role'] == 'super_admin').toList();
    final assignedSchoolIds = schoolAdmins.map((a) => a['school_id']).toSet();
    final unassignedSchools = schools.where((s) => !assignedSchoolIds.contains(s['id'])).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: gTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: gTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: gTheme.border),
                    ),
                    child: Icon(Icons.shield_outlined, color: gTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Campus Governance & Administrator Scoping',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: gTheme.textPrimary),
                      ),
                      Text(
                        'Jurisdiction overview: each academic campus operates under an isolated administrator scope.',
                        style: TextStyle(fontSize: 12, color: gTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => onNavigateTab(2), // Navigate to Admins tab
                icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                label: const Text('Manage Accounts & Roles'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: gTheme.border),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAccessStatItem(
                  gTheme: gTheme,
                  icon: Icons.domain_rounded,
                  value: '${assignedSchoolIds.length} / ${schools.length}',
                  label: 'Campuses with Dedicated Admin',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccessStatItem(
                  gTheme: gTheme,
                  icon: Icons.admin_panel_settings_outlined,
                  value: '${superAdmins.length}',
                  label: 'Root Super Admins (Master Scope)',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccessStatItem(
                  gTheme: gTheme,
                  icon: Icons.help_outline_rounded,
                  value: '${unassignedSchools.length}',
                  label: 'Unassigned Campuses',
                  isWarning: unassignedSchools.isNotEmpty,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccessStatItem({
    required GovernanceTheme gTheme,
    required IconData icon,
    required String value,
    required String label,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWarning ? gTheme.warningBg : gTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWarning ? gTheme.warningBorder : gTheme.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isWarning ? gTheme.warningText : gTheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isWarning ? gTheme.warningText : gTheme.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, color: gTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(GovernanceTheme gTheme, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: gTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gTheme.border),
      ),
      child: Center(
        child: Text(message, style: TextStyle(color: gTheme.textMuted, fontSize: 13)),
      ),
    );
  }
}

class _MetricTileData {
  final String label;
  final String value;
  final IconData icon;
  final String tag;

  _MetricTileData({
    required this.label,
    required this.value,
    required this.icon,
    required this.tag,
  });
}
