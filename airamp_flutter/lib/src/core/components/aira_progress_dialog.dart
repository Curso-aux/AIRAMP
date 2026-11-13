import 'dart:async';
import 'package:flutter/material.dart';

/// A modern, high-fidelity loading dialog overlay with real-time
/// animated progress, stage status updates, and light/dark theme support.
class AiraProgressDialog extends StatefulWidget {
  final String title;
  final String initialMessage;
  final IconData icon;
  final Color accentColor;
  final Future<void> Function(void Function(double progress, String statusMessage) updateProgress) task;

  const AiraProgressDialog({
    super.key,
    required this.title,
    required this.initialMessage,
    required this.icon,
    required this.accentColor,
    required this.task,
  });

  /// Displays the progress dialog modal and executes [task].
  /// The dialog automatically dismisses once [task] finishes, and propagates any thrown exception.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String initialMessage,
    required Future<void> Function(void Function(double progress, String statusMessage) updateProgress) task,
    IconData icon = Icons.hourglass_top_rounded,
    Color accentColor = const Color(0xFFD97706),
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AiraProgressDialog(
        title: title,
        initialMessage: initialMessage,
        icon: icon,
        accentColor: accentColor,
        task: task,
      ),
    );
  }

  /// Convenience helper for deactivation operations.
  static Future<void> showDeactivating(
    BuildContext context, {
    required String title,
    required String initialMessage,
    required Future<void> Function(void Function(double progress, String statusMessage) updateProgress) task,
  }) {
    return show(
      context,
      title: title,
      initialMessage: initialMessage,
      icon: Icons.person_off_outlined,
      accentColor: const Color(0xFFD97706), // Amber
      task: task,
    );
  }

  /// Convenience helper for permanent deletion / purge operations.
  static Future<void> showDeleting(
    BuildContext context, {
    required String title,
    required String initialMessage,
    required Future<void> Function(void Function(double progress, String statusMessage) updateProgress) task,
  }) {
    return show(
      context,
      title: title,
      initialMessage: initialMessage,
      icon: Icons.delete_sweep_rounded,
      accentColor: const Color(0xFFEF4444), // Crimson Red
      task: task,
    );
  }

  /// Convenience helper for restore operations.
  static Future<void> showRestoring(
    BuildContext context, {
    required String title,
    required String initialMessage,
    required Future<void> Function(void Function(double progress, String statusMessage) updateProgress) task,
  }) {
    return show(
      context,
      title: title,
      initialMessage: initialMessage,
      icon: Icons.restore_rounded,
      accentColor: const Color(0xFF10B981), // Emerald Green
      task: task,
    );
  }

  @override
  State<AiraProgressDialog> createState() => _AiraProgressDialogState();
}

class _AiraProgressDialogState extends State<AiraProgressDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  double? _targetProgress;
  double _displayProgress = 0.08;
  late String _statusMessage;
  bool _isCompleted = false;
  Timer? _creepTimer;

  @override
  void initState() {
    super.initState();
    _statusMessage = widget.initialMessage;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Subtle virtual creep timer so progress bar feels alive and never freezes at a fixed number like 30%
    _creepTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _isCompleted) return;
      setState(() {
        if (_targetProgress != null && _targetProgress! > 0) {
          // If a real target is set, allow gentle creep up to min(target + 0.10, 0.92) if target hasn't updated
          final ceiling = (_targetProgress! + 0.12).clamp(0.0, 0.92);
          if (_displayProgress < ceiling) {
            _displayProgress = (_displayProgress + 0.008).clamp(0.0, ceiling);
          }
        } else {
          // Initial creep up to 20%
          if (_displayProgress < 0.20) {
            _displayProgress = (_displayProgress + 0.015).clamp(0.0, 0.20);
          }
        }
      });
    });

    // Execute task after the dialog is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) => _executeTask());
  }

  @override
  void dispose() {
    _creepTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _executeTask() async {
    try {
      await widget.task((progress, statusMessage) {
        if (mounted) {
          setState(() {
            _targetProgress = progress.clamp(0.0, 1.0);
            if (_targetProgress! > _displayProgress) {
              _displayProgress = _targetProgress!;
            }
            _statusMessage = statusMessage;
            if (_targetProgress! >= 1.0) {
              _isCompleted = true;
            }
          });
        }
      });

      if (mounted) {
        _creepTimer?.cancel();
        setState(() {
          _isCompleted = true;
          _displayProgress = 1.0;
          _targetProgress = 1.0;
          if (!_statusMessage.toLowerCase().contains('complete') &&
              !_statusMessage.toLowerCase().contains('success') &&
              !_statusMessage.toLowerCase().contains('purged')) {
            _statusMessage = 'Purge completed successfully!';
          }
        });

        // Hold 650ms for visual satisfaction so the user sees 100% and success confirmation
        await Future.delayed(const Duration(milliseconds: 650));

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    } catch (e) {
      _creepTimer?.cancel();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final currentAccent = _isCompleted
        ? const Color(0xFF10B981) // Emerald Green on completion
        : widget.accentColor;

    final currentIcon = _isCompleted
        ? Icons.check_circle_rounded
        : widget.icon;

    return PopScope(
      canPop: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Dialog(
            backgroundColor: surfaceColor,
            elevation: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: borderColor),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Pulsing Icon Badge ──
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentAccent.withValues(alpha: 0.12),
                        border: Border.all(
                          color: currentAccent.withValues(alpha: 0.35),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: currentAccent.withValues(alpha: 0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            currentIcon,
                            key: ValueKey(currentIcon),
                            color: currentAccent,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Dialog Title ──
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Stage Subtitle / Progress Note ──
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _statusMessage,
                      key: ValueKey(_statusMessage),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: _isCompleted ? const Color(0xFF10B981) : textSecondary,
                        fontWeight: _isCompleted ? FontWeight.w600 : FontWeight.normal,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Progress Bar with Smooth Tween Interpolation ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 8,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.05, end: _displayProgress),
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedVal, _) {
                          final barColor = (animatedVal >= 0.999 || _isCompleted)
                              ? const Color(0xFF10B981)
                              : widget.accentColor;
                          return LinearProgressIndicator(
                            value: animatedVal.clamp(0.0, 1.0),
                            backgroundColor: barColor.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Percentage Display with Smooth Counter Animation ──
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.05, end: _displayProgress),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedVal, _) {
                      final pctColor = (animatedVal >= 0.999 || _isCompleted)
                          ? const Color(0xFF10B981)
                          : widget.accentColor;
                      final pctText = '${(animatedVal.clamp(0.0, 1.0) * 100).toInt()}%';
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          pctText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: pctColor,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Lock & Safety Info Pill ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isCompleted ? Icons.verified_user_rounded : Icons.shield_outlined,
                          size: 14,
                          color: _isCompleted ? const Color(0xFF10B981) : textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _isCompleted
                                ? 'Account permanently purged and credentials securely revoked.'
                                : 'Synchronizing records safely. Please do not close this window.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: _isCompleted ? const Color(0xFF10B981) : textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
