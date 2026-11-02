import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Semantic toast types for [AiraActionToast].
enum AiraToastType {
  success,
  warning,
  error,
  info,
}

/// A modern, light/dark mode-responsive floating action toast positioned
/// in the top-right of the viewport with animated progress countdown,
/// interactive pause controls, and high-fidelity typography matching
/// modern design systems.
class AiraActionToast {
  static OverlayEntry? _currentEntry;

  /// Displays a floating card toast in the top-right corner with entrance slide
  /// and animated countdown bar.
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    AiraToastType type = AiraToastType.success,
    Duration duration = const Duration(seconds: 8),
    String actionLabel = 'Okay',
    VoidCallback? onAction,
    double width = 440,
    bool showStopButton = true,
  }) {
    // Dismiss any currently displayed toast before showing the new one
    dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _AiraActionToastOverlay(
        title: title,
        message: message,
        type: type,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        width: width,
        showStopButton: showStopButton,
        onDismiss: () {
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
          try {
            entry.remove();
          } catch (_) {}
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  /// Dismisses any active action toast overlay.
  static void dismiss() {
    try {
      _currentEntry?.remove();
    } catch (_) {}
    _currentEntry = null;
  }

  /// Convenience helper for success/changes-saved notifications.
  static void showSuccess(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 8),
    String actionLabel = 'Okay',
    VoidCallback? onAction,
    double width = 440,
  }) {
    show(
      context,
      title: title,
      message: message,
      type: AiraToastType.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      width: width,
    );
  }

  /// Convenience helper for warning notifications.
  static void showWarning(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 8),
    String actionLabel = 'Okay',
    VoidCallback? onAction,
    double width = 440,
  }) {
    show(
      context,
      title: title,
      message: message,
      type: AiraToastType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      width: width,
    );
  }

  /// Convenience helper for error notifications.
  static void showError(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 8),
    String actionLabel = 'Okay',
    VoidCallback? onAction,
    double width = 440,
  }) {
    show(
      context,
      title: title,
      message: message,
      type: AiraToastType.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      width: width,
    );
  }
}

/// Overlay container that positions the toast in the top-right with
/// smooth slide & fade transitions.
class _AiraActionToastOverlay extends StatefulWidget {
  final String title;
  final String message;
  final AiraToastType type;
  final Duration duration;
  final String actionLabel;
  final VoidCallback? onAction;
  final double width;
  final bool showStopButton;
  final VoidCallback onDismiss;

  const _AiraActionToastOverlay({
    required this.title,
    required this.message,
    required this.type,
    required this.duration,
    required this.actionLabel,
    this.onAction,
    required this.width,
    required this.showStopButton,
    required this.onDismiss,
  });

  @override
  State<_AiraActionToastOverlay> createState() => _AiraActionToastOverlayState();
}

class _AiraActionToastOverlayState extends State<_AiraActionToastOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.25, 0.0), // Slides in smoothly from the right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    _animController.forward();
  }

  void _handleDismiss() async {
    if (_isExiting || !mounted) return;
    _isExiting = true;
    await _animController.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final screenWidth = mediaQuery.size.width;

    final isNarrow = screenWidth < (widget.width + 48);
    final effectiveWidth = isNarrow ? (screenWidth - 32) : widget.width;

    return Positioned(
      top: topPadding + 20,
      right: isNarrow ? 16 : 24,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: effectiveWidth,
              child: AiraActionToastCard(
                title: widget.title,
                message: widget.message,
                type: widget.type,
                duration: widget.duration,
                actionLabel: widget.actionLabel,
                onAction: widget.onAction,
                showStopButton: widget.showStopButton,
                onDismiss: _handleDismiss,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The stateful card widget rendering the light/dark responsive toast layout,
/// animated progress bar, and "Click to stop" countdown interactions.
class AiraActionToastCard extends StatefulWidget {
  final String title;
  final String message;
  final AiraToastType type;
  final Duration duration;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool showStopButton;
  final VoidCallback onDismiss;

  const AiraActionToastCard({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    required this.duration,
    required this.actionLabel,
    this.onAction,
    required this.showStopButton,
    required this.onDismiss,
  });

  @override
  State<AiraActionToastCard> createState() => _AiraActionToastCardState();
}

class _AiraActionToastCardState extends State<AiraActionToastCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_isPaused) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pauseAutoClose() {
    if (!_isPaused && mounted) {
      _controller.stop();
      setState(() {
        _isPaused = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark || AppTheme.isDark;

    // Theme color tokens matching the reference styling
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final bodyColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final footerBg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.55) : const Color(0xFFF8FAFC);
    final footerBorder = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final footerText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final buttonBorder = isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB);
    final buttonBg = isDark ? const Color(0xFF334155).withValues(alpha: 0.4) : Colors.white;
    final buttonText = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    // Accent color configuration based on type
    final Color accentColor;
    final Widget badgeIcon;

    switch (widget.type) {
      case AiraToastType.success:
        accentColor = const Color(0xFF10B981); // Emerald green
        badgeIcon = Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 2.2),
          ),
          child: const Center(
            child: Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 16),
          ),
        );
        break;
      case AiraToastType.error:
        accentColor = const Color(0xFFEF4444); // Coral red
        badgeIcon = Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 2.2),
          ),
          child: const Center(
            child: Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 16),
          ),
        );
        break;
      case AiraToastType.warning:
        accentColor = const Color(0xFFF59E0B); // Honey Amber
        badgeIcon = Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 2.2),
          ),
          child: const Center(
            child: Icon(Icons.priority_high_rounded, color: Color(0xFFF59E0B), size: 16),
          ),
        );
        break;
      case AiraToastType.info:
        accentColor = const Color(0xFF0284C7); // Sky Cerulean
        badgeIcon = Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 2.2),
          ),
          child: const Center(
            child: Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 16),
          ),
        );
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x66000000) : const Color(0x140F172A),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upper Card Content (Header, Body, Action Button)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      badgeIcon,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: footerText),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        splashRadius: 16,
                        tooltip: 'Dismiss',
                        onPressed: () {
                          _controller.stop();
                          widget.onDismiss();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Message Body
                  Text(
                    widget.message,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: bodyColor,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Action Button ("Okay")
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      _controller.stop();
                      if (widget.onAction != null) {
                        widget.onAction!();
                      }
                      widget.onDismiss();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
                      decoration: BoxDecoration(
                        color: buttonBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: buttonBorder, width: 1.1),
                      ),
                      child: Text(
                        widget.actionLabel,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: buttonText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Footer with countdown text & "Click to stop"
            Container(
              padding: const EdgeInsets.fromLTRB(18, 11, 18, 11),
              decoration: BoxDecoration(
                color: footerBg,
                border: Border(top: BorderSide(color: footerBorder, width: 1.0)),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final remaining = _isPaused
                      ? 0
                      : ((1.0 - _controller.value) * widget.duration.inSeconds)
                          .ceil()
                          .clamp(0, widget.duration.inSeconds);

                  return Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 12.5,
                              color: footerText,
                              height: 1.3,
                            ),
                            children: [
                              if (!_isPaused) ...[
                                const TextSpan(text: 'This message will close in '),
                                TextSpan(
                                  text: '$remaining',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: titleColor,
                                  ),
                                ),
                                const TextSpan(text: ' seconds. '),
                                if (widget.showStopButton)
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: InkWell(
                                      onTap: _pauseAutoClose,
                                      child: Text(
                                        'Click to stop.',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: titleColor,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                              ] else ...[
                                TextSpan(
                                  text: 'Auto-close paused. ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: titleColor,
                                  ),
                                ),
                                const TextSpan(text: 'Click Okay or ✕ to dismiss.'),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Animated Bottom Progress Indicator
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = _isPaused
                    ? 0.0
                    : (1.0 - _controller.value).clamp(0.0, 1.0);

                return Container(
                  height: 4,
                  width: double.infinity,
                  color: footerBg,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      color: accentColor,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
