import 'package:flutter/material.dart';
import '../animations/animated_pressable.dart';
import '../theme/app_theme.dart';

/// Semantic toast types.
enum AppToastType {
  success,
  error,
  warning,
  info,
}

/// A modern, non-blocking floating pill toast system.
///
/// Designed to provide high-visibility, polished visual feedback that floats
/// elegantly above bottom navigation bars and floating quick action bubbles.
class AppToast {
  /// Shows a success toast with an emerald badge and check icon.
  static void showSuccess(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: AppToastType.success,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Shows an error toast with a crimson badge and error icon.
  static void showError(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      type: AppToastType.error,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Shows a warning toast with an amber badge and warning icon.
  static void showWarning(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: AppToastType.warning,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Shows an info toast with an accent badge and info icon.
  static void showInfo(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: AppToastType.info,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Base toast display method using a floating, transparent SnackBar container.
  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    final Color accentColor;
    final Color backgroundColor;
    final IconData iconData;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (type) {
      case AppToastType.success:
        accentColor = const Color(0xFF10B981); // Emerald
        backgroundColor = isDark ? const Color(0xFF0D281E) : const Color(0xFFECFDF5);
        iconData = Icons.check_circle_rounded;
        break;
      case AppToastType.error:
        accentColor = isDark ? AppTheme.darkError : AppTheme.lightError;
        backgroundColor = isDark ? const Color(0xFF2D1214) : const Color(0xFFFEF2F2);
        iconData = Icons.error_rounded;
        break;
      case AppToastType.warning:
        accentColor = const Color(0xFFF59E0B); // Amber
        backgroundColor = isDark ? const Color(0xFF2B1D0C) : const Color(0xFFFFFBEB);
        iconData = Icons.warning_rounded;
        break;
      case AppToastType.info:
        accentColor = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
        backgroundColor = isDark ? const Color(0xFF112338) : const Color(0xFFF0F9FF);
        iconData = Icons.info_rounded;
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, size: 18, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    height: 1.3,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 12),
                AnimatedPressable(
                  onTap: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      actionLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
