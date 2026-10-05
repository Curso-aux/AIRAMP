import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/components/otp_verification_dialog.dart';
import '../../../../core/services/otp_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../landing/presentation/components/halftone_background.dart';
import '../../application/auth_provider.dart';

class _RolePortalConfig {
  final String key;
  final String label;
  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color accentColor;
  final Color badgeBg;
  final String noticeText;
  final String identifierLabel;
  final String identifierHint;
  final String buttonText;

  const _RolePortalConfig({
    required this.key,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.accentColor,
    required this.badgeBg,
    required this.noticeText,
    required this.identifierLabel,
    required this.identifierHint,
    required this.buttonText,
  });
}

class AdminWebLoginScreen extends ConsumerStatefulWidget {
  final String initialRole;

  const AdminWebLoginScreen({
    super.key,
    this.initialRole = 'student',
  });

  @override
  ConsumerState<AdminWebLoginScreen> createState() => _AdminWebLoginScreenState();
}

class _AdminWebLoginScreenState extends ConsumerState<AdminWebLoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  String _error = '';
  late String _selectedRole;

  static const Map<String, _RolePortalConfig> _portals = {
    'student': _RolePortalConfig(
      key: 'student',
      label: 'Student',
      title: 'Student Portal',
      subtitle: 'Personalized Learning, Modules & Quizzes',
      badgeText: 'LEARNER ACCESS',
      icon: Icons.school_rounded,
      accentColor: Color(0xFF0284C7), // Sky / Cyan blue
      badgeBg: Color(0xFFE0F2FE),
      noticeText: 'Sign in with your Student ID (e.g. 001-0001) or username.',
      identifierLabel: 'Student ID or Username',
      identifierHint: 'e.g. 001-0001 or khev',
      buttonText: 'Sign In to Student Portal',
    ),
    'teacher': _RolePortalConfig(
      key: 'teacher',
      label: 'Teacher',
      title: 'Teacher Portal',
      subtitle: 'Classroom Management & Scoring Hub',
      badgeText: 'FACULTY ACCESS',
      icon: Icons.assignment_ind_rounded,
      accentColor: Color(0xFF9333EA), // Purple
      badgeBg: Color(0xFFF3E8FF),
      noticeText: 'Welcome Educator! Sign in with your Faculty email or Teacher username.',
      identifierLabel: 'Faculty Email or Username',
      identifierHint: 'e.g. john.reyes, sir.john, or teacher@deped.gov.ph',
      buttonText: 'Sign In to Teacher Portal',
    ),
    'admin': _RolePortalConfig(
      key: 'admin',
      label: 'Admin',
      title: 'Admin Web Console',
      subtitle: 'Institutional Governance & Oversight',
      badgeText: 'INSTITUTION ACCESS',
      icon: Icons.admin_panel_settings_rounded,
      accentColor: Color(0xFF059669), // Emerald
      badgeBg: Color(0xFFD1FAE5),
      noticeText: 'Authorized School Administrators only. Manage curriculum, staff assignments, and analytics.',
      identifierLabel: 'Administrator Email or Username',
      identifierHint: 'e.g. aira@admin, admin, or admin@aira.edu',
      buttonText: 'Sign In to Admin Console',
    ),
  };

  @override
  void initState() {
    super.initState();
    _selectedRole = _normalizeRole(widget.initialRole);
  }

  @override
  void didUpdateWidget(AdminWebLoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRole != widget.initialRole) {
      setState(() {
        _selectedRole = _normalizeRole(widget.initialRole);
        _error = '';
      });
    }
  }

  String _normalizeRole(String role) {
    final lower = role.toLowerCase().trim();
    if (lower == 'teacher' || lower == 'faculty') return 'teacher';
    if (lower == 'admin' || lower == 'administrator' || lower == 'institution') return 'admin';
    return 'student';
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _error = '');

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your login identifier and password.');
      return;
    }

    try {
      await ref.read(authProvider.notifier).login(identifier, password);
      if (!mounted) return;
      final user = ref.read(authProvider);

      if (user != null) {
        // Automatic routing based on verified account role
        if (user.role == 'admin' || user.role == 'super_admin') {
          // Require 2FA OTP verification if admin has a registered email
          if (user.email.isNotEmpty && user.email.contains('@')) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                content: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          'Sending administrator 2FA code to ${OtpService.maskEmail(user.email)}...',
                          style: TextStyle(color: AppTheme.text, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            final otpResult = await OtpService().requestEmailVerificationOtp(
              targetEmail: user.email,
              fullName: user.fullName,
              userId: user.id,
              role: user.role,
              purpose: 'Administrator 2FA Sign-In',
            );

            if (!mounted) return;
            Navigator.of(context, rootNavigator: true).pop();

            if (!otpResult.success) {
              setState(() => _error = otpResult.message);
              await ref.read(authProvider.notifier).logout();
              return;
            }

            final verified = await OtpVerificationDialog.show(
              context: context,
              email: user.email,
              userId: user.id,
              fullName: user.fullName,
              role: user.role,
              onVerify: (code) async {
                return await OtpService().verifyOtp(
                  identifier: user.id,
                  enteredCode: code,
                );
              },
              onResend: () async {
                final res = await OtpService().requestEmailVerificationOtp(
                  targetEmail: user.email,
                  fullName: user.fullName,
                  userId: user.id,
                  role: user.role,
                  purpose: 'Administrator 2FA Sign-In',
                );
                return res.success;
              },
            );

            if (!mounted) return;
            if (verified != true) {
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                setState(() => _error = '2FA verification was cancelled or unverified.');
              }
              return;
            }
          }

          if (mounted) context.go('/admin/dashboard');
        } else if (user.role == 'teacher') {
          if (mounted) context.go('/teacher/dashboard');
        } else {
          if (mounted) context.go('/student/home');
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLoading = ref.watch(authProvider.notifier).isLoading;
    final config = _portals[_selectedRole] ?? _portals['student']!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: HalftoneBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: config.accentColor.withValues(alpha: 0.12),
                      blurRadius: 36,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Portal Icon
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: config.accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: config.accentColor.withValues(alpha: 0.35), width: 1.5),
                        ),
                        child: Icon(
                          config.icon,
                          color: config.accentColor,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? config.accentColor.withValues(alpha: 0.2) : config.badgeBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: config.accentColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          config.badgeText,
                          style: TextStyle(
                            color: config.accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Title & Subtitle
                    Text(
                      config.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      config.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Notice Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: config.accentColor.withValues(alpha: isDark ? 0.1 : 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: config.accentColor.withValues(alpha: 0.22)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline_rounded, color: config.accentColor, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              config.noticeText,
                              style: TextStyle(
                                color: AppTheme.text,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Error Message Banner
                    if (_error.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error,
                                style: TextStyle(
                                  color: AppTheme.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Identifier Input
                    Text(
                      config.identifierLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _identifierController,
                      maxLength: 50,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      keyboardType: TextInputType.text,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: config.identifierHint,
                        counterText: '',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: config.accentColor),
                        filled: true,
                        fillColor: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.03),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: config.accentColor, width: 2),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 18),

                    // Password Input
                    Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      maxLength: 16,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        counterText: '',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: config.accentColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.03),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: config.accentColor, width: 2),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 10),

                    // Forgot Password Link below Password Input
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => context.push('/forgot-password'),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: config.accentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign In Button
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : _handleLogin,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.login_rounded, size: 18),
                      label: Text(isLoading ? 'Signing In...' : config.buttonText),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: config.accentColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        elevation: 4,
                        shadowColor: config.accentColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Floating Top-left Return to Home Button
        Positioned(
          top: 12,
          left: 12,
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white70 : AppTheme.text,
              size: 24,
            ),
            tooltip: 'Return to Home',
            onPressed: () => context.go('/'),
          ),
        ),
        // Floating Top-right Dark / Light Mode Toggle
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : config.accentColor,
              size: 22,
            ),
          ),
        ),
      ],
    ),
  ),
),
);
  }
}
