import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../data/admin_repository.dart';

class AdminManagementScreen extends ConsumerWidget {
  const AdminManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final teachers = ref.watch(adminTeachersProvider);
    final subjects = ref.watch(subjectsProvider);
    final sections = ref.watch(sectionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Super Administrator Console',
          style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.text),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'School Operations & Faculty Control',
                                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Centralized control room for faculty, curriculum, and security',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Core Management Modules
                Text(
                  'Operations & Academic Modules',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;
                    final cardWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildModuleCard(
                          context,
                          title: 'Faculty & Teachers',
                          subtitle: '${teachers.length} Active instructors and department staff',
                          icon: Icons.badge_outlined,
                          color: AppTheme.primary,
                          width: cardWidth,
                          route: '/admin/teachers',
                        ),
                        _buildModuleCard(
                          context,
                          title: 'Subjects & Curriculum',
                          subtitle: '${subjects.length} Subjects with modules, LOs, and reading materials',
                          icon: Icons.menu_book_outlined,
                          color: Colors.teal,
                          width: cardWidth,
                          route: '/admin/subjects',
                        ),
                        _buildModuleCard(
                          context,
                          title: 'Class Sections',
                          subtitle: '${sections.length} Academic sections across Grade 10-12',
                          icon: Icons.groups_outlined,
                          color: Colors.amber.shade700,
                          width: cardWidth,
                          route: '/admin/sections',
                        ),
                        _buildModuleCard(
                          context,
                          title: 'Registration & Access Keys',
                          subtitle: 'Generate single-use and multi-use self-enrollment keys',
                          icon: Icons.key_outlined,
                          color: Colors.indigo,
                          width: cardWidth,
                          route: '/admin/keys',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),

                // Security & System Status
                Text(
                  'Security & Architecture Integrity',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      _buildSecurityItem(
                        icon: Icons.lock_outline,
                        color: Colors.green,
                        title: 'Cryptographic Password Hashing',
                        description: 'Salted SHA-256 with unique 16-byte user-specific salts',
                        status: 'ACTIVE',
                      ),
                      Divider(height: 24, color: AppTheme.border),
                      _buildSecurityItem(
                        icon: Icons.vpn_key_outlined,
                        color: Colors.blue,
                        title: 'Secure Session Token Generator',
                        description: 'Random.secure() 256-bit entropy per authenticated device',
                        status: 'ACTIVE',
                      ),
                      Divider(height: 24, color: AppTheme.border),
                      _buildSecurityItem(
                        icon: Icons.storage_outlined,
                        color: Colors.purple,
                        title: 'Local Database Engine',
                        description: 'SQLite v18 with role-based partitioning and auto-migration',
                        status: 'SYNCHRONIZED',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
    required String route,
  }) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required String status,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.text)),
              const SizedBox(height: 2),
              Text(description, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
          ),
          child: Text(
            status,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ),
      ],
    );
  }
}

