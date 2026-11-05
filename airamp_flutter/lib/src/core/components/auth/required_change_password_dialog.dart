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
/// - Smooth, institutional styling aligned with the system theme
class RequiredChangePasswordDialog extends StatefulWidget {
  final bool isTeacher;
  final String? role;

  const RequiredChangePasswordDialog({
    super.key,
    required this.isTeacher,
    this.role,
  });

  static bool _isShowing = false;
  static bool hasSeenInThisSession = false;

  /// Resets session tracker (e.g. on logout or app restart)
  static void resetSession() {
    hasSeenInThisSession = false;
  }

  /// Shows the modal dialog if not already showing.
  static Future<void> show(
    BuildContext context, {
    required bool isTeacher,
    String? role,
  }) async {
    if (_isShowing) return;
    _isShowing = true;
    hasSeenInThisSession = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        builder: (dialogCtx) => RequiredChangePasswordDialog(
          isTeacher: isTeacher,
          role: role,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<RequiredChangePasswordDialog> createState() =>
      _RequiredChangePasswordDialogState();
}

class _RequiredChangePasswordDialogState
    extends State<RequiredChangePasswordDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (!isTesting) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1.0;
    }

    _pulseScale = Tween<double>(begin: 0.97, end: 1.03).animate(
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

    try {
      final currentLoc = GoRouterState.of(context).matchedLocation;
      String targetRoute =
          widget.isTeacher ? '/teacher/profile' : '/student/profile';

      if (currentLoc.contains('/admin') ||
          widget.role == 'admin' ||
          widget.role == 'super_admin') {
        targetRoute = '/admin/profile';
      }

      if (currentLoc != targetRoute) {
        context.go(targetRoute);
      }
    } catch (_) {
      // In unit/widget tests without GoRouter, Navigator.pop above is sufficient
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;

    // System theme palette
    final cardBg = isDark ? const Color(0xFF141E2E) : Colors.white;
    final cardBorder =
        isDark ? const Color(0xFF243248) : const Color(0xFFE2E8F0);
    final titleColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subtitleColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final boxBg =
        isDark ? const Color(0xFF192436) : const Color(0xFFF8FAFC);
    final boxBorder =
        isDark ? const Color(0xFF24344D) : const Color(0xFFEEF2F6);
    final accentPrimary =
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF0284C7);
    final accentDeep =
        isDark ? const Color(0xFF3B82F6) : const Color(0xFF1D4ED8);

    // Determine role-aware unlock text
    String unlockText = 'Full access to courses & quizzes is unlocked.';
    try {
      final currentLoc = GoRouterState.of(context).matchedLocation;
      if (currentLoc.contains('/admin') ||
          widget.role == 'admin' ||
          widget.role == 'super_admin') {
        unlockText =
            'Full administrative & campus governance access is unlocked.';
      } else if (widget.isTeacher || widget.role == 'teacher') {
        unlockText =
            'Full access to curriculum, gradebooks & rosters is unlocked.';
      }
    } catch (_) {
      if (widget.isTeacher) {
        unlockText =
            'Full access to curriculum, gradebooks & rosters is unlocked.';
      }
    }

    return PopScope(
      canPop: false, // Strictly prevents dismissal via back gesture / button
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cardBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Smooth Institutional Security Badge
                  ScaleTransition(
                    scale: _pulseScale,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF1E3A8A).withValues(alpha: 0.55),
                                  const Color(0xFF0F172A),
                                ]
                              : [
                                  const Color(0xFFEFF6FF),
                                  const Color(0xFFE0E7FF),
                                ],
                        ),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.35)
                              : const Color(0xFFBFDBFE),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentDeep.withValues(
                              alpha: isDark ? 0.22 : 0.12,
                            ),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.lock_reset_rounded,
                          size: 34,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Action Required: Set New Password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'For your account safety and privacy, you are required to establish a personal password on your first login.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: subtitleColor,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Refined Requirement Checklist
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: boxBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: boxBorder),
                    ),
                    child: Column(
                      children: [
                        _buildBulletItem(
                          icon: Icons.shield_outlined,
                          text:
                              'Your temporary default password must be replaced.',
                          iconColor: accentPrimary,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildBulletItem(
                          icon: Icons.key_rounded,
                          text: 'Must be at least 6 characters in length.',
                          iconColor: accentPrimary,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildBulletItem(
                          icon: Icons.verified_user_outlined,
                          text: unlockText,
                          iconColor: accentPrimary,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Button with Smooth System Gradient
                  Container(
                    width: double.infinity,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentPrimary,
                          accentDeep,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentDeep.withValues(
                            alpha: isDark ? 0.35 : 0.22,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _handleProceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
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
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                        ],
                      ),
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

  Widget _buildBulletItem({
    required IconData icon,
    required String text,
    required Color iconColor,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF334155),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
