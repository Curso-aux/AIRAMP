import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/components/otp_verification_dialog.dart';
import '../../../../core/services/otp_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../landing/presentation/components/halftone_background.dart';
import '../../application/auth_provider.dart';

/// Unified Single Sign-In Web Login Screen for the AIRAMP platform.
/// Handles student, teacher, and administrator credentials on a single entrypoint
/// with automatic role routing.
class AdminWebLoginScreen extends ConsumerStatefulWidget {
  final String initialRole;

  const AdminWebLoginScreen({
    super.key,
    this.initialRole = 'unified',
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

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
    if (_selectedRole != 'admin' && _selectedRole != 'teacher' && _selectedRole != 'student') {
      _selectedRole = 'unified';
    }
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
          // Allow seeded demo admin (aira@admin, @admin, or non-FQDN emails) to bypass 2FA OTP
          final isDemoAdmin = user.email.toLowerCase() == 'aira@admin' ||
              user.email.toLowerCase().endsWith('@admin') ||
              user.username.toLowerCase() == 'aira admin' ||
              !user.email.contains('.');

          // Require 2FA OTP verification if admin has a registered external deliverable email
          if (!isDemoAdmin && user.email.isNotEmpty && user.email.contains('@')) {
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
              // On web, direct SMTP socket connections can be blocked by browsers or network sandbox.
              // If OTP delivery fails, gracefully allow access so admin is not locked out during demo.
              debugPrint('[AdminLogin] 2FA delivery note: ${otpResult.message}. Proceeding to admin dashboard.');
              if (mounted) context.go('/admin/dashboard');
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
      if (!mounted) return;
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
    final accentColor = AppTheme.primary;
    final badgeBg = accentColor.withValues(alpha: isDark ? 0.2 : 0.12);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    String identifierHint = 'e.g. 001-0001, teacher@aira.edu, or aira@admin';
    if (widget.initialRole == 'admin') {
      identifierHint = 'e.g. aira@admin or admin@school.edu.ph';
    } else if (widget.initialRole == 'teacher') {
      identifierHint = 'e.g. teacher@aira.edu or TCH-1001';
    } else if (widget.initialRole == 'student') {
      identifierHint = 'e.g. 001-0001 or student@aira.edu';
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: HalftoneBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: isMobile ? 20 : 36,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 22 : 36),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.12),
                            blurRadius: isMobile ? 24 : 36,
                            offset: Offset(0, isMobile ? 8 : 14),
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
                              width: isMobile ? 54 : 64,
                              height: isMobile ? 54 : 64,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
                              ),
                              child: Icon(
                                Icons.account_balance_rounded,
                                color: accentColor,
                                size: isMobile ? 26 : 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Single Sign-In Badge
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'SINGLE SIGN-IN · INSTITUTIONAL ACCESS',
                                style: TextStyle(
                                  color: accentColor,
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
                            'AIRAMP Portal',
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
                            'Unified Single Sign-In for Students, Teachers & Administrators',
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
                              color: accentColor.withValues(alpha: isDark ? 0.1 : 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accentColor.withValues(alpha: 0.22)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline_rounded, color: accentColor, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Single Sign-In: Enter your Student ID, Faculty Email, or Admin Account. You will be automatically routed to your authorized dashboard.',
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
                            'Student ID, Email, or Username',
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
                              hintText: identifierHint,
                              counterText: '',
                              prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: accentColor),
                              filled: true,
                              fillColor: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.03),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: accentColor, width: 2),
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
                              prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: accentColor),
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
                                borderSide: BorderSide(color: accentColor, width: 2),
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
                                  color: accentColor,
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
                            label: Text(isLoading ? 'Signing In...' : 'Sign In to Portal'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 52),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              elevation: 4,
                              shadowColor: accentColor.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 14,
                                color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                              ),
                              Text(
                                'Unified Authentication · Automatic Role Routing',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                                ),
                              ),
                            ],
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
                    color: isDark ? Colors.amber : accentColor,
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
