import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';

import 'components/halftone_background.dart';

class WebLandingScreen extends ConsumerWidget {
  const WebLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    final isTablet = size.width >= 768 && size.width < 1100;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: HalftoneBackground(
        child: SingleChildScrollView(
          child: Column(
          children: [
            // ── Top Navigation Bar ──────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 48,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Logo & Brand
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.school_rounded, color: AppTheme.primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'AIRA',
                            style: TextStyle(
                              color: AppTheme.text,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'WEB ADMIN',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Academic Integrated Review & Assessment Management Platform',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Theme Mode Switcher
                  IconButton(
                    tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Login / Dashboard CTA
                  if (user != null && (user.role == 'admin' || user.role == 'super_admin'))
                    ElevatedButton.icon(
                      onPressed: () => context.go('/admin/dashboard'),
                      icon: const Icon(Icons.dashboard_rounded, size: 18),
                      label: const Text('Admin Console'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => context.go('/admin/login'),
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: const Text('Admin Login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ),

            // ── Hero Section ─────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : (isTablet ? 48 : 96),
                vertical: isMobile ? 48 : 80,
              ),
              child: Column(
                children: [
                  // DepEd & Institutional Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, color: AppTheme.primary, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Institutional Learning & Assessment Infrastructure',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Hero Title
                  Text(
                    'Institutional Control & Unified Learning',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.text,
                      fontSize: isMobile ? 32 : 50,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Subtitle
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: Text(
                      'AIRAMP separates institutional oversight from classroom execution: school administrators manage curriculum and students on the Web Console, while teachers and students experience interactive, offline-ready modular review on their mobile and desktop apps.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: isMobile ? 15 : 18,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Action Buttons
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => context.go('/admin/login'),
                        icon: const Icon(Icons.admin_panel_settings_rounded, size: 20),
                        label: const Text('Access Admin Portal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(0, 50),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Teachers and students access coursework via the AIRAMP mobile or Windows app.'),
                              backgroundColor: AppTheme.surfaceLight,
                            ),
                          );
                        },
                        icon: const Icon(Icons.devices_rounded, size: 20),
                        label: const Text('App Information'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.text,
                          side: BorderSide(
                            color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.2),
                          ),
                          minimumSize: const Size(0, 50),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── 3-Pillar Ecosystem Grid ──────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : (isTablet ? 40 : 80),
                vertical: 40,
              ),
              child: Column(
                children: [
                  Text(
                    'AIRAMP Role Ecosystem',
                    style: TextStyle(
                      color: AppTheme.text,
                      fontSize: isMobile ? 22 : 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Dedicated platforms customized for each role in the academic institution',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Pillars Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 900) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildRoleCard(
                              context,
                              title: 'Admin Web Console',
                              subtitle: 'Institutional Oversight',
                              icon: Icons.admin_panel_settings_rounded,
                              badge: 'Active on Web',
                              isFeatured: true,
                              color: AppTheme.primary,
                              items: [
                                'Live school analytics and pass rates',
                                'Curriculum management (Subjects, Topics, LOs)',
                                'Arrange student perspective enrollment sections',
                                'Generate & distribute section enrollment keys',
                                'Broadcast school-wide announcements',
                              ],
                              ctaText: 'Open Admin Console',
                              onCta: () => context.go('/admin/login'),
                            )),
                            const SizedBox(width: 20),
                            Expanded(child: _buildRoleCard(
                              context,
                              title: 'Teacher App',
                              subtitle: 'Classroom & Scoring Hub',
                              icon: Icons.assignment_ind_rounded,
                              badge: 'Mobile & Desktop App',
                              isFeatured: false,
                              color: AppTheme.accent,
                              items: [
                                'Section & class cohort tracking',
                                'Student assessment scorebooks',
                                'Direct messaging & student consultations',
                                'Learning outcome pacing and mastery tracking',
                                'Class announcements broadcast',
                              ],
                              ctaText: 'Use Mobile / Desktop App',
                              onCta: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Teachers: Please launch the AIRAMP application on your mobile device or Windows computer.'),
                                    backgroundColor: AppTheme.surfaceLight,
                                  ),
                                );
                              },
                            )),
                            const SizedBox(width: 20),
                            Expanded(child: _buildRoleCard(
                              context,
                              title: 'Student App',
                              subtitle: 'Personalized Learning',
                              icon: Icons.school_rounded,
                              badge: 'Mobile & Desktop App',
                              isFeatured: false,
                              color: AppTheme.info,
                              items: [
                                'Offline-ready interactive learning modules',
                                'Sequential or flexible Learning Outcome navigation',
                                'Instant quiz feedback & mastery scores',
                                'Section key enrollment self-service',
                                'Direct teacher inquiries & study support',
                              ],
                              ctaText: 'Use Mobile / Desktop App',
                              onCta: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Students: Please launch the AIRAMP application on your mobile device or Windows computer.'),
                                    backgroundColor: AppTheme.surfaceLight,
                                  ),
                                );
                              },
                            )),
                          ],
                        );
                      } else {
                        // Stacked for tablet / mobile
                        return Column(
                          children: [
                            _buildRoleCard(
                              context,
                              title: 'Admin Web Console',
                              subtitle: 'Institutional Oversight',
                              icon: Icons.admin_panel_settings_rounded,
                              badge: 'Active on Web',
                              isFeatured: true,
                              color: AppTheme.primary,
                              items: [
                                'Live school analytics and pass rates',
                                'Curriculum management (Subjects, Topics, LOs)',
                                'Arrange student perspective enrollment sections',
                                'Generate & distribute section enrollment keys',
                                'Broadcast school-wide announcements',
                              ],
                              ctaText: 'Open Admin Console',
                              onCta: () => context.go('/admin/login'),
                            ),
                            const SizedBox(height: 20),
                            _buildRoleCard(
                              context,
                              title: 'Teacher App',
                              subtitle: 'Classroom & Scoring Hub',
                              icon: Icons.assignment_ind_rounded,
                              badge: 'Mobile & Desktop App',
                              isFeatured: false,
                              color: AppTheme.accent,
                              items: [
                                'Section & class cohort tracking',
                                'Student assessment scorebooks',
                                'Direct messaging & student consultations',
                                'Learning outcome pacing and mastery tracking',
                                'Class announcements broadcast',
                              ],
                              ctaText: 'Use Mobile / Desktop App',
                              onCta: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Teachers: Please launch the AIRAMP application on your mobile device or Windows computer.'),
                                    backgroundColor: AppTheme.surfaceLight,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildRoleCard(
                              context,
                              title: 'Student App',
                              subtitle: 'Personalized Learning',
                              icon: Icons.school_rounded,
                              badge: 'Mobile & Desktop App',
                              isFeatured: false,
                              color: AppTheme.info,
                              items: [
                                'Offline-ready interactive learning modules',
                                'Sequential or flexible Learning Outcome navigation',
                                'Instant quiz feedback & mastery scores',
                                'Section key enrollment self-service',
                                'Direct teacher inquiries & study support',
                              ],
                              ctaText: 'Use Mobile / Desktop App',
                              onCta: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Students: Please launch the AIRAMP application on your mobile device or Windows computer.'),
                                    backgroundColor: AppTheme.surfaceLight,
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // ── Access Authorization Notice ───────────────────────
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : (isTablet ? 40 : 80),
                vertical: 24,
              ),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shield_outlined, color: AppTheme.warning, size: 28),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Web Access Restriction Notice',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'This web portal is strictly restricted to School Administrators (Admin & Super Admin accounts). Teachers and students cannot sign in to the web console and must use the dedicated AIRAMP mobile or desktop application to ensure reliable offline lesson caching and data synchronization.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Footer ───────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 32),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'AIRAMP © 2026 Academic Integrated Review & Assessment Management Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Built for DepEd Senior High School Competencies & Institutional Analytics',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String badge,
    required bool isFeatured,
    required Color color,
    required List<String> items,
    required String ctaText,
    required VoidCallback onCta,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFeatured
              ? AppTheme.primary.withValues(alpha: 0.6)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
          width: isFeatured ? 2 : 1,
        ),
        boxShadow: isFeatured
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isFeatured ? AppTheme.primary.withValues(alpha: 0.15) : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: isFeatured ? AppTheme.primary : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.text,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // Features Checklist
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.text,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Button
          SizedBox(
            width: double.infinity,
            child: isFeatured
                ? ElevatedButton(
                    onPressed: onCta,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    child: Text(ctaText),
                  )
                : OutlinedButton(
                    onPressed: onCta,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.text,
                      side: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
                      ),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    child: Text(ctaText),
                  ),
          ),
        ],
      ),
    );
  }
}
