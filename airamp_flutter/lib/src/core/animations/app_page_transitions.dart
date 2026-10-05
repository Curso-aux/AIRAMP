import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Performance-optimized, aesthetic page transitions for GoRouter.
///
/// Features:
/// 1. GPU-accelerated [RepaintBoundary] raster layer isolation to eliminate CPU layout jank during transitions.
/// 2. Platform-aware default: Web gets silky vertical float fade-through (220ms);
///    Mobile (Android/iOS) gets fluid Apple/Material 3 slide-and-fade (280ms).
/// 3. Specialized transitions for Activities/Modals and Shell tabs.
class AppPageTransitions {
  const AppPageTransitions._();

  /// Default platform-adaptive page transition:
  /// - Web: Smooth fade-through with subtle vertical float (220ms).
  /// - Mobile / Native: Fluid horizontal slide-and-fade with secondary exit motion (280ms).
  static Page<dynamic> page({
    required ValueKey<String> key,
    required Widget child,
    String? name,
    Object? arguments,
    String? restorationId,
  }) {
    if (kIsWeb) {
      return webFadeThrough(
        key: key,
        child: child,
        name: name,
        arguments: arguments,
        restorationId: restorationId,
      );
    }
    return slidePush(
      key: key,
      child: child,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
    );
  }

  /// Silky Web Fade-Through:
  /// Opacity: 0.0 -> 1.0 (with subtle vertical float from 2.5% height to 0%).
  /// Fast 220ms duration for instant responsiveness without lag.
  static Page<dynamic> webFadeThrough({
    required ValueKey<String> key,
    required Widget child,
    String? name,
    Object? arguments,
    String? restorationId,
    Duration duration = const Duration(milliseconds: 220),
    Duration reverseDuration = const Duration(milliseconds: 180),
  }) {
    return CustomTransitionPage<void>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return RepaintBoundary(
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.025),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            ),
          ),
        );
      },
    );
  }

  /// Modern Mobile Slide-and-Fade:
  /// Incoming screen slides in from right (Offset(0.08, 0.0)) while fading in.
  /// Outgoing screen gently steps back (Offset(-0.03, 0.0)) and dims.
  /// Uses [RepaintBoundary] to ensure zero frame drops during push/pop.
  static Page<dynamic> slidePush({
    required ValueKey<String> key,
    required Widget child,
    String? name,
    Object? arguments,
    String? restorationId,
    Duration duration = const Duration(milliseconds: 280),
    Duration reverseDuration = const Duration(milliseconds: 240),
  }) {
    return CustomTransitionPage<void>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final primaryCurve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final secondaryCurve = CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return RepaintBoundary(
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0.0),
              end: Offset.zero,
            ).animate(primaryCurve),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(primaryCurve),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset.zero,
                  end: const Offset(-0.03, 0.0),
                ).animate(secondaryCurve),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 1.0, end: 0.88).animate(secondaryCurve),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Activity / Modal Sheet Transition:
  /// Vertical bottom slide-up with smooth fade (Offset(0, 0.06) -> 0.0).
  /// Perfect for Quizzes, Submissions, Detail views, and Editor activities.
  static Page<dynamic> activityModal({
    required ValueKey<String> key,
    required Widget child,
    String? name,
    Object? arguments,
    String? restorationId,
    Duration duration = const Duration(milliseconds: 260),
    Duration reverseDuration = const Duration(milliseconds: 220),
  }) {
    return CustomTransitionPage<void>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return RepaintBoundary(
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.06),
              end: Offset.zero,
            ).animate(curve),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
              child: child,
            ),
          ),
        );
      },
    );
  }

  /// Pure Cross-Fade:
  /// For top-level role authentication redirects and tab switches.
  static Page<dynamic> fadeThrough({
    required ValueKey<String> key,
    required Widget child,
    String? name,
    Object? arguments,
    String? restorationId,
    Duration duration = const Duration(milliseconds: 200),
    Duration reverseDuration = const Duration(milliseconds: 180),
  }) {
    return CustomTransitionPage<void>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return RepaintBoundary(
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    );
  }
}

/// A lightweight, GPU-composited transition wrapper for Shell branches
/// (e.g. StudentScaffold, TeacherScaffold, AdminWebScaffold).
///
/// Smoothly animates incoming tab content with a subtle fade-and-rise (180ms),
/// preventing the abrupt, jarring visual pop of standard [IndexedStack] switches
/// without tearing down or reconstructing the underlying branch states.
class AppBranchTransition extends StatefulWidget {
  final int currentIndex;
  final Widget child;
  final Duration duration;

  const AppBranchTransition({
    super.key,
    required this.currentIndex,
    required this.child,
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  State<AppBranchTransition> createState() => _AppBranchTransitionState();
}

class _AppBranchTransitionState extends State<AppBranchTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0, // Fully visible on initial mount
    );

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    // Fade from 0.35 to 1.0 so there is never a black or empty flicker
    _fadeAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(curve);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.012),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void didUpdateWidget(covariant AppBranchTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
