import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';

/// A floating, draggable quick actions bubble styled to match AIRAMP's theme.
///
/// Features:
/// - Free drag & pan across the screen with boundary clamping.
/// - Spring edge-snapping to the nearest edge (left or right).
/// - Styled using AIRAMP's brand theme (teal gradient button with bolt/shortcut icon).
/// - Smooth idle dimming (opacity 0.65) after 3.5s of inactivity.
/// - Expands on tap into a clean AIRAMP-themed dialog with 6 quick action cards.
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

class _TeacherAssistiveTouchState extends ConsumerState<TeacherAssistiveTouch>
    with SingleTickerProviderStateMixin {
  static const double _buttonSize = 52.0;
  static const double _edgePadding = 12.0;

  Offset _position = Offset.zero;
  bool _isInitialized = false;
  bool _isDragging = false;
  bool _isIdle = false;
  bool _isMenuOpen = false;

  Timer? _idleTimer;
  late AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  Offset _dragStartPos = Offset.zero;
  DateTime _dragStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        if (_snapAnimation != null) {
          setState(() {
            _position = _snapAnimation!.value;
          });
        }
      });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _snapController.dispose();
    super.dispose();
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && !_isDragging && !_isMenuOpen) {
        setState(() => _isIdle = true);
      }
    });
  }

  void _wakeUp() {
    _idleTimer?.cancel();
    if (_isIdle) {
      setState(() => _isIdle = false);
    }
  }

  void _onPanDown(DragDownDetails details) {
    _wakeUp();
    if (_snapController.isAnimating) {
      _snapController.stop();
    }
    _dragStartPos = _position;
    _dragStartTime = DateTime.now();
  }

  void _onPanStart(DragStartDetails details) {
    _wakeUp();
    setState(() => _isDragging = true);
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom;

    final minY = 12.0;
    final maxY = (screenHeight - _buttonSize - 16.0).clamp(minY, double.infinity);
    final minX = _edgePadding;
    final maxX = (screenWidth - _buttonSize - _edgePadding).clamp(minX, double.infinity);

    final newX = (_position.dx + details.delta.dx).clamp(minX, maxX);
    final newY = (_position.dy + details.delta.dy).clamp(minY, maxY);

    setState(() {
      _position = Offset(newX, newY);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDragging = false);

    final dragDistance = (_position - _dragStartPos).distance;
    final dragDuration = DateTime.now().difference(_dragStartTime).inMilliseconds;

    // Detect tap vs drag
    if (dragDistance < 6.0 && dragDuration < 300) {
      _openMenu();
      return;
    }

    _snapToNearestEdge(details.velocity.pixelsPerSecond);
  }

  void _snapToNearestEdge(Offset velocity) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom;

    final minY = 12.0;
    final maxY = (screenHeight - _buttonSize - 16.0).clamp(minY, double.infinity);
    final minX = _edgePadding;
    final maxX = (screenWidth - _buttonSize - _edgePadding).clamp(minX, double.infinity);

    final centerX = _position.dx + (_buttonSize / 2);
    final snapLeft = velocity.dx < -300 || (velocity.dx.abs() <= 300 && centerX < screenWidth / 2);

    final targetX = snapLeft ? minX : maxX;
    final targetY = _position.dy.clamp(minY, maxY);

    _snapAnimation = Tween<Offset>(
      begin: _position,
      end: Offset(targetX, targetY),
    ).animate(
      CurvedAnimation(
        parent: _snapController,
        curve: Curves.easeOutBack,
      ),
    );

    _snapController.forward(from: 0.0).then((_) {
      _startIdleTimer();
    });
  }

  void _openMenu() {
    _wakeUp();
    setState(() => _isMenuOpen = true);
    HapticFeedback.mediumImpact();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Quick Actions Hub',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, anim1, anim2) {
        return _QuickActionsMenuDialog(
          onCurriculum: () {
            Navigator.of(dialogContext).pop();
            widget.onCurriculum();
          },
          onSchedule: () {
            Navigator.of(dialogContext).pop();
            widget.onSchedule();
          },
          onScores: () {
            Navigator.of(dialogContext).pop();
            widget.onScores();
          },
          onStudents: () {
            Navigator.of(dialogContext).pop();
            widget.onStudents();
          },
          onCreateQuiz: () {
            Navigator.of(dialogContext).pop();
            widget.onCreateQuiz();
          },
          onAnnounce: () {
            Navigator.of(dialogContext).pop();
            widget.onAnnounce();
          },
          onProfile: () {
            Navigator.of(dialogContext).pop();
            widget.onProfile();
          },
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() => _isMenuOpen = false);
        _startIdleTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom;

    if (!_isInitialized) {
      final initX = screenWidth - _buttonSize - _edgePadding;
      final initY = (screenHeight * 0.62).clamp(
        12.0,
        (screenHeight - _buttonSize - 16.0).clamp(12.0, double.infinity),
      );
      _position = Offset(initX, initY);
      _isInitialized = true;
      _startIdleTimer();
    } else {
      final minX = _edgePadding;
      final maxX = (screenWidth - _buttonSize - _edgePadding).clamp(minX, double.infinity);
      final minY = 12.0;
      final maxY = (screenHeight - _buttonSize - 16.0).clamp(minY, double.infinity);

      if (_position.dx > maxX || _position.dy > maxY) {
        _position = Offset(_position.dx.clamp(minX, maxX), _position.dy.clamp(minY, maxY));
      }
    }

    final opacity = _isDragging
        ? 1.0
        : (_isIdle ? 0.65 : 0.95);

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanDown: _onPanDown,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTap: _openMenu,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 220),
          child: Container(
            width: _buttonSize,
            height: _buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primary,
                  AppTheme.primaryDark,
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Icon(
                  _isDragging ? Icons.pan_tool_rounded : Icons.touch_app_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The AIRAMP-styled expanded Quick Actions dialog.
class _QuickActionsMenuDialog extends ConsumerWidget {
  final VoidCallback onCurriculum;
  final VoidCallback onSchedule;
  final VoidCallback onScores;
  final VoidCallback onStudents;
  final VoidCallback onCreateQuiz;
  final VoidCallback onAnnounce;
  final VoidCallback onProfile;

  const _QuickActionsMenuDialog({
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
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.primary.withValues(alpha: 0.28),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.touch_app_rounded,
                                      color: AppTheme.primary,
                                      size: 20,
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
                                          'Teacher shortcuts & authoring tools',
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
                                        child: _ActionCardTile(
                                          icon: Icons.quiz_outlined,
                                          title: 'Create Quiz',
                                          subtitle: 'Draft & launch',
                                          color: const Color(0xFF0D9488),
                                          onTap: onCreateQuiz,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _ActionCardTile(
                                          icon: Icons.campaign_outlined,
                                          title: 'Announce',
                                          subtitle: 'Post updates',
                                          color: const Color(0xFF8B5CF6),
                                          onTap: onAnnounce,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ActionCardTile(
                                          icon: Icons.menu_book_outlined,
                                          title: 'Curriculum',
                                          subtitle: 'Subjects & units',
                                          color: const Color(0xFF3B82F6),
                                          onTap: onCurriculum,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _ActionCardTile(
                                          icon: Icons.calendar_month_outlined,
                                          title: 'Schedule',
                                          subtitle: 'Class timetable',
                                          color: const Color(0xFF14B8A6),
                                          onTap: onSchedule,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ActionCardTile(
                                          icon: Icons.assignment_turned_in_outlined,
                                          title: 'Live Scores',
                                          subtitle: 'Submissions health',
                                          color: const Color(0xFF10B981),
                                          onTap: onScores,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _ActionCardTile(
                                          icon: Icons.people_alt_outlined,
                                          title: 'Students',
                                          subtitle: 'Section roster',
                                          color: const Color(0xFF0EA5E9),
                                          onTap: onStudents,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _ActionCardTile(
                                    icon: Icons.person_outline_rounded,
                                    title: 'Profile & Settings',
                                    subtitle: 'Account details, appearance & security',
                                    color: const Color(0xFF6366F1),
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

/// An interactive glassmorphic card tile matching AIRAMP's design system.
class _ActionCardTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isFullWidth;

  const _ActionCardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isFullWidth = false,
  });

  @override
  State<_ActionCardTile> createState() => _ActionCardTileState();
}

class _ActionCardTileState extends State<_ActionCardTile>
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
