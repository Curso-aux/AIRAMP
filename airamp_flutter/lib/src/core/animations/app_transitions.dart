import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A custom, silky-smooth page transition builder that provides
/// a modern, Apple/Material 3 fluid slide-and-fade animation
/// across all platform navigations.
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Primary entrance curve
    final primaryCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Secondary exit curve (when another screen is pushed on top)
    final secondaryCurve = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.06, 0.0),
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
    );
  }
}

/// Helper methods for opening dialogs and bottom sheets with
/// delightful, springy "pop" animations and subtle haptic feedback.
class AppModalTransitions {
  /// Opens a dialog with a smooth, springy "pop" scale + fade animation.
  static Future<T?> showSmoothDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    Duration duration = const Duration(milliseconds: 240),
  }) {
    HapticFeedback.lightImpact();
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.40),
      transitionDuration: duration,
      pageBuilder: (ctx, anim1, anim2) => builder(ctx),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curve = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curve),
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        );
      },
    );
  }

  /// Opens a modal bottom sheet with smooth easing and tactile feedback.
  static Future<T?> showSmoothBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    ShapeBorder? shape,
    BoxConstraints? constraints,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor ?? Colors.transparent,
      shape: shape ?? const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: constraints,
      builder: builder,
    );
  }
}
