import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../../core/components/app_logo.dart';

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
  final GlobalKey _assistantKey = GlobalKey();
  final GlobalKey _cloudKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollProgress = ValueNotifier<double>(0.0);
  bool _showExplorePrompt = true;
  int _selectedRoleIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final initialProgress = (_scrollController.offset / 36.0).clamp(0.0, 1.0);
        _scrollProgress.value = initialProgress;
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = math.max(0.0, _scrollController.offset);
    final progress = (offset / 48.0).clamp(0.0, 1.0);
    if ((progress - _scrollProgress.value).abs() > 0.003) {
      _scrollProgress.value = progress;
    }
    if (offset > 20) {
      if (_showExplorePrompt) {
        setState(() => _showExplorePrompt = false);
      }
    } else {
      if (!_showExplorePrompt) {
        setState(() => _showExplorePrompt = true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _scrollToEcosystem() {
    if (_showExplorePrompt) {
      setState(() => _showExplorePrompt = false);
    }
    _scrollToKey(_ecosystemKey);
  }

  void _scrollToAssistant() => _scrollToKey(_assistantKey);
  void _scrollToCloud() => _scrollToKey(_cloudKey);

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    final isTablet = size.width >= 768 && size.width < 1100;
    final contentPadding = isMobile ? 16.0 : (isTablet ? 32.0 : 40.0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: HalftoneBackground(
        opacity: isMobile ? (isDark ? 0.08 : 0.12) : (isDark ? 0.20 : 0.40),
        enableBottomFade: false,
        scrollController: _scrollController,
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
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Container(
                          key: _ecosystemKey,
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(
                            contentPadding,
                            isMobile ? 48.0 : 80.0,
                            contentPadding,
                            isMobile ? 36.0 : 48.0,
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

                              // Pillars Cards (Interactive Role CTAs & Mobile Segmented Console)
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final roleCards = [
                                    (
                                      title: 'Admin Web Console',
                                      subtitle: 'Institutional Oversight',
                                      icon: Icons.admin_panel_settings_rounded,
                                      badge: 'Active on Web',
                                      color: AppTheme.primary,
                                      tabLabel: 'Admin',
                                      items: const [
                                        'Live school analytics and pass rates',
                                        'Curriculum management (Subjects, Topics, LOs)',
                                        'Organize student cohorts & enrollment sections',
                                        'Generate & distribute section enrollment keys',
                                        'Broadcast school-wide announcements',
                                      ],
                                      ctaText: 'Sign in as Admin →',
                                      role: 'admin',
                                    ),
                                    (
                                      title: 'Teacher Portal',
                                      subtitle: 'Classroom & Scoring Hub',
                                      icon: Icons.assignment_ind_rounded,
                                      badge: 'Web & Desktop',
                                      color: AppTheme.accent,
                                      tabLabel: 'Teacher',
                                      items: const [
                                        'Section & class cohort tracking',
                                        'Student assessment scorebooks',
                                        'Direct messaging & student consultations',
                                        'Learning outcome pacing and mastery tracking',
                                        'Class announcements broadcast',
                                      ],
                                      ctaText: 'Sign in as Teacher →',
                                      role: 'teacher',
                                    ),
                                    (
                                      title: 'Student Portal',
                                      subtitle: 'Personalized Learning',
                                      icon: Icons.school_rounded,
                                      badge: 'Web, Mobile & Desktop',
                                      color: AppTheme.info,
                                      tabLabel: 'Student',
                                      items: const [
                                        'Offline-ready interactive learning modules',
                                        'Sequential or flexible Learning Outcome navigation',
                                        'Instant quiz feedback & mastery scores',
                                        'Section key enrollment self-service',
                                        'Direct teacher inquiries & study support',
                                      ],
                                      ctaText: 'Sign in as Student →',
                                      role: 'student',
                                    ),
                                  ];

                                  if (constraints.maxWidth > 900) {
                                    return IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          for (int i = 0; i < roleCards.length; i++) ...[
                                            if (i > 0) const SizedBox(width: 20),
                                            Expanded(
                                              child: _buildRoleCard(
                                                context,
                                                title: roleCards[i].title,
                                                subtitle: roleCards[i].subtitle,
                                                icon: roleCards[i].icon,
                                                badge: roleCards[i].badge,
                                                isFeatured: i == 0,
                                                color: roleCards[i].color,
                                                items: roleCards[i].items,
                                                ctaText: roleCards[i].ctaText,
                                                onCta: () => _navigateToLogin(context, role: roleCards[i].role),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  } else {
                                    // Mobile / Tablet Interactive Segmented Console
                                    final safeIndex = _selectedRoleIndex.clamp(0, roleCards.length - 1);
                                    final activeRole = roleCards[safeIndex];

                                    return Column(
                                      children: [
                                        // Segmented Role Switcher Bar
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppTheme.darkSurface : Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.white.withValues(alpha: 0.1)
                                                  : Colors.black.withValues(alpha: 0.08),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: List.generate(roleCards.length, (index) {
                                              final role = roleCards[index];
                                              final isSelected = safeIndex == index;
                                              return Expanded(
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(12),
                                                    onTap: () {
                                                      if (_selectedRoleIndex != index) {
                                                        setState(() => _selectedRoleIndex = index);
                                                      }
                                                    },
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 200),
                                                      curve: Curves.easeOutCubic,
                                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                                      decoration: BoxDecoration(
                                                        color: isSelected ? role.color : Colors.transparent,
                                                        borderRadius: BorderRadius.circular(12),
                                                        boxShadow: isSelected
                                                            ? [
                                                                BoxShadow(
                                                                  color: role.color.withValues(alpha: 0.35),
                                                                  blurRadius: 8,
                                                                  offset: const Offset(0, 3),
                                                                )
                                                              ]
                                                            : null,
                                                      ),
                                                      child: Center(
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                                            child: Row(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(
                                                                  role.icon,
                                                                  size: 15,
                                                                  color: isSelected
                                                                      ? Colors.white
                                                                      : (isDark
                                                                          ? AppTheme.darkTextSecondary
                                                                          : AppTheme.lightTextSecondary),
                                                                ),
                                                                const SizedBox(width: 5),
                                                                Text(
                                                                  role.tabLabel,
                                                                  style: TextStyle(
                                                                    fontSize: 12.5,
                                                                    fontWeight:
                                                                        isSelected ? FontWeight.w700 : FontWeight.w600,
                                                                    color: isSelected
                                                                        ? Colors.white
                                                                        : (isDark
                                                                            ? AppTheme.darkTextSecondary
                                                                            : AppTheme.lightTextSecondary),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        // Active Role Card with Swipe Detection
                                        GestureDetector(
                                          onHorizontalDragEnd: (details) {
                                            if (details.primaryVelocity != null) {
                                              if (details.primaryVelocity! < -150) {
                                                // Swipe Left -> Next Role
                                                if (_selectedRoleIndex < roleCards.length - 1) {
                                                  setState(() => _selectedRoleIndex++);
                                                }
                                              } else if (details.primaryVelocity! > 150) {
                                                // Swipe Right -> Previous Role
                                                if (_selectedRoleIndex > 0) {
                                                  setState(() => _selectedRoleIndex--);
                                                }
                                              }
                                            }
                                          },
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 260),
                                            switchInCurve: Curves.easeOutCubic,
                                            switchOutCurve: Curves.easeInCubic,
                                            transitionBuilder: (child, animation) {
                                              return FadeTransition(
                                                opacity: animation,
                                                child: SlideTransition(
                                                  position: Tween<Offset>(
                                                    begin: const Offset(0.04, 0.0),
                                                    end: Offset.zero,
                                                  ).animate(animation),
                                                  child: child,
                                                ),
                                              );
                                            },
                                            child: KeyedSubtree(
                                              key: ValueKey<int>(safeIndex),
                                              child: _buildRoleCard(
                                                context,
                                                title: activeRole.title,
                                                subtitle: activeRole.subtitle,
                                                icon: activeRole.icon,
                                                badge: activeRole.badge,
                                                isFeatured: true,
                                                color: activeRole.color,
                                                items: activeRole.items,
                                                ctaText: activeRole.ctaText,
                                                onCta: () => _navigateToLogin(context, role: activeRole.role),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 14),

                                        // Pagination Dots & Touch Hint
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: List.generate(roleCards.length, (index) {
                                            final isSelected = safeIndex == index;
                                            return GestureDetector(
                                              onTap: () => setState(() => _selectedRoleIndex = index),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                                width: isSelected ? 22 : 7,
                                                height: 7,
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? roleCards[index].color
                                                      : (isDark
                                                          ? Colors.white.withValues(alpha: 0.2)
                                                          : Colors.black.withValues(alpha: 0.15)),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Swipe left / right or tap tabs above to view each role',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary.withValues(alpha: 0.75),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Interactive School Management Assistant Section ────
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: contentPadding),
                          child: Container(
                            key: _assistantKey,
                            margin: const EdgeInsets.symmetric(vertical: 20),
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
                        ),
                      ),
                    ),

                    // ── Cross-Platform Ecosystem Cloud (Animated) ──────────
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: contentPadding),
                          child: Container(
                            key: _cloudKey,
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            child: CrossPlatformEcosystemCloud(
                              isDark: isDark,
                              isCompact: isMobile,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Access Authorization Notice ───────────────────────
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: contentPadding),
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: isMobile ? 14 : 24),
                            padding: EdgeInsets.all(isMobile ? 18 : 24),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.08),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.devices_rounded,
                                        color: AppTheme.primary,
                                        size: isMobile ? 20 : 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Institutional & Multi-Device Access Guidelines',
                                        style: TextStyle(
                                          fontSize: isMobile ? 15 : 17,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'AIRAMP is engineered for continuous academic operations across all devices and network environments:',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12.5,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildGuidelinePoint(
                                  isDark: isDark,
                                  icon: Icons.admin_panel_settings_outlined,
                                  title: 'Administrators (Web Console)',
                                  desc: 'Master governance of curriculum, section access keys, teacher assignments, and institutional analytics.',
                                ),
                                const SizedBox(height: 10),
                                _buildGuidelinePoint(
                                  isDark: isDark,
                                  icon: Icons.wifi_off_rounded,
                                  title: 'Teachers & Students (Offline-Ready)',
                                  desc: 'Interactive review modules, Gizmo flashcards, and quizzes operate offline in embedded SQLite, syncing automatically upon reconnecting.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Footer ───────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        contentPadding,
                        28,
                        contentPadding,
                        isMobile ? 56.0 : 36.0,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppLogo.mark(
                                  size: 32,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 12),
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
                        ),
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
                isTablet: isTablet,
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
    final horizontalPadding = isMobile ? 18.0 : (isTablet ? 32.0 : 40.0);
    final minHeroHeight = isMobile
        ? math.min(680.0, size.height * 0.88)
        : math.max(680.0, size.height);

    // DepEd & Institutional Pill (High-contrast neutral frosted glass, eye-strain free)
    final pillWidget = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFFCBD5E1),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            color: isDark ? const Color(0xFF34D399) : const Color(0xFF0F766E),
            size: isMobile ? 15 : 17,
          ),
          SizedBox(width: isMobile ? 6 : 8),
          Flexible(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  fontSize: isMobile ? 11 : 13,
                  letterSpacing: 0.2,
                ),
                children: [
                  TextSpan(
                    text: isMobile
                        ? 'Institutional Infrastructure'
                        : 'Institutional Learning & Assessment Infrastructure',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' • DepEd K-12 Aligned',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Hero Title
    final titleWidget = Text(
      'Institutional Control & Unified Learning',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppTheme.text,
        fontSize: isMobile ? 27 : 50,
        fontWeight: FontWeight.w900,
        height: 1.18,
        letterSpacing: isMobile ? -0.4 : -0.5,
      ),
    );

    // Subtitle
    final subtitleWidget = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: Text(
        'AIRAMP connects institutional governance with interactive classroom learning: school administrators manage curriculum and cohorts, while teachers and students engage in modular reviews and assessments across web, mobile, and desktop.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
          fontWeight: isDark ? FontWeight.w500 : FontWeight.w600,
          fontSize: isMobile ? 14 : 18,
          height: 1.55,
        ),
      ),
    );

    final primaryBtn = (user != null)
        ? ElevatedButton.icon(
            onPressed: () {
              if (user.role == 'super_admin') {
                context.go('/super-admin');
              } else if (user.role == 'admin') {
                context.go('/admin/dashboard');
              } else if (user.role == 'teacher') {
                context.go('/teacher/dashboard');
              } else {
                context.go('/student/home');
              }
            },
            icon: Icon(
              user.role == 'super_admin'
                  ? Icons.admin_panel_settings_rounded
                  : (user.role == 'teacher'
                      ? Icons.school_rounded
                      : (user.role == 'student'
                          ? Icons.auto_stories_rounded
                          : Icons.dashboard_rounded)),
              size: 20,
            ),
            label: Text(
              user.role == 'super_admin'
                  ? 'Go to Super Admin Hub'
                  : (user.role == 'teacher'
                      ? 'Go to Teacher Portal'
                      : (user.role == 'student'
                          ? 'Go to Student Portal'
                          : 'Go to Admin Console')),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              minimumSize: Size(isMobile ? double.infinity : 0, isMobile ? 48 : 50),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          )
        : ElevatedButton.icon(
            onPressed: () => _navigateToLogin(context),
            icon: const Icon(Icons.login_rounded, size: 20, color: Colors.black),
            label: const Text('Sign In to Portal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              minimumSize: Size(isMobile ? double.infinity : 0, isMobile ? 48 : 50),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              elevation: 4,
              shadowColor: AppTheme.primary.withValues(alpha: 0.4),
            ),
          );

    final secondaryBtn = ClipRRect(
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
            minimumSize: Size(isMobile ? double.infinity : 0, isMobile ? 48 : 50),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
          ),
        ),
      ),
    );

    final actionsWidget = isMobile
        ? ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                primaryBtn,
                const SizedBox(height: 10),
                secondaryBtn,
              ],
            ),
          )
        : Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              primaryBtn,
              secondaryBtn,
            ],
          );

    if (isMobile) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              84.0,
              horizontalPadding,
              28.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                pillWidget,
                const SizedBox(height: 18),
                titleWidget,
                const SizedBox(height: 14),
                subtitleWidget,
                const SizedBox(height: 24),
                actionsWidget,
                const SizedBox(height: 24),
                _buildExplorePrompt(context, isDark, isMobile),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minHeroHeight,
          maxWidth: 1200,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            96.0,
            horizontalPadding,
            24.0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 1),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  pillWidget,
                  const SizedBox(height: 24),
                  titleWidget,
                  const SizedBox(height: 18),
                  subtitleWidget,
                  const SizedBox(height: 36),
                  actionsWidget,
                ],
              ),
              _buildExplorePrompt(context, isDark, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplorePrompt(BuildContext context, bool isDark, bool isMobile) {
    return AnimatedOpacity(
      opacity: _showExplorePrompt ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: IgnorePointer(
        ignoring: !_showExplorePrompt,
        child: Padding(
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
    bool? isTablet,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollProgress,
      builder: (context, progress, _) {
        final screenWidth = size.width;
        final isDesktop = screenWidth >= 960;
        final showNavLinks = screenWidth >= 960;

        // Dynamic height and styling driven by scroll progress
        final utilityHeight = isDesktop ? (28.0 * (1.0 - progress)).clamp(0.0, 28.0) : 0.0;
        final utilityOpacity = isDesktop ? (1.0 - progress).clamp(0.0, 1.0) : 0.0;
        final mainBarHeight = isMobile ? 58.0 : (64.0 - (8.0 * progress)).clamp(56.0, 64.0);
        final totalHeight = utilityHeight + mainBarHeight;

        // Fully transparent at full scroll up (progress == 0.0), slightly transparent on scroll down
        final blurSigma = (12.0 * progress).clamp(0.0, 12.0);
        final bgOpacity = isDark
            ? (0.65 * progress).clamp(0.0, 0.65)
            : (0.55 * progress).clamp(0.0, 0.55);
        final shadowAlpha = ((isDark ? 0.22 : 0.05) * progress).clamp(0.0, 0.22);
        final borderAlpha = (0.08 * progress).clamp(0.0, 0.08);

        Widget navContent = Container(
          height: totalHeight,
          decoration: BoxDecoration(
            gradient: progress < 0.99
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            const Color(0xFF0B111A).withValues(
                              alpha: (0.45 * (1.0 - progress) + (0.65 * progress)).clamp(0.0, 0.65),
                            ),
                            const Color(0xFF0B111A).withValues(
                              alpha: (0.65 * progress).clamp(0.0, 0.65),
                            ),
                          ]
                        : [
                            Colors.white.withValues(
                              alpha: (0.50 * (1.0 - progress) + (0.55 * progress)).clamp(0.0, 0.55),
                            ),
                            Colors.white.withValues(
                              alpha: (0.55 * progress).clamp(0.0, 0.55),
                            ),
                          ],
                  )
                : null,
            color: progress >= 0.99
                ? (isDark ? const Color(0xFF0B111A) : Colors.white).withValues(alpha: bgOpacity)
                : null,
            border: borderAlpha > 0.001
                ? Border(
                    bottom: BorderSide(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: borderAlpha),
                      width: 1,
                    ),
                  )
                : null,
            boxShadow: shadowAlpha > 0.001
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: shadowAlpha),
                      blurRadius: 6.0 + (8.0 * progress),
                      offset: Offset(0, 1.0 + (2.0 * progress)),
                    ),
                  ]
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tier 1: Institutional Utility Strip (Desktops only, smoothly collapses on scroll)
                      if (utilityHeight > 2)
                        SizedBox(
                          height: utilityHeight,
                          child: Opacity(
                            opacity: utilityOpacity,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 16 : 40,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: (isDark ? Colors.white : Colors.black)
                                        .withValues(alpha: (0.04 * (1.0 - progress)).clamp(0.0, 0.04)),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 13,
                                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF0F766E),
                                    shadows: [
                                      Shadow(
                                        color: isDark ? Colors.black87 : Colors.white,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'DepEd K-12 Aligned • Institutional Learning & Assessment Infrastructure',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? const Color(0xFFF1F5F9)
                                            : const Color(0xFF0F172A),
                                        letterSpacing: 0.2,
                                        shadows: [
                                          Shadow(
                                            color: isDark
                                                ? Colors.black.withValues(alpha: 0.9)
                                                : Colors.white.withValues(alpha: 0.95),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Spacer(),
                                  _buildUtilityRoleLink(
                                    'Student Access',
                                    () => _navigateToLogin(context, role: 'student'),
                                    isDark,
                                  ),
                                  _buildUtilityDivider(isDark),
                                  _buildUtilityRoleLink(
                                    'Teacher Workspace',
                                    () => _navigateToLogin(context, role: 'teacher'),
                                    isDark,
                                  ),
                                  _buildUtilityDivider(isDark),
                                  _buildUtilityRoleLink(
                                    'Admin Governance',
                                    () => _navigateToLogin(context, role: 'admin'),
                                    isDark,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Tier 2: Primary Brand & Navigation Action Row
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 6 : 40,
                          ),
                          child: Row(
                            children: [
                              // Brand Section (Tapping smoothly scrolls to top)
                              InkWell(
                                onTap: _scrollToTop,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AppLogo.mark(
                                        size: isMobile ? 22 : 36,
                                        isDark: isDark,
                                      ),
                                      SizedBox(width: isMobile ? 4 : 10),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'AIRA',
                                            style: TextStyle(
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              fontWeight: FontWeight.w900,
                                              fontSize: isMobile ? 14 : 20,
                                              letterSpacing: isMobile ? 0.3 : 1.1,
                                              shadows: [
                                                Shadow(
                                                  color: isDark ? Colors.black87 : Colors.white,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            'MP',
                                            style: TextStyle(
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.w900,
                                              fontSize: isMobile ? 14 : 20,
                                              letterSpacing: isMobile ? 0.3 : 1.1,
                                              shadows: [
                                                Shadow(
                                                  color: isDark ? Colors.black87 : Colors.white,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!isMobile) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary.withValues(alpha: 0.16),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: AppTheme.primary.withValues(alpha: 0.35),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                'PORTAL',
                                                style: TextStyle(
                                                  color: AppTheme.primary,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.6,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const Spacer(),

                              // Center: Balanced Anchor Links (Role Ecosystem, AI Assistant, Cloud, About)
                              if (showNavLinks)
                                Flexible(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _HeaderNavLink(
                                          label: 'Role Ecosystem',
                                          onTap: _scrollToEcosystem,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 4),
                                        _HeaderNavLink(
                                          label: 'School Assistant',
                                          onTap: _scrollToAssistant,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 4),
                                        _HeaderNavLink(
                                          label: 'Ecosystem Cloud',
                                          onTap: _scrollToCloud,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 4),
                                        _HeaderNavLink(
                                          label: 'Platform Info',
                                          onTap: () => _showAppInfoDialog(context, isDark),
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 16),
                                      ],
                                    ),
                                  ),
                                ),

                              // Right Actions: Theme Mode Switcher + Sign In CTA + Mobile Navigation Menu
                              IconButton(
                                tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                                visualDensity: VisualDensity.compact,
                                padding: isMobile ? const EdgeInsets.all(4) : const EdgeInsets.all(8),
                                constraints: isMobile ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
                                onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                                icon: Icon(
                                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                  color: isDark ? AppTheme.warning : const Color(0xFF0F766E),
                                  size: isMobile ? 18 : 22,
                                  shadows: [
                                    Shadow(
                                      color: isDark ? Colors.black87 : Colors.white,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: isMobile ? 4 : 8),

                              // Mobile menu trigger or Desktop Sign In / Dashboard CTA
                              if (isMobile) ...[
                                if (user != null)
                                  _buildUserDashboardButton(user, isMobile: true)
                                else
                                  _buildSignInButton(context, isDark, isMobile: true),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: 'Open Navigation Menu',
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () => _showMobileNavSheet(context, isDark),
                                  icon: Icon(
                                    Icons.menu_rounded,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    size: 22,
                                  ),
                                ),
                              ] else ...[
                                if (user != null)
                                  _buildUserDashboardButton(user, isMobile: false)
                                else
                                  _buildSignInButton(context, isDark, isMobile: false),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );

        if (blurSigma > 0.01) {
          navContent = ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: navContent,
            ),
          );
        }

        return RepaintBoundary(child: navContent);
      },
    );
  }

  Widget _buildUtilityRoleLink(String label, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            letterSpacing: 0.2,
            shadows: [
              Shadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.95),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUtilityDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '|',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          shadows: [
            Shadow(
              color: isDark ? Colors.black54 : Colors.white70,
              blurRadius: 2,
            ),
          ],
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
              ? color.withValues(alpha: 0.6)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
          width: isFeatured ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isFeatured
                ? color.withValues(alpha: 0.16)
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
                            ? color.withValues(alpha: 0.15)
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isFeatured ? color : AppTheme.textSecondary,
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
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: isFeatured ? 3 : 1,
                  shadowColor: color.withValues(alpha: 0.35),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: TextStyle(
                    fontWeight: isFeatured ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 14,
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
      icon: Icon(Icons.login_rounded, size: isMobile ? 14 : 18, color: Colors.black),
      label: Text(
        'Sign In',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
          fontSize: isMobile ? 12 : 14,
          letterSpacing: 0.2,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        elevation: 3,
        shadowColor: AppTheme.primary.withValues(alpha: 0.45),
        minimumSize: Size(0, isMobile ? 32 : 42),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildUserDashboardButton(dynamic user, {required bool isMobile}) {
    if (user.role == 'super_admin') {
      return ElevatedButton.icon(
        onPressed: () => context.go('/super-admin'),
        icon: const Icon(Icons.admin_panel_settings_rounded, size: 16),
        label: Text(isMobile ? 'Super Admin' : 'Super Admin Hub'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          minimumSize: Size(0, isMobile ? 34 : 40),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
    } else if (user.role == 'admin') {
      return ElevatedButton.icon(
        onPressed: () => context.go('/admin/dashboard'),
        icon: const Icon(Icons.dashboard_rounded, size: 16),
        label: Text(isMobile ? 'Admin' : 'Admin Console'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          minimumSize: Size(0, isMobile ? 34 : 40),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
    } else if (user.role == 'teacher') {
      return ElevatedButton.icon(
        onPressed: () => context.go('/teacher/dashboard'),
        icon: const Icon(Icons.school_rounded, size: 16),
        label: Text(isMobile ? 'Faculty' : 'Teacher Portal'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          minimumSize: Size(0, isMobile ? 34 : 40),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () => context.go('/student/home'),
        icon: const Icon(Icons.auto_stories_rounded, size: 16),
        label: Text(isMobile ? 'Student' : 'Student Portal'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          minimumSize: Size(0, isMobile ? 34 : 40),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
    }
  }

  void _showMobileNavSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    AppLogo.mark(size: 24, isDark: isDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AIRAMP Platform Navigation',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                const SizedBox(height: 12),
                _buildMobileSheetNavItem(
                  icon: Icons.hub_rounded,
                  title: 'Role Ecosystem',
                  subtitle: 'Institutional consoles for Admin, Faculty & Students',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _scrollToEcosystem();
                  },
                  isDark: isDark,
                ),
                _buildMobileSheetNavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'School Assistant',
                  subtitle: 'Interactive answers for keys, grading & modules',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _scrollToAssistant();
                  },
                  isDark: isDark,
                ),
                _buildMobileSheetNavItem(
                  icon: Icons.cloud_done_outlined,
                  title: 'Ecosystem Cloud',
                  subtitle: 'Offline caching, cross-platform & sync network',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _scrollToCloud();
                  },
                  isDark: isDark,
                ),
                _buildMobileSheetNavItem(
                  icon: Icons.devices_rounded,
                  title: 'App Architecture & Info',
                  subtitle: 'Technical specifications, DepEd alignment & security',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showAppInfoDialog(context, isDark);
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                Text(
                  'DIRECT ROLE PORTALS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickRolePill(
                        label: 'Admin',
                        icon: Icons.admin_panel_settings_outlined,
                        color: AppTheme.primary,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _navigateToLogin(context, role: 'admin');
                        },
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickRolePill(
                        label: 'Teacher',
                        icon: Icons.school_outlined,
                        color: AppTheme.accent,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _navigateToLogin(context, role: 'teacher');
                        },
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickRolePill(
                        label: 'Student',
                        icon: Icons.auto_stories_outlined,
                        color: AppTheme.info,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _navigateToLogin(context, role: 'student');
                        },
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileSheetNavItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 20),
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickRolePill({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelinePoint({
    required bool isDark,
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAppInfoDialog(BuildContext context, bool isDark) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.90,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle pill
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 6),
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Expanded(
                  child: _buildAppInfoContent(ctx, isDark: isDark, isMobile: true),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 720,
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            child: _buildAppInfoContent(ctx, isDark: isDark, isMobile: false),
          ),
        ),
      );
    }
  }

  Widget _buildAppInfoContent(
    BuildContext ctx, {
    required bool isDark,
    required bool isMobile,
  }) {
    final platforms = [
      (
        icon: Icons.language_rounded,
        title: 'Web Administration Console',
        badge: 'Web Portal',
        badgeColor: const Color(0xFF10B981),
        target: 'Chrome • Edge • Safari',
        desc: 'Institutional master governance for school heads, supervisors, and administrators. Manage multi-tenant curriculum, generate student section enrollment keys, oversee faculty scoring access, and audit school-wide analytics in real time.',
      ),
      (
        icon: Icons.phone_iphone_rounded,
        title: 'Mobile Progressive Web App (PWA)',
        badge: 'iOS & Android',
        badgeColor: const Color(0xFF38BDF8),
        target: 'Smartphones & Tablets',
        desc: 'Touch-optimized student and teacher experience. Add to Home Screen for full-screen view. Review DepEd competencies, practice with gamified flashcard modules, and cache lesson materials for offline study.',
      ),
      (
        icon: Icons.desktop_windows_rounded,
        title: 'Windows Desktop Application',
        badge: 'School PC Labs',
        badgeColor: const Color(0xFFA855F7),
        target: 'Windows 10 / 11 64-bit',
        desc: 'High-performance standalone desktop application built for school computer laboratories. Provides direct hardware acceleration, instant quiz evaluation, and high-concurrency offline assessment taking.',
      ),
      (
        icon: Icons.storage_rounded,
        title: 'Embedded SQLite Local Engine',
        badge: 'Offline-First',
        badgeColor: const Color(0xFFF59E0B),
        target: 'Zero-Lag Local Storage',
        desc: 'Embedded relational database embedded in client applications. Assessments and learning progress are stored locally with zero network latency, automatically synchronizing to Firebase Cloud upon reconnection.',
      ),
    ];

    return Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(isMobile ? 18 : 24, 16, isMobile ? 16 : 20, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.devices_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AIRAMP Platform Architecture',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 19,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'DepEd K-12 Alignment • Offline Engine • Multi-Device RBAC',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                tooltip: 'Close',
                color: isDark ? Colors.white60 : Colors.black54,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
        ),

        // Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Title: Cross-Platform Targets
                Text(
                  'MULTI-DEVICE ECOSYSTEM TARGETS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),

                // Platform Cards
                ...platforms.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131A29) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: p.badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(p.icon, color: p.badgeColor, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.title,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  p.target,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: p.badgeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.badge,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: p.badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.desc,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )),

                const SizedBox(height: 14),

                // Section 2: DepEd SHS Alignment
                Text(
                  'DEPED SENIOR HIGH SCHOOL CURRICULUM MODEL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131A29) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pre-loaded competencies across core, applied, and specialized tracks (STEM, ABM, HUMSS, TVL). Study materials and assessments are structured hierarchically:',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildHierarchyPill('1. Subjects', isDark),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                          _buildHierarchyPill('2. Topics', isDark),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                          _buildHierarchyPill('3. Learning Outcomes (LO)', isDark),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                          _buildHierarchyPill('4. Quizzes & Gizmos', isDark),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Section 3: Institutional Security & Governance
                Text(
                  'SECURITY & TENANT ISOLATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131A29) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildSecurityItem(
                        icon: Icons.domain_verification_rounded,
                        title: 'Hierarchical Multi-Tenant RBAC',
                        desc: 'Campus data strictly scoped by school_id. Zero cross-institution data bleed.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _buildSecurityItem(
                        icon: Icons.enhanced_encryption_rounded,
                        title: 'Cryptographic Salted Password Security',
                        desc: 'SHA-256 with cryptographically secure 16-byte random salts per credential.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _buildSecurityItem(
                        icon: Icons.mark_email_read_rounded,
                        title: 'Two-Factor Authentication (2FA)',
                        desc: 'Administrative email challenge tokens with sandboxed demo bypass support.',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Action Footer
        Container(
          padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 12, isMobile ? 16 : 24, isMobile ? 16 : 20),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/login');
                  },
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Sign In to Portal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  side: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHierarchyPill(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _HeaderNavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _HeaderNavLink({
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_HeaderNavLink> createState() => _HeaderNavLinkState();
}

class _HeaderNavLinkState extends State<_HeaderNavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark
        ? (_isHovered ? AppTheme.darkPrimaryLight : Colors.white)
        : (_isHovered ? AppTheme.lightPrimary : const Color(0xFF0F172A));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppTheme.primary.withValues(alpha: widget.isDark ? 0.20 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: _isHovered ? FontWeight.w800 : FontWeight.w700,
              color: textColor,
              letterSpacing: 0.2,
              shadows: [
                Shadow(
                  color: widget.isDark
                      ? Colors.black.withValues(alpha: 0.90)
                      : Colors.white.withValues(alpha: 0.95),
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
