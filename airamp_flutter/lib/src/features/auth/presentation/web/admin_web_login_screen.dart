import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/components/auth/required_change_password_dialog.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/components/app_logo.dart';
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
  final _passwordFocusNode = FocusNode();
  bool _showPassword = false;
  bool _isSubmitting = false;
  String _error = '';

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isSubmitting) return;
    setState(() => _error = '');

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your User ID and password.');
      return;
    }

    if (identifier.contains('@')) {
      setState(() => _error = 'Wrong User ID. ID only.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(authProvider.notifier).login(identifier, password);
      if (!mounted) return;
      final user = ref.read(authProvider);

      if (user != null) {
        // Automatic routing based on verified account role
        if (user.role == 'super_admin') {
          // Super admin goes directly to the Super Admin Governance Portal
          if (mounted) context.go('/super-admin');
          return;
        } else if (user.role == 'admin') {
          if (user.mustChangePassword) {
            RequiredChangePasswordDialog.resetSession();
            if (mounted) context.go('/admin/profile');
          } else {
            if (mounted) context.go('/admin/dashboard');
          }
          return;
        } else if (user.role == 'teacher') {
          if (user.mustChangePassword) {
            RequiredChangePasswordDialog.resetSession();
            if (mounted) context.go('/teacher/profile');
          } else {
            if (mounted) context.go('/teacher/dashboard');
          }
        } else {
          if (user.mustChangePassword) {
            RequiredChangePasswordDialog.resetSession();
            if (mounted) context.go('/student/profile');
          } else {
            if (mounted) context.go('/student/home');
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = AppTheme.primary;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    const identifierHint = 'e.g. S-100-0001, T-100-0001, or A-100-0001';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: HalftoneBackground(
        opacity: isDark ? 0.20 : 0.14,
        child: SafeArea(
          child: Stack(
            children: [
              // High-Contrast Floating Return to Home Button
              Positioned(
                top: isMobile ? 12 : 16,
                left: isMobile ? 12 : 16,
                child: Material(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.90)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => context.go('/'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.black.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? Colors.white : AppTheme.text,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Return to Home',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // High-Contrast Floating Dark / Light Mode Toggle
              Positioned(
                top: isMobile ? 12 : 16,
                right: isMobile ? 12 : 16,
                child: Material(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.90)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.black.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: isDark ? Colors.amber : accentColor,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

              // Centered Focused Login Form Card
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: isMobile ? 24 : 40,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 24 : 36),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                            blurRadius: isMobile ? 24 : 36,
                            offset: Offset(0, isMobile ? 8 : 14),
                          ),
                          BoxShadow(
                            color: accentColor.withValues(alpha: isDark ? 0.10 : 0.06),
                            blurRadius: 40,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: AutofillGroup(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Branded Centered Logo Emblem Lockup
                            Center(
                              child: Container(
                                width: isMobile ? 64 : 72,
                                height: isMobile ? 64 : 72,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: isDark ? 0.18 : 0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: isDark ? 0.35 : 0.22),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: AppLogo.mark(
                                    size: isMobile ? 38 : 44,
                                    isDark: isDark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Portal Title & Subtitle (Clean & Direct)
                            Text(
                              'AIRAMP Portal',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isMobile ? 22 : 25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: AppTheme.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sign in with your institutional account to continue',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Error Message Banner
                            if (_error.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                              const SizedBox(height: 20),
                            ],

                            // Identifier Input
                            Text(
                              'User ID',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _identifierController,
                              maxLength: 80,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              keyboardType: TextInputType.text,
                              autofillHints: const [AutofillHints.username],
                              textInputAction: TextInputAction.next,
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
                              key: ValueKey('admin_login_pass_$_showPassword'),
                              focusNode: _passwordFocusNode,
                              controller: _passwordController,
                              maxLength: 128,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              obscureText: !_showPassword,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                counterText: '',
                                prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: accentColor),
                                suffixIcon: IconButton(
                                  focusNode: FocusNode(canRequestFocus: false, skipTraversal: true),
                                  icon: Icon(
                                    _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() => _showPassword = !_showPassword);
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        _passwordFocusNode.requestFocus();
                                        _passwordController.selection = TextSelection.fromPosition(
                                          TextPosition(offset: _passwordController.text.length),
                                        );
                                      }
                                    });
                                  },
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
                              onPressed: _isSubmitting ? null : _handleLogin,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.login_rounded, size: 18),
                              label: Text(_isSubmitting ? 'Signing In...' : 'Sign In to Portal'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 52),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                elevation: 3,
                                shadowColor: accentColor.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Footer Link: Terms of Service / Conditions & Privacy Policy
                            Center(
                              child: InkWell(
                                onTap: () => context.push('/terms'),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.article_outlined,
                                        size: 14,
                                        color: accentColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Terms of Service & Privacy Policy',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: accentColor,
                                            decoration: TextDecoration.underline,
                                            decorationColor: accentColor.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
