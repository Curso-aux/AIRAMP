import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/aira_voice_service.dart';
import '../../services/aira_screen_text_extractor.dart';
import 'aira_hold_ring.dart';
import 'aira_scanner_overlay.dart';
import 'aira_speech_hud.dart';

/// The core floating interactive AIRA assistant widget.
///
/// Features:
/// - Free drag & pan across the screen with boundary clamping
/// - Spring edge-snapping to the nearest edge (left/right)
/// - Float bobbing & idle dimming
/// - Hold-to-scan with glowing circular progress ring (4.5s)
/// - Cybernetic screen laser scan overlay
/// - Screen text extraction & fluent young girl English voice reading
/// - Speech HUD with playback controls and instant tap-to-stop
class AiraFloatingAssistant extends StatefulWidget {
  final VoidCallback onOpenMenu;
  final Duration holdDuration;

  const AiraFloatingAssistant({
    super.key,
    required this.onOpenMenu,
    this.holdDuration = const Duration(milliseconds: 1000),
  });

  @override
  State<AiraFloatingAssistant> createState() => _AiraFloatingAssistantState();
}

class _AiraFloatingAssistantState extends State<AiraFloatingAssistant>
    with TickerProviderStateMixin {
  static const double _buttonWidth = 64.0;
  static const double _buttonHeight = 88.0;
  static const double _ringSize = 88.0;
  static const double _edgePadding = 8.0;

  Offset _position = Offset.zero;
  bool _isInitialized = false;
  bool _isDragging = false;
  bool _isInteracting = false;
  bool _isIdle = false;
  bool _isScanning = false;
  bool _holdCompleted = false;
  double _dragVelocityX = 0.0;
  double _holdProgress = 0.0;

  Timer? _idleTimer;
  late AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  late AnimationController _holdController;

  late AnimationController _speakingController;
  late Animation<double> _speakingBounce;
  late Animation<double> _speakingTilt;
  late Animation<double> _soundWavePulse;

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

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _holdController = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    )..addListener(() {
        setState(() {
          _holdProgress = _holdController.value;
        });
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onHoldCompleted();
        }
      });

    // Speaking rhythm animation
    _speakingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );

    _speakingBounce = Tween<double>(begin: 0.98, end: 1.05).animate(
      CurvedAnimation(parent: _speakingController, curve: Curves.easeInOutSine),
    );

    _speakingTilt = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _speakingController, curve: Curves.easeInOutSine),
    );

    _soundWavePulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _speakingController, curve: Curves.easeOutQuad),
    );

    // Listen to voice state changes to refresh avatar active/idle state
    AiraVoiceService.instance.stateNotifier.addListener(_onVoiceStateChanged);
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _snapController.dispose();
    _floatController.dispose();
    _holdController.dispose();
    _speakingController.dispose();
    AiraVoiceService.instance.stateNotifier.removeListener(_onVoiceStateChanged);
    super.dispose();
  }

  void _onVoiceStateChanged() {
    if (mounted) {
      if (AiraVoiceService.instance.isSpeaking) {
        if (!_speakingController.isAnimating) {
          _speakingController.repeat(reverse: true);
        }
      } else {
        if (_speakingController.isAnimating) {
          _speakingController.stop();
          _speakingController.value = 0.0;
        }
      }
      setState(() {});
    }
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted &&
          !_isDragging &&
          !_isScanning &&
          !AiraVoiceService.instance.isSpeaking) {
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

  void _onHoldCompleted() {
    _holdCompleted = true;
    _holdController.reset();
    setState(() {
      _holdProgress = 0.0;
      _isScanning = true;
      _isInteracting = false;
    });

    HapticFeedback.heavyImpact();
    debugPrint('[AIRA] Hold-to-scan triggered (1s completed)');
  }

  void _onScanAnimationComplete() {
    setState(() {
      _isScanning = false;
    });

    // Extract text from the active screen
    final ignoreRect = Rect.fromLTWH(
      _position.dx - 10,
      _position.dy - 10,
      _buttonWidth + 20,
      _buttonHeight + 20,
    );

    final extracted = AiraScreenTextExtractor.extractScreenText(
      context,
      ignoreRect: ignoreRect,
    );

    const intro = "Yay! Here is what I see on your screen! ";
    if (extracted.trim().isEmpty) {
      AiraVoiceService.instance.speakScreen(
        "Aww, I looked all around, but I don't see any words to read on this screen!",
      );
    } else {
      debugPrint('[AIRA] Read Screen text: $extracted');
      AiraVoiceService.instance.speakScreen("$intro$extracted");
    }
  }

  void _onPanDown(DragDownDetails details) {
    _wakeUp();
    if (_snapController.isAnimating) {
      _snapController.stop();
    }
    _dragStartPos = _position;
    _dragStartTime = DateTime.now();
    _holdCompleted = false;

    // Warm up voice service directly during user touch gesture to unlock browser audio
    AiraVoiceService.instance.init();

    // Start filling the circular progress ring (1s duration)
    _holdController.forward(from: 0.0);

    setState(() => _isInteracting = true);
  }

  void _onPanStart(DragStartDetails details) {
    _wakeUp();
    _dragStartPos = _position;
    _dragStartTime = DateTime.now();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _wakeUp();

    // If finger moves beyond threshold, cancel hold progress and transition to drag
    final moveDist = (_position - _dragStartPos).distance;
    if (moveDist > 8.0 && _holdController.isAnimating) {
      _holdController.reset();
      setState(() => _holdProgress = 0.0);
    }

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top + 10.0;
    final bottomPadding = mediaQuery.padding.bottom + 80.0;

    final minX = _edgePadding;
    final maxX = screenWidth - _buttonWidth - _edgePadding;
    final minY = topPadding;
    final maxY = screenHeight - _buttonHeight - bottomPadding;

    setState(() {
      _isDragging = true;
      _dragVelocityX = details.delta.dx;
      _position = Offset(
        (_position.dx + details.delta.dx).clamp(minX, maxX),
        (_position.dy + details.delta.dy).clamp(minY, maxY),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // If hold completed, ignore drag end to prevent accidental quick action opening
    if (_holdCompleted) {
      _holdCompleted = false;
      setState(() {
        _isDragging = false;
        _isInteracting = false;
      });
      return;
    }

    // Cancel unfinished hold
    if (_holdController.isAnimating) {
      _holdController.reset();
      setState(() => _holdProgress = 0.0);
    }

    setState(() => _isDragging = false);

    final dragDistance = (_position - _dragStartPos).distance;
    final dragDuration = DateTime.now().difference(_dragStartTime);

    // Quick tap: < 6px movement and < 220ms duration
    if (dragDistance < 6.0 && dragDuration.inMilliseconds < 220) {
      if (AiraVoiceService.instance.isSpeaking) {
        // Tapping AIRA while speaking stops reading
        HapticFeedback.lightImpact();
        AiraVoiceService.instance.stop();
        setState(() => _isInteracting = false);
      } else {
        // Normal quick tap opens role menu
        widget.onOpenMenu();
      }
      return;
    }

    _snapToNearestEdge(details.velocity.pixelsPerSecond);
    _startIdleTimer();

    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted && !_isDragging) {
        setState(() {
          _isInteracting = false;
          _dragVelocityX = 0.0;
        });
      }
    });
  }

  void _snapToNearestEdge(Offset velocity) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top + 10.0;
    final bottomPadding = mediaQuery.padding.bottom + 80.0;

    final minX = _edgePadding;
    final maxX = screenWidth - _buttonWidth - _edgePadding;
    final minY = topPadding;
    final maxY = screenHeight - _buttonHeight - bottomPadding;

    final centerX = screenWidth / 2;
    double targetX;

    if (velocity.dx.abs() > 400) {
      targetX = velocity.dx > 0 ? maxX : minX;
    } else {
      targetX = (_position.dx + _buttonWidth / 2 < centerX) ? minX : maxX;
    }

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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top + 10.0;
    final bottomPadding = mediaQuery.padding.bottom + 80.0;

    if (!_isInitialized) {
      _position = Offset(
        screenWidth - _buttonWidth - _edgePadding,
        screenHeight * 0.65,
      );
      _isInitialized = true;
      _startIdleTimer();
    }

    final isVoiceActive = AiraVoiceService.instance.isSpeaking;
    final isVoicePaused = AiraVoiceService.instance.state == AiraVoiceState.paused;
    final isActivelyInteracting = _isDragging ||
        _isInteracting ||
        _holdProgress > 0.01 ||
        _isScanning ||
        isVoiceActive;

    final opacity = isActivelyInteracting ? 1.0 : (_isIdle ? 0.70 : 0.95);

    // Calculate Speech HUD Position relative to AIRA
    double hudLeft;
    if (_position.dx > screenWidth / 2) {
      hudLeft = (_position.dx - 268).clamp(12.0, screenWidth - 280);
    } else {
      hudLeft = (_position.dx + _buttonWidth + 12).clamp(12.0, screenWidth - 280);
    }
    final hudTop = (_position.dy + 8).clamp(topPadding, screenHeight - bottomPadding - 60);

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Fullscreen Scanner HUD Overlay when scan triggers
          if (_isScanning)
            AiraScannerOverlay(
              onComplete: _onScanAnimationComplete,
            ),

          // 2. Floating Speech HUD when reading aloud
          if (isVoiceActive || isVoicePaused)
            Positioned(
              left: hudLeft,
              top: hudTop,
              child: AiraSpeechHUD(
                onStop: () {
                  setState(() {});
                },
              ),
            ),

          // 3. Floating AIRA Avatar Button with Circular Hold Progress Ring
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: GestureDetector(
              onPanDown: _onPanDown,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              behavior: HitTestBehavior.opaque,
              child: AnimatedOpacity(
                opacity: opacity,
                duration: const Duration(milliseconds: 220),
                child: AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    final floatY = isActivelyInteracting ? 0.0 : _floatAnimation.value;
                    final tiltAngle = _isDragging
                        ? (_dragVelocityX * 0.003).clamp(-0.15, 0.15)
                        : 0.0;

                    return Transform.translate(
                      offset: Offset(0, floatY),
                      child: Transform.rotate(
                        angle: tiltAngle,
                        child: AnimatedScale(
                          scale: isActivelyInteracting ? 1.08 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutBack,
                          child: AiraHoldRing(
                            progress: _holdProgress,
                            size: _ringSize,
                            child: SizedBox(
                              width: _buttonWidth,
                              height: _buttonHeight,
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  // Soft floating character shadow underneath baseline
                                  Positioned(
                                    bottom: 2,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      width: isActivelyInteracting ? 46 : 38,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: isActivelyInteracting ? 0.28 : 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: isActivelyInteracting ? 0.25 : 0.12,
                                            ),
                                            blurRadius: isActivelyInteracting ? 8 : 5,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Soundwave aura pulse when speaking
                                  if (isVoiceActive)
                                    Positioned.fill(
                                      child: AnimatedBuilder(
                                        animation: _soundWavePulse,
                                        builder: (context, _) {
                                          final p = _soundWavePulse.value;
                                          return Center(
                                            child: Container(
                                              width: 52 + (20 * p),
                                              height: 52 + (20 * p),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: const Color(0xFF00E5FF).withValues(
                                                    alpha: (0.45 * (1.0 - p)).clamp(0.0, 1.0),
                                                  ),
                                                  width: 2.0,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF00E5FF).withValues(
                                                      alpha: (0.25 * (1.0 - p)).clamp(0.0, 1.0),
                                                    ),
                                                    blurRadius: 12,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                  // Avatar Image (transitions between idle, active, and speaking)
                                  AnimatedBuilder(
                                    animation: _speakingController,
                                    builder: (context, child) {
                                      final speakScale = isVoiceActive ? _speakingBounce.value : 1.0;
                                      final speakTilt = isVoiceActive ? _speakingTilt.value : 0.0;

                                      String avatarAsset;
                                      if (isVoiceActive) {
                                        avatarAsset = 'assets/images/aira_avatar_speaking.png';
                                      } else if (isActivelyInteracting) {
                                        avatarAsset = 'assets/images/aira_avatar_active.png';
                                      } else {
                                        avatarAsset = 'assets/images/aira_avatar_idle.png';
                                      }

                                      return Transform.rotate(
                                        angle: speakTilt,
                                        child: Transform.scale(
                                          scale: speakScale,
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 220),
                                            switchInCurve: Curves.easeOutCubic,
                                            switchOutCurve: Curves.easeInCubic,
                                            transitionBuilder: (child, animation) {
                                              return FadeTransition(
                                                opacity: animation,
                                                child: ScaleTransition(
                                                  scale: Tween<double>(begin: 0.94, end: 1.0)
                                                      .animate(animation),
                                                  child: child,
                                                ),
                                              );
                                            },
                                            child: Image.asset(
                                              avatarAsset,
                                              key: ValueKey<String>(avatarAsset),
                                              width: _buttonWidth,
                                              height: _buttonHeight,
                                              fit: BoxFit.contain,
                                              filterQuality: FilterQuality.medium,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
