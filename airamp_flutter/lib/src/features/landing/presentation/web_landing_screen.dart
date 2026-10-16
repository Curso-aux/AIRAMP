import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';

import 'components/halftone_background.dart';
import 'components/placeholders_and_vanish_input_demo.dart';
import 'components/cross_platform_ecosystem_cloud.dart';

class WebLandingScreen extends ConsumerStatefulWidget {
  const WebLandingScreen({super.key});

  @override
  ConsumerState<WebLandingScreen> createState() => _WebLandingScreenState();
}

class _WebLandingScreenState extends ConsumerState<WebLandingScreen> {
  final GlobalKey _ecosystemKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEcosystem() {
    if (_ecosystemKey.currentContext != null) {
      Scrollable.ensureVisible(
        _ecosystemKey.currentContext!,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        enableBottomFade: false,
        child: Stack(
          children: [
            // ── Scrollable Body Content (flows under sticky navbar) ──
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    // ── Hero Section (100vh Full Viewport) ───────
                    _buildHeroSection(
                      context: context,
                      ref: ref,
                      user: user,
                      isDark: isDark,
                      size: size,
                      isMobile: isMobile,
                      isTablet: isTablet,
                    ),

                    // ── 3-Pillar Ecosystem Grid ──────────────────────────
                    Container(
                      key: _ecosystemKey,
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 20 : (isTablet ? 40 : 80),
                        vertical: isMobile ? 40 : 64,
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

                        // Pillars Cards (Interactive Role CTAs & Flex-Column Layout)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 900) {
                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildRoleCard(
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
                                          'Organize student cohorts & enrollment sections',
                                          'Generate & distribute section enrollment keys',
                                          'Broadcast school-wide announcements',
                                        ],
                                        ctaText: 'Sign in as Admin →',
                                        onCta: () => _navigateToLogin(context, role: 'admin'),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: _buildRoleCard(
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
                                        ctaText: 'Sign in as Teacher →',
                                        onCta: () => _navigateToLogin(context, role: 'teacher'),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: _buildRoleCard(
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
                                        ctaText: 'Sign in as Student →',
                                        onCta: () => _navigateToLogin(context, role: 'student'),
                                      ),
                                    ),
                                  ],
                                ),
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
                                      'Organize student cohorts & enrollment sections',
                                      'Generate & distribute section enrollment keys',
                                      'Broadcast school-wide announcements',
                                    ],
                                    ctaText: 'Sign in as Admin →',
                                    onCta: () => _navigateToLogin(context, role: 'admin'),
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
                                    ctaText: 'Sign in as Teacher →',
                                    onCta: () => _navigateToLogin(context, role: 'teacher'),
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
                                    ctaText: 'Sign in as Student →',
                                    onCta: () => _navigateToLogin(context, role: 'student'),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),

            // ── Interactive School Management Assistant Section ────
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : (isTablet ? 40 : 80),
                vertical: 20,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: PlaceholdersAndVanishInputDemo(
                isDark: isDark,
                isCompact: isMobile,
              ),
            ),

            // ── Cross-Platform Ecosystem Cloud (Animated) ──────────
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : (isTablet ? 40 : 80),
                vertical: 16,
              ),
              child: CrossPlatformEcosystemCloud(
                isDark: isDark,
                isCompact: isMobile,
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

  Widget _buildHeroSection({
    required BuildContext context,
    required WidgetRef ref,
    required dynamic user,
    required bool isDark,
    required Size size,
    required bool isMobile,
    required bool isTablet,
  }) {
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 48.0 : 96.0);
    final minHeroHeight = isMobile
        ? math.max(600.0, size.height)
        : math.max(680.0, size.height);

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: minHeroHeight,
        minWidth: double.infinity,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          isMobile ? 76.0 : 96.0,
          horizontalPadding,
          isMobile ? 16.0 : 24.0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 1), // Top optical balancing anchor
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // DepEd & Institutional Pill
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, color: AppTheme.primary, size: 16),
                      SizedBox(width: isMobile ? 6 : 8),
                      Flexible(
                        child: Text(
                          isMobile
                              ? 'Institutional Learning Infrastructure'
                              : 'Institutional Learning & Assessment Infrastructure • DepEd K-12 Aligned',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: isMobile ? 11 : 13,
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

              // Subtitle (Improved contrast: deep slate #1e293b in light mode, crisp slate-200 in dark mode)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Text(
                  'AIRAMP connects institutional governance with interactive classroom learning: school administrators manage curriculum and cohorts, while teachers and students engage in modular reviews and assessments across web, mobile, and desktop.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
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
                    // Primary High-Emphasis Solid CTA
                    ElevatedButton.icon(
                      onPressed: () => _navigateToLogin(context),
                      icon: const Icon(Icons.login_rounded, size: 20, color: Colors.black),
                      label: const Text('Sign In to Portal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 50),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        elevation: 4,
                        shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                  // Upgraded Frosted Secondary Button
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: OutlinedButton.icon(
                        onPressed: () => _showAppInfoDialog(context, isDark),
                        icon: Icon(
                          Icons.devices_rounded,
                          size: 20,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                        ),
                        label: Text(
                          'App Information',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF1E293B).withValues(alpha: 0.88)
                              : Colors.white.withValues(alpha: 0.95),
                          foregroundColor: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          minimumSize: const Size(0, 50),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Bottom Floating Explore Role Ecosystem Indicator
          _buildExplorePrompt(context, isDark, isMobile),
        ],
      ),
    ),
  );
}

  Widget _buildExplorePrompt(BuildContext context, bool isDark, bool isMobile) {
    return Padding(
      padding: EdgeInsets.only(top: 16, bottom: isMobile ? 8 : 14),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _scrollToEcosystem,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.70)
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMobile ? 'Explore Ecosystem' : 'Explore Role Ecosystem',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: isMobile ? 11.5 : 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.primary,
                  size: isMobile ? 18 : 20,
                ),
              ],
            ),
          ),
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
                              Text(
                                'MP',
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
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFeatured
              ? AppTheme.primary.withValues(alpha: 0.6)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
          width: isFeatured ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isFeatured
                ? AppTheme.primary.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Role Card Content
          Column(
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
                        color: isFeatured
                            ? AppTheme.primary.withValues(alpha: 0.15)
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
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
              const SizedBox(height: 2),
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
            ],
          ),

          // Action Footer with Role-Specific CTA
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onCta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFeatured
                      ? AppTheme.primary
                      : (isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9)),
                  foregroundColor: isFeatured
                      ? Colors.black
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  elevation: isFeatured ? 2 : 0,
                  side: isFeatured
                      ? null
                      : BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFCBD5E1),
                        ),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: TextStyle(
                    fontWeight: isFeatured ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(ctaText),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToLogin(BuildContext context, {String? role}) {
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
      icon: Icon(Icons.login_rounded, size: isMobile ? 15 : 18, color: Colors.black),
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
        elevation: 3,
        shadowColor: AppTheme.primary.withValues(alpha: 0.45),
        minimumSize: Size(0, isMobile ? 38 : 42),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showAppInfoDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 680,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Close Action
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(height: 4),
                // School Management Assistant inside App Information
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: PlaceholdersAndVanishInputDemo(
                    isDark: isDark,
                    isCompact: true,
                  ),
                ),

                // ── Animated Cross-Platform Ecosystem Cloud (Modal) ────
                CrossPlatformEcosystemCloud(
                  isDark: isDark,
                  isCompact: true,
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
}
