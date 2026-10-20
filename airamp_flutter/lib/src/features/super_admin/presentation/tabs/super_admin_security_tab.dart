import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../data/super_admin_repository.dart';
import '../super_admin_theme.dart';

class SuperAdminSecurityTab extends ConsumerWidget {
  const SuperAdminSecurityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final gTheme = GovernanceTheme(themeState.isDark);
    final auditLogsAsync = ref.watch(superAdminAuditLogsProvider);
    final statsAsync = ref.watch(superAdminStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Formal Institutional Header ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: gTheme.primarySubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: gTheme.primaryBorder),
                    ),
                    child: Icon(Icons.shield_outlined, color: gTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security Architecture & System Audit Trail',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: gTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Real-time cryptographic integrity, multi-tenant RBAC boundaries, and governance event stream.',
                        style: TextStyle(fontSize: 13, color: gTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Security Integrity Pillars ──
              Container(
                padding: const EdgeInsets.all(22),
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
                child: Column(
                  children: [
                    _buildSecurityPillar(
                      gTheme: gTheme,
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Hierarchical Multi-Tenant RBAC Governance',
                      description: 'Super Admin manages Campuses, Administrator Accounts, and Access Scopes across all institutions.',
                      statusBadge: 'ACTIVE',
                    ),
                    Divider(height: 26, color: gTheme.border),
                    _buildSecurityPillar(
                      gTheme: gTheme,
                      icon: Icons.lock_outline_rounded,
                      title: 'Cryptographic Salted Password Security (SHA-256)',
                      description: 'Unique 16-byte cryptographically secure salts per user generated via Random.secure(), auto-upgrading on legacy authentication.',
                      statusBadge: 'ENFORCED',
                    ),
                    Divider(height: 26, color: gTheme.border),
                    _buildSecurityPillar(
                      gTheme: gTheme,
                      icon: Icons.domain_verification_outlined,
                      title: 'Multi-Tenant Database Isolation Scoping',
                      description: 'Tables automatically partitioned and foreign-keyed by school_id across students, teachers, subjects, sections, and schedules.',
                      statusBadge: 'ISOLATED',
                    ),
                    Divider(height: 26, color: gTheme.border),
                    _buildSecurityPillar(
                      gTheme: gTheme,
                      icon: Icons.mark_email_read_outlined,
                      title: 'Two-Factor Authentication (2FA) & SMTP Bridge',
                      description: 'Administrative 2FA email challenge verification with safe sandboxed bypass fallback for demonstration environments.',
                      statusBadge: 'ENABLED',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Database Metrics ──
              statsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (stats) => Container(
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
                        children: [
                          Icon(Icons.storage_outlined, size: 18, color: gTheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Database Table Record Distribution (v21 Schema)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: gTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildTableStat(gTheme, 'Users', stats['total_users']?.toString() ?? '0'),
                          const SizedBox(width: 12),
                          _buildTableStat(gTheme, 'Schools', stats['total_schools']?.toString() ?? '1'),
                          const SizedBox(width: 12),
                          _buildTableStat(gTheme, 'Subjects', stats['total_subjects']?.toString() ?? '0'),
                          const SizedBox(width: 12),
                          _buildTableStat(gTheme, 'Sections', stats['total_sections']?.toString() ?? '0'),
                          const SizedBox(width: 12),
                          _buildTableStat(gTheme, 'Schedules', stats['total_schedules']?.toString() ?? '0'),
                          const SizedBox(width: 12),
                          _buildTableStat(gTheme, 'Admin Accounts', stats['total_admins']?.toString() ?? '1'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── System Audit Trail ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history_edu_rounded, size: 20, color: gTheme.textPrimary),
                      const SizedBox(width: 8),
                      Text(
                        'Governance Audit Trail & Event Stream',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: gTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, size: 18, color: gTheme.textSecondary),
                    tooltip: 'Refresh Audit Trail',
                    onPressed: () => ref.invalidate(superAdminAuditLogsProvider),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: gTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: gTheme.border),
                ),
                child: auditLogsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error loading audit log: $e', style: TextStyle(color: gTheme.dangerText)),
                  ),
                  data: (logs) {
                    if (logs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(child: Text('No audit events logged yet.', style: TextStyle(color: gTheme.textMuted))),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: logs.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: gTheme.border),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final action = log['action'] as String? ?? 'EVENT';
                        final details = log['details'] as String? ?? '';
                        final actor = log['actor_name'] as String? ?? 'System';
                        final time = log['created_at'] as String? ?? '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: gTheme.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: gTheme.border),
                                ),
                                child: Text(
                                  action,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: gTheme.primary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      details,
                                      style: TextStyle(fontSize: 13, color: gTheme.textPrimary, height: 1.35),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Actor: $actor • $time',
                                      style: TextStyle(fontSize: 11, color: gTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityPillar({
    required GovernanceTheme gTheme,
    required IconData icon,
    required String title,
    required String description,
    required String statusBadge,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: gTheme.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: gTheme.border),
          ),
          child: Icon(icon, color: gTheme.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: gTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: gTheme.textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: gTheme.successBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: gTheme.successBorder),
          ),
          child: Text(
            statusBadge,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: gTheme.successText,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableStat(GovernanceTheme gTheme, String label, String count) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: gTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: gTheme.border),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: gTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: gTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
