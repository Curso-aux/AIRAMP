import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// An authentic, living academic background featuring dynamic transitioning
/// campus and classroom photography layered seamlessly beneath an animated
/// monochrome halftone dot screen where the dots/pixels visibly ripple, glide,
/// and breathe in real time.
class HalftoneBackground extends StatefulWidget {
  final Widget child;
  final double opacity;
  final List<String>? images;
  final Duration slideDuration;
  final Duration transitionDuration;
  final bool enableBottomFade;
  final double bottomFadeStart;
  static bool enableAnimation = true;

  const HalftoneBackground({
    super.key,
    required this.child,
    this.opacity = 0.32,
    this.images,
    this.slideDuration = const Duration(seconds: 7),
    this.transitionDuration = const Duration(milliseconds: 1800),
    this.enableBottomFade = false,
    this.bottomFadeStart = 0.82,
  });

  @override
  State<HalftoneBackground> createState() => _HalftoneBackgroundState();
}

class _HalftoneBackgroundState extends State<HalftoneBackground>
    with TickerProviderStateMixin {
  late final AnimationController _halftoneController;
  late final AnimationController _crossFadeController;
  late final AnimationController _zoomController;
  final ValueNotifier<Offset?> _mouseNotifier = ValueNotifier<Offset?>(null);

  Timer? _slideTimer;
  int _currentImageIndex = 0;
  int _nextImageIndex = 1;
  bool _isTransitioning = false;

  static const List<String> _defaultImages = [
    'assets/images/ph_highschool_classroom_bg.jpg',
    'assets/images/ph_seniorhigh_science_bg.jpg',
    'assets/images/ph_highschool_study_bg.jpg',
    'assets/images/ph_seniorhigh_computer_bg.jpg',
    'assets/images/classroom_halftone_bg.jpg',
  ];

  List<String> get _images => widget.images ?? _defaultImages;

  // Soft, muted slate-cyan tint for dark mode (avoids harsh blinding white dots)
  static const ColorFilter _darkHalftoneFilter = ColorFilter.matrix([
    -0.55, 0, 0, 0, 130,
    0, -0.55, 0, 0, 145,
    0, 0, -0.55, 0, 165,
    0, 0, 0, 1, 0,
  ]);

  @override
  void initState() {
    super.initState();

    // 1. Continuous 16-second smooth looping halftone wave animation
    _halftoneController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );

    // 2. Smooth cross-fade controller for transitions between images
    _crossFadeController = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
    );

    // 3. Gentle ambient zoom (Ken Burns breath)
    _zoomController = AnimationController(
      vsync: this,
      duration: widget.slideDuration,
    );

    bool isTest = false;
    try {
      isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {}

    if (HalftoneBackground.enableAnimation && !isTest) {
      _halftoneController.repeat();
      _zoomController.forward();
      _startSlideTimer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache all background images for stutter-free cross-fades
    for (final img in _images) {
      precacheImage(AssetImage(img), context).catchError((_) {});
    }
  }

  void _startSlideTimer() {
    _slideTimer?.cancel();
    if (_images.length <= 1) return;

    _slideTimer = Timer.periodic(widget.slideDuration, (_) {
      if (!mounted) return;
      final images = _images;
      if (images.length <= 1) return;

      _nextImageIndex = (_currentImageIndex + 1) % images.length;
      setState(() {
        _isTransitioning = true;
      });

      _crossFadeController.forward(from: 0.0).then((_) {
        if (!mounted) return;
        setState(() {
          _currentImageIndex = _nextImageIndex;
          _isTransitioning = false;
        });
        _crossFadeController.reset();
        _zoomController.forward(from: 0.0);
      });
    });
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _halftoneController.dispose();
    _crossFadeController.dispose();
    _zoomController.dispose();
    _mouseNotifier.dispose();
    super.dispose();
  }

  Widget _buildImage(String assetPath) {
    final filename = assetPath.split('/').last;
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) {
        return Image.network(
          filename,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (c, e, s) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildCrossFadingImages() {
    final images = _images;
    if (images.isEmpty) return const SizedBox.shrink();

    final currentImg = images[_currentImageIndex % images.length];
    final nextImg = images[_nextImageIndex % images.length];

    return AnimatedBuilder(
      animation: Listenable.merge([_crossFadeController, _zoomController]),
      builder: (context, _) {
        final zoomScale = 1.0 + (_zoomController.value * 0.035);
        final curvedFade = Curves.easeInOutCubic.transform(_crossFadeController.value);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Current base image with gentle slow zoom
            Transform.scale(
              scale: zoomScale,
              child: _buildImage(currentImg),
            ),

            // Cross-fading next image
            if (_isTransitioning)
              Opacity(
                opacity: curvedFade.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 1.0 + ((1.0 - curvedFade) * 0.02),
                  child: _buildImage(nextImg),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return MouseRegion(
      onHover: (event) => _mouseNotifier.value = event.localPosition,
      onExit: (_) => _mouseNotifier.value = null,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 1. Solid theme background base
          Positioned.fill(
            child: Container(
              color: bgColor,
            ),
          ),

          // 2. Dynamic transitioning academic photos with subtle Ken Burns motion
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.18 : widget.opacity,
              child: ColorFiltered(
                colorFilter: isDark
                    ? _darkHalftoneFilter
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: _buildCrossFadingImages(),
              ),
            ),
          ),

          // 3. Animated monochrome halftone screen layer (dots/pixels rippling & gliding)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_halftoneController, _mouseNotifier]),
              builder: (context, _) {
                return CustomPaint(
                  painter: AnimatedHalftoneScreenPainter(
                    progress: _halftoneController.value,
                    mousePos: _mouseNotifier.value,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // 4. Radial backdrop vignette: clears out hero text area for max legibility without washing out the lower scene
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 0.85,
                  colors: isDark
                      ? [
                          AppTheme.darkBackground.withValues(alpha: 0.40),
                          AppTheme.darkBackground.withValues(alpha: 0.10),
                          Colors.transparent,
                        ]
                      : [
                          AppTheme.lightBackground.withValues(alpha: 0.30),
                          AppTheme.lightBackground.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // 5. Smooth bottom edge fade so it melts seamlessly into the page background
          if (widget.enableBottomFade)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            Colors.transparent,
                            Colors.transparent,
                            AppTheme.darkBackground.withValues(alpha: 0.60),
                            AppTheme.darkBackground,
                          ]
                        : [
                            Colors.transparent,
                            Colors.transparent,
                            const Color(0xFFF8FAFC).withValues(alpha: 0.65),
                            const Color(0xFFF8FAFC),
                          ],
                    stops: [
                      0.0,
                      widget.bottomFadeStart,
                      (widget.bottomFadeStart + 1.0) / 2,
                      1.0,
                    ],
                  ),
                ),
              ),
            ),

          // 6. Foreground content (scrollable layout, cards, buttons)
          widget.child,
        ],
      ),
    );
  }
}

/// Renders an authentic monochrome halftone dot screen where dots/pixels
/// continuously undulate in harmonic size waves, glide across the lattice,
/// and react to mouse hovering without introducing foreign colored circles.
class AnimatedHalftoneScreenPainter extends CustomPainter {
  final double progress;
  final Offset? mousePos;
  final bool isDark;

  static const double _spacing = 15.0;
  static const double _rowHeight = 13.0; // _spacing * sqrt(3) / 2 ≈ 12.99 (fine hexagonal print lattice)

  AnimatedHalftoneScreenPainter({
    required this.progress,
    required this.mousePos,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final dotPaint = Paint()..style = PaintingStyle.fill;
    // Pure monochrome: black ink dots in light mode, soft white dots in dark mode
    final dotColor = isDark ? Colors.white : Colors.black;

    // Seamless continuous drift of the halftone dot lattice
    final double dx = (progress * _spacing * 1.5) % _spacing;
    final double dy = (progress * _rowHeight * 1.5) % _rowHeight;

    final int cols = (size.width / _spacing).ceil() + 2;
    final int rows = (size.height / _rowHeight).ceil() + 2;

    final double centerX = size.width * 0.5;
    final double centerY = size.height * 0.35;
    final double maxDist = math.max(centerX, centerY);

    final double phase = progress * 2.0 * math.pi;

    for (int r = -1; r < rows; r++) {
      final double y = (r * _rowHeight) - dy;
      final double rowOffset = (r % 2 != 0) ? (_spacing * 0.5) : 0.0;

      for (int c = -1; c < cols; c++) {
        final double x = (c * _spacing) + rowOffset - dx;

        if (x < -6 || x > size.width + 6 || y < -6 || y > size.height + 6) {
          continue;
        }

        // 1. Distance from center hero text area (softer in center, prominent on edges)
        final double distToCenter = math.sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
        final double centerFactor = (distToCenter / maxDist).clamp(0.0, 1.2);
        // Vignette weight: subtle in center (0.3) to strong at edges (1.05)
        final double densityWeight = 0.30 + (centerFactor * 0.75);

        // 2. Dynamic harmonic wave traveling across the halftone grid
        final double wave1 = math.sin((x * 0.009) + (y * 0.009) - phase);
        final double wave2 = math.cos((x * 0.013) - (y * 0.006) + (phase * 0.75));
        final double wave = (wave1 + wave2) * 0.5; // -1.0 to 1.0

        // 3. Fine, small dot radius undulating in subtle waves (from 0.4px to 1.85px)
        final double baseRadius = 0.85 * densityWeight;
        double radius = (baseRadius + (wave * 0.55 * densityWeight)).clamp(0.35, 1.85);

        // 4. Dot opacity matching authentic fine-grain print ink
        double baseAlpha = isDark
            ? (0.05 + (wave + 1.0) * 0.055) * densityWeight
            : (0.07 + (wave + 1.0) * 0.065) * densityWeight;

        // 5. Delicate interactive mouse ripple
        if (mousePos != null) {
          final double mDist = (Offset(x, y) - mousePos!).distance;
          if (mDist < 140) {
            final double influence = 1.0 - (mDist / 140.0);
            radius += influence * 0.9;
            baseAlpha += influence * (isDark ? 0.08 : 0.10);
          }
        }

        dotPaint.color = dotColor.withValues(alpha: baseAlpha.clamp(0.02, isDark ? 0.22 : 0.25));
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant AnimatedHalftoneScreenPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.mousePos != mousePos ||
        oldDelegate.isDark != isDark;
  }
}
