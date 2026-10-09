import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A faithful Flutter port of Aceternity UI's iconic `PlaceholdersAndVanishInput` component.
///
/// Features:
/// 1. Smoothly cycling placeholders with vertical slide-and-fade transitions.
/// 2. Sleek pill-shaped container with subtle border glow and responsive submit button.
/// 3. Signature particle vanish effect: text disperses into floating evaporating particles upon submit.
class PlaceholdersAndVanishInput extends StatefulWidget {
  final List<String> placeholders;
  final ValueChanged<String>? onChange;
  final ValueChanged<String>? onSubmit;
  final String? initialValue;
  final double? width;

  const PlaceholdersAndVanishInput({
    super.key,
    required this.placeholders,
    this.onChange,
    this.onSubmit,
    this.initialValue,
    this.width,
  });

  @override
  State<PlaceholdersAndVanishInput> createState() => _PlaceholdersAndVanishInputState();
}

class _PlaceholdersAndVanishInputState extends State<PlaceholdersAndVanishInput>
    with TickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  // Placeholder cycling state
  int _currentPlaceholderIndex = 0;
  Timer? _placeholderTimer;

  // Vanish particle animation state
  late final AnimationController _vanishController;
  final List<_VanishParticle> _particles = [];
  bool _isVanishing = false;
  String _vanishingText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();

    _vanishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..addListener(() {
        if (_isVanishing) {
          setState(() {
            for (final p in _particles) {
              p.update(_vanishController.value);
            }
          });
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _isVanishing = false;
            _particles.clear();
            _vanishingText = '';
          });
        }
      });

    _startPlaceholderCycle();
  }

  void _startPlaceholderCycle() {
    _placeholderTimer?.cancel();
    if (widget.placeholders.isEmpty) return;

    final bool isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) return;

    _placeholderTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (!mounted) return;
      if (_controller.text.isEmpty && !_focusNode.hasFocus) {
        setState(() {
          _currentPlaceholderIndex =
              (_currentPlaceholderIndex + 1) % widget.placeholders.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _placeholderTimer?.cancel();
    _vanishController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _triggerVanishAndSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty && !_isVanishing) {
      // If user submits empty, use current placeholder
      if (widget.placeholders.isNotEmpty) {
        final currentPh = widget.placeholders[_currentPlaceholderIndex];
        _controller.text = currentPh;
        _triggerVanishAndSubmit();
      }
      return;
    }

    if (_isVanishing) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = isDark ? Colors.white : const Color(0xFF0F172A);

    // Spawn 45 randomized disperse particles based on text length
    final random = math.Random();
    _particles.clear();
    final int particleCount = (text.length * 5).clamp(32, 64);

    for (int i = 0; i < particleCount; i++) {
      final double startX = 20.0 + (random.nextDouble() * 200.0).clamp(0.0, 240.0);
      final double startY = 24.0 + (random.nextDouble() * 12.0 - 6.0);
      final double angle = (random.nextDouble() * math.pi) - (math.pi / 2); // outward/upward
      final double speed = random.nextDouble() * 45.0 + 15.0;

      _particles.add(
        _VanishParticle(
          x: startX,
          y: startY,
          vx: math.cos(angle) * speed * (random.nextBool() ? 1 : -0.8),
          vy: -random.nextDouble() * 38.0 - 8.0,
          size: random.nextDouble() * 2.5 + 1.2,
          color: dotColor,
        ),
      );
    }

    setState(() {
      _isVanishing = true;
      _vanishingText = text;
      _controller.clear();
    });

    widget.onChange?.call('');
    widget.onSubmit?.call(_vanishingText);

    _vanishController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPlaceholder = widget.placeholders.isNotEmpty
        ? widget.placeholders[_currentPlaceholderIndex]
        : 'Type something...';

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.width ?? 600,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          // ── Outer Pill Input Container ──────────────────────────
          Container(
            height: 52,
            padding: const EdgeInsets.only(left: 18, right: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.12),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                if (_focusNode.hasFocus)
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 0),
                  ),
              ],
            ),
            child: Row(
              children: [
                // Text Field & Animated Cycling Placeholder
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Cycling Animated Placeholder
                      if (_controller.text.isEmpty && !_isVanishing)
                        IgnorePointer(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 380),
                            transitionBuilder: (child, animation) {
                              final inAnimation = Tween<Offset>(
                                begin: const Offset(0.0, 0.5),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ));
                              return SlideTransition(
                                position: inAnimation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              currentPlaceholder,
                              key: ValueKey<String>(currentPlaceholder),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                      // Actual Text Input
                      TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        cursorColor: AppTheme.primary,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          setState(() {});
                          widget.onChange?.call(val);
                        },
                        onSubmitted: (_) => _triggerVanishAndSubmit(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Submit Button Pill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _controller.text.trim().isNotEmpty
                        ? AppTheme.primary
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.black.withValues(alpha: 0.08)),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _triggerVanishAndSubmit,
                    icon: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: _controller.text.trim().isNotEmpty
                          ? Colors.black
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    tooltip: 'Submit query',
                  ),
                ),
              ],
            ),
          ),

          // ── Vanish Particles Layer ──────────────────────────────
          if (_isVanishing)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _VanishParticlesPainter(
                    particles: _particles,
                    progress: _vanishController.value,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VanishParticle {
  double x;
  double y;
  final double vx;
  final double vy;
  final double size;
  final Color color;
  double alpha = 1.0;

  _VanishParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
  });

  void update(double progress) {
    x += vx * 0.035;
    y += vy * 0.035;
    alpha = (1.0 - progress * 1.15).clamp(0.0, 1.0);
  }
}

class _VanishParticlesPainter extends CustomPainter {
  final List<_VanishParticle> particles;
  final double progress;

  _VanishParticlesPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      if (p.alpha <= 0.01) continue;
      paint.color = p.color.withValues(alpha: p.alpha);
      canvas.drawCircle(Offset(p.x, p.y), p.size * (1.0 - progress * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VanishParticlesPainter oldDelegate) => true;
}
