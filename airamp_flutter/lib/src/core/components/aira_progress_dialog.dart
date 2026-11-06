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

  double? _progress;
  late String _statusMessage;

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

    // Execute task after the dialog is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) => _executeTask());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _executeTask() async {
    try {
      await widget.task((progress, statusMessage) {
        if (mounted) {
          setState(() {
            _progress = progress.clamp(0.0, 1.0);
            _statusMessage = statusMessage;
          });
        }
      });
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
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
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.accentColor.withValues(alpha: 0.12),
                        border: Border.all(
                          color: widget.accentColor.withValues(alpha: 0.35),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          widget.icon,
                          color: widget.accentColor,
                          size: 30,
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
                        fontSize: 13.5,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Progress Bar ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 8,
                      child: _progress == null
                          ? LinearProgressIndicator(
                              backgroundColor: widget.accentColor.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                            )
                          : LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: widget.accentColor.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Percentage Display ──
                  if (_progress != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(_progress! * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.accentColor,
                        ),
                      ),
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
                        Icon(Icons.shield_outlined, size: 14, color: textSecondary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Synchronizing records safely. Please do not close this window.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: textSecondary,
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
