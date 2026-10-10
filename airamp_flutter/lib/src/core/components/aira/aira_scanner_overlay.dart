import 'dart:ui';
import 'package:flutter/material.dart';

/// Fullscreen futuristic HUD scanner overlay displayed when AIRA scans the screen.
class AiraScannerOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const AiraScannerOverlay({super.key, required this.onComplete});

  @override
  State<AiraScannerOverlay> createState() => _AiraScannerOverlayState();
}

class _AiraScannerOverlayState extends State<AiraScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scanProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scanProgress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _scanProgress,
          builder: (context, _) {
            final scanY = _scanProgress.value * screenHeight;
            final opacity = (1.0 - (_controller.value - 0.85).clamp(0.0, 0.15) / 0.15);

            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Stack(
                children: [
                  // 1. Subtle tint overlay with vignette
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [
                          const Color(0x0800E5FF),
                          Colors.black.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),

                  // 2. Futuristic cyber laser scan line with glowing tail
                  Positioned(
                    top: scanY - 140,
                    left: 0,
                    right: 0,
                    height: 140,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0x0500E5FF),
                            Color(0x2500E5FF),
                            Color(0x8800E5FF),
                          ],
                          stops: [0.0, 0.5, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // 3. Crisp horizontal neon laser line
                  Positioned(
                    top: scanY,
                    left: 0,
                    right: 0,
                    height: 3.5,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xFF00BFA5),
                            Color(0xFF00E5FF),
                            Colors.white,
                            Color(0xFF00E5FF),
                            Color(0xFF00BFA5),
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.15, 0.4, 0.5, 0.6, 0.85, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xDD00E5FF),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.white,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Centered holographic scanning pill badge
                  Align(
                    alignment: const Alignment(0, -0.65),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xDD0F172A),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0x6600E5FF),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x3300E5FF),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0x3300E5FF),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.document_scanner_rounded,
                                    color: Color(0xFF00E5FF),
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'AIRA is scanning your screen...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
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
            );
          },
        ),
      ),
    );
  }
}
