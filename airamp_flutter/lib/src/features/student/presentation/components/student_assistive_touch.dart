import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';

import '../../../../core/components/aira/aira_floating_assistant.dart';

/// A floating, draggable quick actions bubble styled to match AIRAMP's theme for students.
///
/// Features:
/// - Free drag & pan across the screen with boundary clamping.
/// - Spring edge-snapping to the nearest edge (left or right).
/// - Styled using AIRAMP's brand theme (teal gradient button with touch_app/pan_tool icon).
/// - Smooth idle dimming (opacity 0.65) after 3.5s of inactivity.
/// - Expands on tap into a clean AIRAMP-themed dialog with student quick action cards.
/// - Hold for 4.5s to trigger screen scanning and AIRA text reading aloud with fluent English girl voice!
class StudentAssistiveTouch extends ConsumerStatefulWidget {
  final VoidCallback onCourses;
  final VoidCallback onSchedule;
  final VoidCallback onQuizzes;
  final VoidCallback onProgress;
  final VoidCallback onChat;
  final VoidCallback onAnnouncements;
  final VoidCallback onProfile;

  const StudentAssistiveTouch({
    super.key,
    required this.onCourses,
    required this.onSchedule,
    required this.onQuizzes,
    required this.onProgress,
    required this.onChat,
    required this.onAnnouncements,
    required this.onProfile,
  });

  @override
  ConsumerState<StudentAssistiveTouch> createState() => _StudentAssistiveTouchState();
}

class _StudentAssistiveTouchState extends ConsumerState<StudentAssistiveTouch> {
  void _openMenu() {
    HapticFeedback.mediumImpact();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Quick Actions',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) {
        return _StudentQuickActionsMenuDialog(
          onCourses: () {
            Navigator.of(ctx).pop();
            widget.onCourses();
          },
          onSchedule: () {
            Navigator.of(ctx).pop();
            widget.onSchedule();
          },
          onQuizzes: () {
            Navigator.of(ctx).pop();
            widget.onQuizzes();
          },
          onProgress: () {
            Navigator.of(ctx).pop();
            widget.onProgress();
          },
          onChat: () {
            Navigator.of(ctx).pop();
            widget.onChat();
          },
          onAnnouncements: () {
            Navigator.of(ctx).pop();
            widget.onAnnouncements();
          },
          onProfile: () {
            Navigator.of(ctx).pop();
            widget.onProfile();
          },
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AiraFloatingAssistant(
      onOpenMenu: _openMenu,
    );
  }
}

/// The AIRAMP-styled expanded Quick Actions dialog for Students.
class _StudentQuickActionsMenuDialog extends ConsumerWidget {
  final VoidCallback onCourses;
  final VoidCallback onSchedule;
  final VoidCallback onQuizzes;
  final VoidCallback onProgress;
  final VoidCallback onChat;
  final VoidCallback onAnnouncements;
  final VoidCallback onProfile;

  const _StudentQuickActionsMenuDialog({
    required this.onCourses,
    required this.onSchedule,
    required this.onQuizzes,
    required this.onProgress,
    required this.onChat,
    required this.onAnnouncements,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final isDark = AppTheme.isDark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = (screenWidth - 32.0).clamp(320.0, 368.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dismissible blurred backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                ),
              ),
            ),
          ),

          // Centered Glassmorphic AIRAMP Card
          Center(
            child: Container(
              width: dialogWidth,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.12),
                    blurRadius: 36,
                    spreadRadius: 0,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          isDark
                              ? const Color(0xFF1E293B).withValues(alpha: 0.70)
                              : Colors.white.withValues(alpha: 0.52),
                          isDark
                              ? const Color(0xFF0F172A).withValues(alpha: 0.55)
                              : Colors.white.withValues(alpha: 0.30),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.78),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.65),
                          blurRadius: 1,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: screenHeight * 0.88,
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top Drag Handle Pill
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(top: 12, bottom: 6),
                                width: 38,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),

                            // Dialog Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 4, 12, 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.primary.withValues(alpha: 0.28),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Image.asset(
                                      'assets/images/aira_avatar_active.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Quick Actions Hub',
                                          style: TextStyle(
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.text,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Student shortcuts & academic tools',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                                    ),
                                    tooltip: 'Close',
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                            ),

                            // 2-column Grid of Squarish Action Tiles
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StudentActionCardTile(
                                          icon: Icons.menu_book_outlined,
                                          title: 'My Courses',
                                          subtitle: 'Subjects & units',
                                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                                          onTap: onCourses,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _StudentActionCardTile(
                                          icon: Icons.calendar_month_outlined,
                                          title: 'Timetable',
                                          subtitle: 'Class schedule',
                                          color: isDark ? const Color(0xFF14B8A6) : const Color(0xFF0D9488),
                                          onTap: onSchedule,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StudentActionCardTile(
                                          icon: Icons.quiz_outlined,
                                          title: 'Quizzes',
                                          subtitle: 'Assigned tasks',
                                          color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                                          onTap: onQuizzes,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _StudentActionCardTile(
                                          icon: Icons.bar_chart_outlined,
                                          title: 'My Progress',
                                          subtitle: 'Grades & stats',
                                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                          onTap: onProgress,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StudentActionCardTile(
                                          icon: Icons.chat_bubble_outline_rounded,
                                          title: 'Ask Teacher',
                                          subtitle: 'Chat & questions',
                                          color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                                          onTap: onChat,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _StudentActionCardTile(
                                          icon: Icons.campaign_outlined,
                                          title: 'Bulletins',
                                          subtitle: 'Announcements',
                                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                          onTap: onAnnouncements,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _StudentActionCardTile(
                                    icon: Icons.person_outline_rounded,
                                    title: 'Profile & Settings',
                                    subtitle: 'Account details, appearance & security',
                                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                    isFullWidth: true,
                                    onTap: onProfile,
                                  ),
                                ],
                              ),
                            ),

                            // Bottom Repositioning Tip
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14, top: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.pan_tool_alt_outlined,
                                    size: 13,
                                    color: AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Drag floating bubble anywhere to reposition',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }
}

/// An interactive glassmorphic card tile matching AIRAMP's student design system.
class _StudentActionCardTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isFullWidth;

  const _StudentActionCardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isFullWidth = false,
  });

  @override
  State<_StudentActionCardTile> createState() => _StudentActionCardTileState();
}

class _StudentActionCardTileState extends State<_StudentActionCardTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;

    if (widget.isFullWidth) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _controller.forward().then((_) {
                if (mounted) _controller.reverse();
              });
              widget.onTap();
            },
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            borderRadius: BorderRadius.circular(18),
            splashColor: widget.color.withValues(alpha: 0.14),
            highlightColor: widget.color.withValues(alpha: 0.08),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.72),
                    isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.45),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.88),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.60),
                    blurRadius: 1,
                    offset: const Offset(0, -0.5),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.color.withValues(alpha: 0.22),
                          widget.color.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.color.withValues(alpha: 0.32),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        widget.icon,
                        size: 22,
                        color: widget.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Squarish elevated glassmorphic card
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _controller.forward().then((_) {
              if (mounted) _controller.reverse();
            });
            widget.onTap();
          },
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          borderRadius: BorderRadius.circular(20),
          splashColor: widget.color.withValues(alpha: 0.16),
          highlightColor: widget.color.withValues(alpha: 0.08),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.72),
                  isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.45),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.88),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.60),
                  blurRadius: 1,
                  offset: const Offset(0, -0.5),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Prominent icon squircle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.color.withValues(alpha: 0.22),
                        widget.color.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      size: 26,
                      color: widget.color,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
