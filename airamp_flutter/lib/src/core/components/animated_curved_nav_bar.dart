import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// A fluid animated curved navigation bar matching the scooped notch design
/// with an elevated floating bubble that glides horizontally across tabs.
class AnimatedCurvedNavBar extends StatefulWidget {
  final List<BottomNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double selectedFontSize;
  final double unselectedFontSize;

  const AnimatedCurvedNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.selectedFontSize = 11,
    this.unselectedFontSize = 10.5,
  });

  @override
  State<AnimatedCurvedNavBar> createState() => _AnimatedCurvedNavBarState();
}

class _AnimatedCurvedNavBarState extends State<AnimatedCurvedNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnim;
  late Animation<double> _bubbleScaleAnim;

  int _activeTargetIndex = 0;
  int _fromIndex = 0;

  static const double _barHeight = 62.0;
  static const double _notchRadius = 42.0;
  static const double _notchDepth = 29.0;
  static const double _bubbleSize = 42.0;
  static const double _restingBubbleTop = -20.0;
  static const double _popLiftHeight = 12.0;
  static const double _horizontalPadding = 16.0;

  // Apple-smooth fluid deceleration curve
  static const Curve _fluidCurve = Cubic(0.20, 0.0, 0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _activeTargetIndex = widget.currentIndex;
    _fromIndex = widget.currentIndex;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _positionAnim = Tween<double>(
      begin: widget.currentIndex.toDouble(),
      end: widget.currentIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: _fluidCurve,
    ));

    // Dynamic pop-up scale bounce: stretches on takeoff, compresses on descent, springs on landing
    _bubbleScaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.10)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.10, end: 0.94)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.94, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant AnimatedCurvedNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _animateTo(widget.currentIndex);
    }
  }

  void _animateTo(int targetIndex) {
    if (!mounted) return;
    _fromIndex = _activeTargetIndex;
    _activeTargetIndex = targetIndex;

    final distance = (targetIndex - _fromIndex).abs();
    // Dynamic duration: snappy for 1 tab, smooth & calm for multi-tab
    final durationMs = distance == 0 ? 260 : (270 + (distance * 32)).clamp(270, 380);
    _controller.duration = Duration(milliseconds: durationMs);

    final startPos = _positionAnim.value;
    final endPos = targetIndex.toDouble();

    _positionAnim = Tween<double>(
      begin: startPos,
      end: endPos,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: _fluidCurve,
    ));

    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = AppTheme.surface;
    final borderColor = isDark ? const Color(0xFF33455E) : const Color(0xFFCBD5E1);
    final count = widget.items.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final usableWidth = totalWidth - (_horizontalPadding * 2);
        final tabWidth = usableWidth / count;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final animatedPos = _positionAnim.value;
            final rawNotchX = _horizontalPadding + (animatedPos + 0.5) * tabWidth;
            const s = _notchRadius;
            final cx = rawNotchX.clamp(s + 4.0, totalWidth - s - 4.0);

            // Parabolic pop-up lift during flight: rests low, arcs up in flight, drops into notch
            final flightProgress = _controller.value;
            final popLift = math.sin(flightProgress * math.pi) * _popLiftHeight;
            final currentBubbleTop = _restingBubbleTop - popLift;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Curved & Scooped Background Path with drop shadow & continuous border
                CustomPaint(
                  size: Size(totalWidth, _barHeight),
                  painter: _ScoopNavBarPainter(
                    notchX: cx,
                    notchRadius: _notchRadius,
                    notchDepth: _notchDepth,
                    borderRadius: 20.0,
                    backgroundColor: surfaceColor,
                    borderColor: borderColor,
                    isDark: isDark,
                  ),
                ),

                // 2. Tab Item Labels and Inactive Resting Icons
                Positioned(
                  left: _horizontalPadding,
                  right: _horizontalPadding,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    children: List.generate(count, (index) {
                      final item = widget.items[index];
                      final distance = (animatedPos - index).abs().clamp(0.0, 1.0);
                      final isActive = index == _activeTargetIndex;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (index != widget.currentIndex) {
                              HapticFeedback.lightImpact();
                              widget.onTap(index);
                            } else {
                              // Tapping already active tab triggers playful pop-up bounce
                              HapticFeedback.selectionClick();
                              _animateTo(index);
                            }
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Inactive Resting Icon (softly fades out as bubble arrives)
                              Positioned(
                                top: 11,
                                child: Opacity(
                                  opacity: (distance - 0.15).clamp(0.0, 1.0),
                                  child: Transform.scale(
                                    scale: 0.80 + (0.20 * distance),
                                    child: IconTheme(
                                      data: IconThemeData(
                                        color: AppTheme.textMuted,
                                        size: 21,
                                      ),
                                      child: item.icon,
                                    ),
                                  ),
                                ),
                              ),

                              // Text Label
                              Positioned(
                                bottom: 7,
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontSize: isActive
                                        ? widget.selectedFontSize
                                        : widget.unselectedFontSize,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isActive
                                        ? AppTheme.text
                                        : AppTheme.textSecondary,
                                    letterSpacing: -0.2,
                                  ),
                                  child: Text(
                                    item.label ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // 3. Elevated Floating Circle (Bubble) with Pop-Up Jump & Spring
                Positioned(
                  left: cx - (_bubbleSize / 2),
                  top: currentBubbleTop,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _animateTo(_activeTargetIndex);
                      widget.onTap(_activeTargetIndex);
                    },
                    child: Transform.scale(
                      scale: _bubbleScaleAnim.value,
                      child: Container(
                        width: _bubbleSize,
                        height: _bubbleSize,
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: borderColor,
                            width: 1.3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.30 : 0.09,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            transitionBuilder: (child, anim) {
                              final scaleAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: anim,
                                  curve: const Interval(0.15, 1.0, curve: Curves.easeOutBack),
                                ),
                              );
                              final slideAnim = Tween<Offset>(
                                begin: const Offset(0.0, 0.45),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: anim,
                                  curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
                                ),
                              );
                              return SlideTransition(
                                position: slideAnim,
                                child: ScaleTransition(
                                  scale: scaleAnim,
                                  child: FadeTransition(opacity: anim, child: child),
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey<int>(_activeTargetIndex),
                              child: IconTheme(
                                data: IconThemeData(
                                  color: AppTheme.primary,
                                  size: 21,
                                ),
                                child: widget.items[_activeTargetIndex].activeIcon,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Custom painter that draws a smooth pill shape with a gentle, organic liquid wave scoop
/// centered dynamically at [notchX], cradling the circle completely from the outside.
class _ScoopNavBarPainter extends CustomPainter {
  final double notchX;
  final double notchRadius;
  final double notchDepth;
  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final bool isDark;

  const _ScoopNavBarPainter({
    required this.notchX,
    required this.notchRadius,
    required this.notchDepth,
    required this.borderRadius,
    required this.backgroundColor,
    required this.borderColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = borderRadius;
    final s = notchRadius;
    final d = notchDepth;
    final cx = notchX.clamp(s + 4.0, w - s - 4.0);

    // Adaptive corner radii to seamlessly connect corners into the wave
    final rTL = math.min(r, math.max(4.0, cx - s));
    final rTR = math.min(r, math.max(4.0, w - (cx + s)));

    // Main enclosed navbar boundary path
    final path = Path();

    // 1. Top-Left rounded corner
    path.moveTo(0, rTL);
    path.arcToPoint(Offset(rTL, 0), radius: Radius.circular(rTL));

    // 2. Horizontal segment to start of scoop notch
    path.lineTo(cx - s, 0);

    // 3. Wide, open cradle scoop that stays completely outside the icon circle
    path.cubicTo(
      cx - s * 0.55, 0.0,
      cx - s * 0.45, d,
      cx, d,
    );
    path.cubicTo(
      cx + s * 0.45, d,
      cx + s * 0.55, 0.0,
      cx + s, 0.0,
    );

    // 4. Horizontal segment to top-right corner
    path.lineTo(w - rTR, 0);
    path.arcToPoint(Offset(w, rTR), radius: Radius.circular(rTR));

    // 5. Right edge down to bottom-right corner
    path.lineTo(w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: Radius.circular(r));

    // 6. Bottom edge left to bottom-left corner
    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r));

    // 7. Left edge up to meet top-left corner
    path.lineTo(0, rTL);
    path.close();

    // Ambient drop shadow under navbar
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: isDark ? 0.30 : 0.07),
      10.0,
      false,
    );

    // Background fill
    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // One unified, seamless perimeter stroke
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScoopNavBarPainter oldDelegate) {
    return oldDelegate.notchX != notchX ||
        oldDelegate.notchRadius != notchRadius ||
        oldDelegate.notchDepth != notchDepth ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.isDark != isDark;
  }
}





