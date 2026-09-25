import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';

/// A floating, draggable quick actions bubble styled to match AIRAMP's theme for students.
///
/// Features:
/// - Free drag & pan across the screen with boundary clamping.
/// - Spring edge-snapping to the nearest edge (left or right).
/// - Styled using AIRAMP's brand theme (teal gradient button with touch_app/pan_tool icon).
/// - Smooth idle dimming (opacity 0.65) after 3.5s of inactivity.
/// - Expands on tap into a clean AIRAMP-themed dialog with student quick action cards.
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

class _StudentAssistiveTouchState extends ConsumerState<StudentAssistiveTouch>
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
  }

  void _onPanStart(DragStartDetails details) {
    _wakeUp();
    _dragStartPos = _position;
    _dragStartTime = DateTime.now();
    setState(() => _isDragging = true);
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _wakeUp();
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top + 10.0;
    final bottomPadding = mediaQuery.padding.bottom + 80.0;

    final minX = _edgePadding;
    final maxX = screenWidth - _buttonSize - _edgePadding;
    final minY = topPadding;
    final maxY = screenHeight - _buttonSize - bottomPadding;

    setState(() {
      _position = Offset(
        (_position.dx + details.delta.dx).clamp(minX, maxX),
        (_position.dy + details.delta.dy).clamp(minY, maxY),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDragging = false);

    final dragDistance = (_position - _dragStartPos).distance;
    final dragDuration = DateTime.now().difference(_dragStartTime);

    // If it was just a tap without drag, trigger menu open
    if (dragDistance < 6.0 && dragDuration.inMilliseconds < 250) {
      _openMenu();
      return;
    }

    _snapToNearestEdge(details.velocity.pixelsPerSecond);
    _startIdleTimer();
  }

  void _snapToNearestEdge(Offset velocity) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top + 10.0;
    final bottomPadding = mediaQuery.padding.bottom + 80.0;

    final minX = _edgePadding;
    final maxX = screenWidth - _buttonSize - _edgePadding;
    final minY = topPadding;
    final maxY = screenHeight - _buttonSize - bottomPadding;

    final centerX = screenWidth / 2;
    double targetX;

    // Use horizontal velocity bias if fast enough, otherwise geometric proximity
    if (velocity.dx.abs() > 400) {
      targetX = velocity.dx > 0 ? maxX : minX;
    } else {
      targetX = (_position.dx + _buttonSize / 2 < centerX) ? minX : maxX;
    }

    // Apply vertical momentum slightly
    final targetY = (_position.dy + velocity.dy * 0.1).clamp(minY, maxY);

    _snapAnimation = Tween<Offset>(
      begin: _position,
      end: Offset(targetX, targetY),
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutCubic,
    ));

    _snapController.forward(from: 0.0);
  }

  void _openMenu() {
    _wakeUp();
    HapticFeedback.mediumImpact();
    setState(() => _isMenuOpen = true);

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
    final screenHeight = mediaQuery.size.height;

    // Default position at bottom-right edge if uninitialized
    if (!_isInitialized) {
      final initX = (screenWidth - _buttonSize - _edgePadding).clamp(
        _edgePadding,
        double.infinity,
      );
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
                          icon: Icon(Icons.close_rounded, size: 20, color: AppTheme.textMuted),
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: AppTheme.border),

                  // 2-column Grid of Action Tiles
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StudentActionCardTile(
                                icon: Icons.menu_book_outlined,
                                title: 'My Courses',
                                subtitle: 'Subjects & units',
                                color: const Color(0xFF3B82F6),
                                onTap: onCourses,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StudentActionCardTile(
                                icon: Icons.calendar_month_outlined,
                                title: 'Timetable',
                                subtitle: 'Class schedule',
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
                              child: _StudentActionCardTile(
                                icon: Icons.quiz_outlined,
                                title: 'Quizzes',
                                subtitle: 'Assigned tasks',
                                color: const Color(0xFF0D9488),
                                onTap: onQuizzes,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StudentActionCardTile(
                                icon: Icons.bar_chart_outlined,
                                title: 'My Progress',
                                subtitle: 'Grades & stats',
                                color: const Color(0xFFF59E0B),
                                onTap: onProgress,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _StudentActionCardTile(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: 'Ask Teacher',
                                subtitle: 'Chat & questions',
                                color: const Color(0xFF8B5CF6),
                                onTap: onChat,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StudentActionCardTile(
                                icon: Icons.campaign_outlined,
                                title: 'Bulletins',
                                subtitle: 'Announcements',
                                color: const Color(0xFF0EA5E9),
                                onTap: onAnnouncements,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _StudentActionCardTile(
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

/// An interactive card tile matching AIRAMP's student design system.
class _StudentActionCardTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _StudentActionCardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
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
                color: AppTheme.border.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
