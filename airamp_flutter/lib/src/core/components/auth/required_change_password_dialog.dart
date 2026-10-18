import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

/// A strictly non-dismissible modal dialog displayed immediately upon first login
/// when an account has a temporary or default password that must be changed.
///
/// Features:
/// - Cannot be closed by tapping the barrier backdrop
/// - Cannot be dismissed via hardware back button (PopScope canPop: false)
/// - Single action button: "Okay, I Understand"
/// - Navigates directly to the student or teacher profile page with visual highlight
class RequiredChangePasswordDialog extends StatefulWidget {
  final bool isTeacher;

  const RequiredChangePasswordDialog({
    super.key,
    required this.isTeacher,
  });

  static bool _isShowing = false;
  static bool hasSeenInThisSession = false;

  /// Resets session tracker (e.g. on logout or app restart)
  static void resetSession() {
    hasSeenInThisSession = false;
  }

  /// Shows the modal dialog if not already showing.
  static Future<void> show(BuildContext context, {required bool isTeacher}) async {
    if (_isShowing) return;
    _isShowing = true;
    hasSeenInThisSession = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.78),
        builder: (dialogCtx) => RequiredChangePasswordDialog(isTeacher: isTeacher),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<RequiredChangePasswordDialog> createState() => _RequiredChangePasswordDialogState();
}

class _RequiredChangePasswordDialogState extends State<RequiredChangePasswordDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleProceed() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();

    final targetRoute = widget.isTeacher ? '/teacher/profile' : '/student/profile';
    try {
      final currentLoc = GoRouterState.of(context).matchedLocation;
      if (currentLoc != targetRoute) {
        context.go(targetRoute);
      }
    } catch (_) {
      context.go(targetRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;

    return PopScope(
      canPop: false, // Strictly prevents dismissal via back gesture / button
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D36) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.6),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: isDark ? 0.22 : 0.14),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Animated Pulsing Security Lock Shield
                ScaleTransition(
                  scale: _pulseScale,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.amber.shade400,
                          const Color(0xFFFF8F00),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock_reset_rounded,
                        size: 38,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  'Password Change Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0B132B),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  'For your account safety and privacy, you are required to create a new personal password on your first login.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),

                // Bullet Requirement List
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildBulletItem(
                        icon: Icons.shield_outlined,
                        text: 'Your temporary default password must be replaced.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildBulletItem(
                        icon: Icons.key_rounded,
                        text: 'Must be at least 6 characters.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildBulletItem(
                        icon: Icons.lock_clock_outlined,
                        text: 'Full access to courses & quizzes is unlocked after this step.',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Single Required Action Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _handleProceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade400,
                      foregroundColor: Colors.black,
                      elevation: 4,
                      shadowColor: Colors.amber.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Okay, I Understand',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletItem({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.amber.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white60 : Colors.black87,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
