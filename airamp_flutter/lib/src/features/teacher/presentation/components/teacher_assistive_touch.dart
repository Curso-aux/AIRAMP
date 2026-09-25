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
      barrierColor: Colors.black.withValues(alpha: 0.35),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth - 40.0).clamp(310.0, 360.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dismissible blurred backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.32),
                ),
              ),
            ),
          ),

          // Centered AIRAMP Card
          Center(
            child: Container(
              width: dialogWidth,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.border,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.text,
                                  letterSpacing: -0.2,
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
                          icon: Icon(Icons.close_rounded, size: 20, color: AppTheme.textMuted),
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: AppTheme.border),

                  // 2-column Grid of 6 Action Tiles
                  Padding(
                    padding: const EdgeInsets.all(16),
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
                            const SizedBox(width: 10),
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
                        const SizedBox(height: 10),
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
                            const SizedBox(width: 10),
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
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionCardTile(
                                icon: Icons.assignment_turned_in_outlined,
                                title: 'Live Scores',
                                subtitle: 'Submissions health',
                                color: const Color(0xFFF59E0B),
                                onTap: onScores,
                              ),
                            ),
                            const SizedBox(width: 10),
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
                        const SizedBox(height: 10),
                        _ActionCardTile(
                          icon: Icons.person_outline,
                          title: 'Profile & Settings',
                          subtitle: 'Account details, appearance & security',
                          color: const Color(0xFF6366F1),
                          onTap: onProfile,
                        ),
                      ],
                    ),
                  ),

                  // Bottom Repositioning Tip
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.border.withValues(alpha: 0.25),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(21),
                        bottomRight: Radius.circular(21),
                      ),
                    ),
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
        ],
      ),
    );
  }
}

/// An interactive card tile matching AIRAMP's design system.
class _ActionCardTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
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
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
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
          splashColor: widget.color.withValues(alpha: 0.12),
          highlightColor: widget.color.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.border,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Icon pill
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      size: 20,
                      color: widget.color,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Text column
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
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
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
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
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
    );
  }
}
