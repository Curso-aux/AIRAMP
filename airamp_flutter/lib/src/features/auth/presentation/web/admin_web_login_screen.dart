import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/components/app_logo.dart';
import '../../../landing/presentation/components/halftone_background.dart';
import '../../application/auth_provider.dart';

class AdminWebLoginScreen extends ConsumerStatefulWidget {
  const AdminWebLoginScreen({super.key});

  @override
  ConsumerState<AdminWebLoginScreen> createState() => _AdminWebLoginScreenState();
}

class _AdminWebLoginScreenState extends ConsumerState<AdminWebLoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  String _error = '';

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminLogin() async {
    setState(() => _error = '');

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your administrator email and password.');
      return;
    }

    try {
      await ref.read(authProvider.notifier).login(identifier, password);
      final user = ref.read(authProvider);

      if (user != null) {
        // Strict Authorization: Only admin and super_admin allowed on Web!
        if (user.role == 'admin' || user.role == 'super_admin') {
          if (mounted) context.go('/admin/dashboard');
        } else {
          // Immediately revoke session on web for non-admin roles
          await ref.read(authProvider.notifier).logout();
          setState(() {
            final roleName = user.role == 'teacher' ? 'Teacher' : 'Student';
            _error = 'Access Restricted: You are signed in with a $roleName account. The Web Portal is exclusively reserved for School Administrators. Please open the AIRAMP application on your mobile device or Windows computer.';
          });
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Return to Home',
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: HalftoneBackground(
        child: Center(
          child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
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
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Admin Shield Icon
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        Icons.shield_rounded,
                        color: AppTheme.primary,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title & Subtitle
                  Text(
                    'AIRA Admin Console',
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
                    'Institutional Governance & Curriculum Management',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Authorization Badge / Notice
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Authorized School Administrators only. Teachers and students must use the AIRAMP mobile/desktop app.',
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
                  const SizedBox(height: 24),

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
                    const SizedBox(height: 20),
                  ],

                  // Email or Username Input
                  Text(
                    'Administrator Email / Username',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _identifierController,
                    keyboardType: TextInputType.text,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'e.g. Aira Admin, aira@admin, or admin@aira.edu',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      filled: true,
                      fillColor: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _handleAdminLogin(),
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
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      hintText: 'Enter administrator password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _handleAdminLogin(),
                  ),
                  const SizedBox(height: 28),

                  // Sign In Button
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _handleAdminLogin,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(isLoading ? 'Signing In...' : 'Sign In to Web Admin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(0, 50),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      elevation: 4,
                      shadowColor: AppTheme.glowPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Back to Landing link
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Return to AIRA Home Page'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
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
    );
  }
}
