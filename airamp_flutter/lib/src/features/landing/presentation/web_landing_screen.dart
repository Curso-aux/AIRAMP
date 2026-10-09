import 'dart:ui';
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
        child: Stack(
          children: [
            // ── Scrollable Body Content (flows under sticky navbar) ──
            Positioned.fill(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Spacing so Hero starts just below the sticky header
                    SizedBox(height: isMobile ? 66 : 78),

                    // ── Hero Section ─────────────────────────────
                    Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : (isTablet ? 48 : 96),
                vertical: isMobile ? 48 : 80,
              ),
              child: Column(
                children: [
                  // DepEd & Institutional Pill
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
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
                        Flexible(
                          child: Text(
                            isMobile
                                ? 'Institutional Learning Infrastructure'
                                : 'Institutional Learning & Assessment Infrastructure',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: isMobile ? 11.5 : 13,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Hero Title
                  Text(
                    'Institutional Control & Unified Learning',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.text,
                      fontSize: isMobile ? 28 : 50,
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
                      'AIRAMP connects institutional governance with interactive classroom learning: school administrators manage curriculum and cohorts, while teachers and students engage in modular reviews and assessments across web, mobile, and desktop.',
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
                      if (user != null) ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            if (user.role == 'admin' || user.role == 'super_admin') {
                              context.go('/admin/dashboard');
                            } else if (user.role == 'teacher') {
                              context.go('/teacher/dashboard');
                            } else {
                              context.go('/student/home');
                            }
                          },
                          icon: Icon(
                            user.role == 'teacher'
                                ? Icons.school_rounded
                                : (user.role == 'student'
                                    ? Icons.auto_stories_rounded
                                    : Icons.dashboard_rounded),
                            size: 20,
                          ),
                          label: Text(
                            user.role == 'teacher'
                                ? 'Go to Teacher Portal'
                                : (user.role == 'student'
                                    ? 'Go to Student Portal'
                                    : 'Go to Admin Console'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(0, 50),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => _navigateToLogin(context),
                          icon: const Icon(Icons.login_rounded, size: 20),
                          label: const Text('Sign In to Portal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(0, 50),
                            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => _showAppInfoDialog(context, isDark),
                        icon: const Icon(Icons.devices_rounded, size: 20),
                        label: const Text('App Information'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: BorderSide(
                            color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12),
                          ),
                          minimumSize: const Size(0, 50),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
                              onCta: () => _navigateToLogin(context, 'admin'),
                            )),
                            const SizedBox(width: 20),
                            Expanded(child: _buildRoleCard(
                              context,
                              title: 'Teacher Portal',
                              subtitle: 'Classroom & Scoring Hub',
                              icon: Icons.assignment_ind_rounded,
                              badge: 'Web & Desktop',
                              isFeatured: false,
                              color: AppTheme.accent,
                              items: [
                                'Section & class cohort tracking',
                                'Student assessment scorebooks',
                                'Direct messaging & student consultations',
                                'Learning outcome pacing and mastery tracking',
                                'Class announcements broadcast',
                              ],
                              ctaText: 'Access Teacher Portal',
                              onCta: () => _navigateToLogin(context, 'teacher'),
                            )),
                            const SizedBox(width: 20),
                            Expanded(child: _buildRoleCard(
                              context,
                              title: 'Student Portal',
                              subtitle: 'Personalized Learning',
                              icon: Icons.school_rounded,
                              badge: 'Web, Mobile & Desktop',
                              isFeatured: false,
                              color: AppTheme.info,
                              items: [
                                'Offline-ready interactive learning modules',
                                'Sequential or flexible Learning Outcome navigation',
                                'Instant quiz feedback & mastery scores',
                                'Section key enrollment self-service',
                                'Direct teacher inquiries & study support',
                              ],
                              ctaText: 'Access Student Portal',
                              onCta: () => _navigateToLogin(context, 'student'),
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
                              onCta: () => _navigateToLogin(context, 'admin'),
                            ),
                            const SizedBox(height: 20),
                            _buildRoleCard(
                              context,
                              title: 'Teacher Portal',
                              subtitle: 'Classroom & Scoring Hub',
                              icon: Icons.assignment_ind_rounded,
                              badge: 'Web & Desktop',
                              isFeatured: false,
                              color: AppTheme.accent,
                              items: [
                                'Section & class cohort tracking',
                                'Student assessment scorebooks',
                                'Direct messaging & student consultations',
                                'Learning outcome pacing and mastery tracking',
                                'Class announcements broadcast',
                              ],
                              ctaText: 'Access Teacher Portal',
                              onCta: () => _navigateToLogin(context, 'teacher'),
                            ),
                            const SizedBox(height: 20),
                            _buildRoleCard(
                              context,
                              title: 'Student Portal',
                              subtitle: 'Personalized Learning',
                              icon: Icons.school_rounded,
                              badge: 'Web, Mobile & Desktop',
                              isFeatured: false,
                              color: AppTheme.info,
                              items: [
                                'Offline-ready interactive learning modules',
                                'Sequential or flexible Learning Outcome navigation',
                                'Instant quiz feedback & mastery scores',
                                'Section key enrollment self-service',
                                'Direct teacher inquiries & study support',
                              ],
                              ctaText: 'Access Student Portal',
                              onCta: () => _navigateToLogin(context, 'student'),
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
                  color: AppTheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.devices_rounded, color: AppTheme.primary, size: 28),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Institutional & Multi-Device Access Guidelines',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'AIRAMP supports seamless multi-device accessibility. Administrators manage institutional curriculum, section keys, and master schedules via the Web Console. Teachers and students can sign in directly through the web portal or use dedicated Windows and mobile applications for offline lesson caching and continuous synchronization.',
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

            // ── Sticky Floating Top Navigation Bar (Follows on scroll) ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildStickyNavbar(
                context: context,
                ref: ref,
                theme: theme,
                isDark: isDark,
                user: user,
                size: size,
                isMobile: isMobile,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyNavbar({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeData theme,
    required bool isDark,
    required dynamic user,
    required Size size,
    required bool isMobile,
  }) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkBackground.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.22),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 48,
                vertical: isMobile ? 10 : 14,
              ),
              child: Row(
                children: [
                  // Logo & Brand
                  Container(
                    width: isMobile ? 38 : 44,
                    height: isMobile ? 38 : 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.school_rounded, color: AppTheme.primary, size: isMobile ? 22 : 26),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'AIRA',
                                style: TextStyle(
                                  color: AppTheme.text,
                                  fontWeight: FontWeight.w900,
                                  fontSize: isMobile ? 18 : 20,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'PORTAL',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (size.width >= 460) ...[
                          Text(
                            isMobile
                                ? 'Academic Review & Assessment'
                                : 'Academic Integrated Review & Assessment Management Platform',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Theme Mode Switcher
                  IconButton(
                    tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    padding: isMobile ? EdgeInsets.zero : const EdgeInsets.all(8),
                    constraints: isMobile ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
                    onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: isDark ? AppTheme.warning : AppTheme.primary,
                      size: isMobile ? 20 : 24,
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Login / Dashboard CTA
                  if (user != null && (user.role == 'admin' || user.role == 'super_admin'))
                    ElevatedButton.icon(
                      onPressed: () => context.go('/admin/dashboard'),
                      icon: const Icon(Icons.dashboard_rounded, size: 16),
                      label: Text(isMobile ? 'Admin' : 'Admin Console'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        minimumSize: Size(0, isMobile ? 38 : 42),
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  else if (user != null && user.role == 'teacher')
                    ElevatedButton.icon(
                      onPressed: () => context.go('/teacher/dashboard'),
                      icon: const Icon(Icons.school_rounded, size: 16),
                      label: Text(isMobile ? 'Faculty' : 'Teacher Portal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        minimumSize: Size(0, isMobile ? 38 : 42),
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  else if (user != null)
                    ElevatedButton.icon(
                      onPressed: () => context.go('/student/home'),
                      icon: const Icon(Icons.auto_stories_rounded, size: 16),
                      label: Text(isMobile ? 'Student' : 'Student Portal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        minimumSize: Size(0, isMobile ? 38 : 42),
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  else
                    _buildSignInButton(context, isDark, isMobile: isMobile),
                ],
              ),
            ),
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
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFeatured ? AppTheme.primary.withValues(alpha: 0.15) : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isFeatured ? AppTheme.primary : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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

  void _navigateToLogin(BuildContext context, [String? role]) {
    try {
      if (role != null) {
        context.go('/login?role=$role');
      } else {
        context.go('/login');
      }
    } catch (_) {
      // Graceful fallback for test environments without GoRouter ancestor
    }
  }

  Widget _buildSignInButton(BuildContext context, bool isDark, {bool isMobile = false}) {
    return ElevatedButton.icon(
      onPressed: () => _navigateToLogin(context),
      icon: Icon(Icons.login_rounded, size: isMobile ? 16 : 18, color: Colors.black),
      label: Text(
        'Sign In',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
          fontSize: isMobile ? 13 : 14,
          letterSpacing: 0.3,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        minimumSize: Size(0, isMobile ? 38 : 42),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        shadowColor: AppTheme.primary.withValues(alpha: 0.3),
      ),
    );
  }

  void _showAppInfoDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.devices_rounded, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'AIRAMP Ecosystem Access',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppPlatformRow(
                  icon: Icons.language_rounded,
                  iconColor: AppTheme.primary,
                  title: 'Web Console & Portals (All Devices)',
                  description: 'Responsive web platform accessible via Google Chrome, Safari, Android, and iOS for Administrators, Teachers, and Students.',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildAppPlatformRow(
                  icon: Icons.phone_iphone_rounded,
                  iconColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  title: 'iOS & Android Mobile Web / PWA',
                  description: 'Add AIRA to your device Home Screen for an instant, full-screen mobile app feel with offline lesson caching.',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildAppPlatformRow(
                  icon: Icons.desktop_windows_rounded,
                  iconColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  title: 'Windows Desktop Application',
                  description: 'Offline-ready assessment execution, auto-sync, and teacher grading tools for school PC laboratories.',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildAppPlatformRow(
                  icon: Icons.android_rounded,
                  iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  title: 'Android Native Application',
                  description: 'Dedicated Android APK for portable learning outcome reviews and direct teacher consultations.',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppPlatformRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
