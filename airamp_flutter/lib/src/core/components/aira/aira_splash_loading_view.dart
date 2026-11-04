import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../theme/app_theme.dart';

/// Studio-grade splash screen featuring:
/// 1. Living monochrome Halftone dot-matrix background animation.
/// 2. Natural, uncropped Chibi Mascot character presentation with breathing bob and ground shadow.
/// 3. Character expression animation (Idle -> Active/Speaking greeting).
/// 4. Crisp bubble "pop" audio feedback with zero-latency haptic click.
/// 5. Clean white-mode default adhering to DepEd SHS aesthetics without generic template cliches.
class AiraSplashLoadingView extends StatefulWidget {
  final bool isDark;

  const AiraSplashLoadingView({
    super.key,
    required this.isDark,
  });

  @override
  State<AiraSplashLoadingView> createState() => _AiraSplashLoadingViewState();
}

class _AiraSplashLoadingViewState extends State<AiraSplashLoadingView>
    with TickerProviderStateMixin {
  // Entrance spring pop
  late AnimationController _popController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Gentle floating / breathing
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late Animation<double> _shadowScaleAnimation;

  // Background halftone continuous wave
  late AnimationController _halftoneController;

  // Character expression transition
  int _avatarIndex = 0; // 0 = mascot/active, 1 = idle/speaking

  AudioPlayer? _audioPlayer;
  bool _soundPlayed = false;

  @override
  void initState() {
    super.initState();

    // 1. Pop & spring entrance
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.12).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 0.96).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1.0).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 15,
      ),
    ]).animate(_popController);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _popController, curve: const Interval(0.0, 0.45, curve: Curves.easeIn)),
    );

    // 2. Idle floating & shadow breathing
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _floatAnimation = Tween<double>(begin: -7.0, end: 7.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _shadowScaleAnimation = Tween<double>(begin: 1.15, end: 0.85).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    // 3. Halftone screen drift & ripple (continuous 12s loop)
    _halftoneController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    _startAnimationAndSound();
  }

  Future<void> _startAnimationAndSound() async {
    // Start continuous halftone background animation immediately
    _halftoneController.repeat();

    // Slight microtask delay to allow first layout frame to settle
    await Future.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;

    // Trigger audio pop & tactile feedback
    _playPopSound();

    // Spring the character into view
    _popController.forward().then((_) {
      if (mounted) {
        _floatController.repeat(reverse: true);
        // Expression shift: active greeting
        setState(() => _avatarIndex = 1);
      }
    });
  }

  Future<void> _playPopSound() async {
    if (_soundPlayed) return;
    _soundPlayed = true;

    // Instant hardware haptic & click feedback
    try {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}

    // Bubbly pop audio playback
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer?.setVolume(0.9);
      await _audioPlayer?.play(AssetSource('audio/pop.wav'));
    } catch (e) {
      debugPrint('[AiraSplash] Audio playback notice: $e');
    }
  }

  @override
  void dispose() {
    _popController.dispose();
    _floatController.dispose();
    _halftoneController.dispose();
    try {
      _audioPlayer?.stop();
      _audioPlayer?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC);
    final primaryColor = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final titleColor = isDark ? AppTheme.darkText : const Color(0xFF0F172A);
    final subtitleColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Animated Living Halftone Background ─────────────────
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _halftoneController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _SplashHalftonePainter(
                    progress: _halftoneController.value,
                    isDark: isDark,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),

          // ── 2. Foreground Chibi & Branding ─────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Mascot Character & Ground Shadow
                AnimatedBuilder(
                  animation: Listenable.merge([_popController, _floatController]),
                  builder: (context, _) {
                    final floatY = _popController.isCompleted ? _floatAnimation.value : 0.0;
                    final shadowScale = _popController.isCompleted ? _shadowScaleAnimation.value : 1.0;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: Offset(0, floatY),
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: _buildChibiMascot(isDark),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Soft elliptical contact shadow (contracts as chibi floats up)
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Transform.scale(
                            scale: _scaleAnimation.value * shadowScale,
                            child: Container(
                              width: 100,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isDark ? Colors.black : const Color(0xFF0F172A))
                                        .withValues(alpha: isDark ? 0.35 : 0.12),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),

                // Branding & Subtitle
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'AIRA',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3.5,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              'SHS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Department of Education · Smart Learning',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Minimalist, elegant dot-pulse indicator
                      _buildPulsingDots(primaryColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the uncropped, natural Chibi mascot with subtle expression shift
  Widget _buildChibiMascot(bool isDark) {
    // Primary mascot: authentic full-color chibi with graduation cap
    final primaryAsset = _avatarIndex == 0
        ? 'assets/images/aira_mascot_logo.png'
        : 'assets/images/aira_avatar_active.png';

    return SizedBox(
      width: 155,
      height: 155,
      child: Image.asset(
        primaryAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to idle avatar if mascot is unavailable
          return Image.asset(
            'assets/images/aira_avatar_idle.png',
            fit: BoxFit.contain,
          );
        },
      ),
    );
  }

  /// Subtle animated loading dots replacing the generic circular spinner
  Widget _buildPulsingDots(Color color) {
    return SizedBox(
      width: 48,
      height: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _floatController,
            builder: (context, _) {
              final phase = (_floatController.value + (index * 0.3)) % 1.0;
              final opacity = 0.25 + (math.sin(phase * math.pi) * 0.75).abs().clamp(0.0, 0.75);
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: opacity),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Authentic, high-performance monochrome Halftone screen painter
/// Renders an undulating dot-matrix grid with subtle organic waves
class _SplashHalftonePainter extends CustomPainter {
  final double progress;
  final bool isDark;

  static const double _spacing = 18.0;
  static const double _rowHeight = 15.588; // 18 * sqrt(3) / 2 (Hexagonal print raster)

  _SplashHalftonePainter({
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final dotColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final double phase = progress * 2.0 * math.pi;
    final int cols = (size.width / _spacing).ceil() + 2;
    final int rows = (size.height / _rowHeight).ceil() + 2;

    final double centerX = size.width * 0.5;
    final double centerY = size.height * 0.45;
    final double maxDist = math.max(centerX, centerY);

    // Continuous subtle lattice drift
    final double dx = (progress * _spacing) % _spacing;
    final double dy = (progress * _rowHeight) % _rowHeight;

    for (int r = -1; r < rows; r++) {
      final double y = (r * _rowHeight) - dy;
      final double rowOffset = (r % 2 != 0) ? (_spacing * 0.5) : 0.0;

      for (int c = -1; c < cols; c++) {
        final double x = (c * _spacing) + rowOffset - dx;

        if (x < -8 || x > size.width + 8 || y < -8 || y > size.height + 8) {
          continue;
        }

        // Vignette weight: subtle in the hero center so the chibi stands out cleanly,
        // increasing slightly toward edges for authentic risograph depth
        final double distToCenter = math.sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
        final double vignette = (distToCenter / maxDist).clamp(0.2, 1.1);

        // Harmonic traveling wave
        final double wave1 = math.sin((x * 0.012) + (y * 0.012) - phase);
        final double wave2 = math.cos((x * 0.016) - (y * 0.008) + (phase * 0.8));
        final double wave = (wave1 + wave2) * 0.5;

        // Fine dot radius: from 0.5px to 1.7px
        final double radius = (0.75 + (wave * 0.55 * vignette)).clamp(0.4, 1.75);

        // Soft ink opacity: keeps the background elegant without overwhelming the screen
        final double alpha = isDark
            ? (0.04 + (wave + 1.0) * 0.035 * vignette).clamp(0.02, 0.12)
            : (0.05 + (wave + 1.0) * 0.045 * vignette).clamp(0.03, 0.14);

        dotPaint.color = dotColor.withValues(alpha: alpha);
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SplashHalftonePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
