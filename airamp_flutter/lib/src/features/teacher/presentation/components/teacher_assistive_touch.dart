import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';

import '../../../../core/components/aira/aira_floating_assistant.dart';
import '../../../../routing/app_router.dart';

/// A floating, draggable quick actions bubble styled to match AIRAMP's theme.
///
/// Features:
/// - Free drag & pan across the screen with boundary clamping.
/// - Spring edge-snapping to the nearest edge (left or right).
/// - Styled using AIRAMP's brand theme (teal gradient button with bolt/shortcut icon).
/// - Smooth idle dimming (opacity 0.65) after 3.5s of inactivity.
/// - Expands on tap into a clean AIRAMP-themed dialog with 6 quick action cards.
/// - Hold for 4.5s to trigger screen scanning and AIRA text reading aloud with fluent English girl voice!
class TeacherAssistiveTouch extends ConsumerStatefulWidget {
  final VoidCallback onCurriculum;
  final VoidCallback onSchedule;
  final VoidCallback onScores;
  final VoidCallback onStudents;
  final VoidCallback onCreateQuiz;
  final VoidCallback onAnnounce;
  final VoidCallback onProfile;

  const TeacherAssistiveTouch({
    super.key,
    required this.onCurriculum,
    required this.onSchedule,
    required this.onScores,
    required this.onStudents,
    required this.onCreateQuiz,
    required this.onAnnounce,
    required this.onProfile,
  });

  @override
  ConsumerState<TeacherAssistiveTouch> createState() => _TeacherAssistiveTouchState();
}

class _TeacherAssistiveTouchState extends ConsumerState<TeacherAssistiveTouch> {
  bool _isMenuOpen = false;
  BuildContext? _activeDialogContext;

  void _closeMenu() {
    if (_activeDialogContext != null &&
        _activeDialogContext!.mounted &&
        Navigator.of(_activeDialogContext!).canPop()) {
      Navigator.of(_activeDialogContext!).pop();
    } else {
      final targetContext = rootNavigatorKey.currentContext ?? context;
      if (targetContext.mounted && Navigator.of(targetContext).canPop()) {
        Navigator.of(targetContext).pop();
      }
    }
    if (mounted) {
      setState(() {
        _isMenuOpen = false;
        _activeDialogContext = null;
      });
    } else {
      _isMenuOpen = false;
      _activeDialogContext = null;
    }
  }

  void _openMenu() {
    HapticFeedback.mediumImpact();

    // Toggle behavior: if quick actions dialog is already open, close it!
    if (_isMenuOpen) {
      _closeMenu();
      return;
    }

    final targetContext = rootNavigatorKey.currentContext ?? context;
    setState(() => _isMenuOpen = true);

    showGeneralDialog(
      context: targetContext,
      barrierDismissible: true,
      barrierLabel: 'Quick Actions Hub',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, anim1, anim2) {
        _activeDialogContext = dialogContext;
        return _QuickActionsMenuDialog(
          onCurriculum: () {
            _closeMenu();
            widget.onCurriculum();
          },
          onSchedule: () {
            _closeMenu();
            widget.onSchedule();
          },
          onScores: () {
            _closeMenu();
            widget.onScores();
          },
          onStudents: () {
            _closeMenu();
            widget.onStudents();
          },
          onCreateQuiz: () {
            _closeMenu();
            widget.onCreateQuiz();
          },
          onAnnounce: () {
            _closeMenu();
            widget.onAnnounce();
          },
          onProfile: () {
            _closeMenu();
            widget.onProfile();
          },
        );
      },
      transitionBuilder: (dialogContext, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isMenuOpen = false;
          _activeDialogContext = null;
        });
      } else {
        _isMenuOpen = false;
        _activeDialogContext = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AiraFloatingAssistant(
      onOpenMenu: _openMenu,
      isVisible: !_isMenuOpen,
    );
  }
}

/// The AIRAMP-styled expanded Quick Actions dialog for Teachers.
class TeacherQuickActionsMenuDialog extends ConsumerWidget {
  final VoidCallback onCurriculum;
  final VoidCallback onSchedule;
  final VoidCallback onScores;
  final VoidCallback onStudents;
  final VoidCallback onCreateQuiz;
  final VoidCallback onAnnounce;
  final VoidCallback onProfile;

  const TeacherQuickActionsMenuDialog({
    super.key,
    required this.onCurriculum,
    required this.onSchedule,
    required this.onScores,
    required this.onStudents,
    required this.onCreateQuiz,
    required this.onAnnounce,
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
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.20),
                ),
              ),
            ),
          ),

          // Centered Institutional Dialog Card
          Center(
            child: Container(
              width: dialogWidth,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                    blurRadius: 28,
                    spreadRadius: 0,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
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
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        // Dialog Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 6, 12, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(alpha: isDark ? 0.28 : 0.15),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.grid_view_rounded,
                                    size: 20,
                                    color: AppTheme.primary,
                                  ),
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
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.text,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Teacher shortcuts & authoring tools',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w400,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                                ),
                                tooltip: 'Close',
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),

                        // Institutional Hairline Divider
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        ),

                        // 2-column Grid of Action Tiles
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _TeacherActionCardTile(
                                      icon: Icons.quiz_outlined,
                                      title: 'Create Quiz',
                                      subtitle: 'Draft & launch',
                                      onTap: onCreateQuiz,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TeacherActionCardTile(
                                      icon: Icons.campaign_outlined,
                                      title: 'Announce',
                                      subtitle: 'Post updates',
                                      onTap: onAnnounce,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _TeacherActionCardTile(
                                      icon: Icons.menu_book_outlined,
                                      title: 'Curriculum',
                                      subtitle: 'Subjects & units',
                                      onTap: onCurriculum,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TeacherActionCardTile(
                                      icon: Icons.calendar_month_outlined,
                                      title: 'Schedule',
                                      subtitle: 'Class timetable',
                                      onTap: onSchedule,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _TeacherActionCardTile(
                                      icon: Icons.assignment_turned_in_outlined,
                                      title: 'Live Scores',
                                      subtitle: 'Submissions health',
                                      onTap: onScores,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TeacherActionCardTile(
                                      icon: Icons.people_alt_outlined,
                                      title: 'Students',
                                      subtitle: 'Section roster',
                                      onTap: onStudents,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _TeacherActionCardTile(
                                icon: Icons.person_outline_rounded,
                                title: 'Profile & Settings',
                                subtitle: 'Account details, appearance & security',
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
        ],
      ),
    );
  }
}

typedef _QuickActionsMenuDialog = TeacherQuickActionsMenuDialog;

/// An institutional card tile matching AIRAMP's academic teacher design system.
class _TeacherActionCardTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isFullWidth;

  const _TeacherActionCardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isFullWidth = false,
  });

  @override
  State<_TeacherActionCardTile> createState() => _TeacherActionCardTileState();
}

class _TeacherActionCardTileState extends State<_TeacherActionCardTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutCubic,
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
    final accentColor = AppTheme.primary;
    final cardBg = isDark ? const Color(0xFF222F42) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF33455E) : const Color(0xFFE2E8F0);

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
            borderRadius: BorderRadius.circular(14),
            splashColor: accentColor.withValues(alpha: 0.08),
            highlightColor: accentColor.withValues(alpha: 0.04),
            child: Ink(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: cardBorder,
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.16 : 0.09),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accentColor.withValues(alpha: isDark ? 0.28 : 0.15),
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        widget.icon,
                        size: 20,
                        color: accentColor,
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
                            fontWeight: FontWeight.w600,
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
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Grid action card
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
          borderRadius: BorderRadius.circular(14),
          splashColor: accentColor.withValues(alpha: 0.08),
          highlightColor: accentColor.withValues(alpha: 0.04),
          child: Ink(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cardBorder,
                width: 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.16 : 0.09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: isDark ? 0.28 : 0.15),
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      size: 22,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
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
