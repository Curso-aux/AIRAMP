import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/components/auth/required_change_password_dialog.dart';
import '../../../core/services/session_draft_service.dart';
import '../application/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _showPassword = false;
  String _error = '';

  // Smooth entrance & tactile feedback animations
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  late final AnimationController _buttonScaleController;
  late final Animation<double> _buttonScaleAnimation;

  final SessionDraftDisposer _draftDisposer = SessionDraftDisposer();
  static const String _formId = 'auth_login';

  @override
  void initState() {
    super.initState();
    _draftDisposer.add(
      _identifierController.bindSessionDraft(
        formId: _formId,
        fieldKey: 'identifier',
        onDraftRestored: () => setState(() {}),
      ),
    );

    // Smooth Entrance: 400ms ease-out cubic fade + slide
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    _entranceController.forward();

    // Tactile button bounce
    _buttonScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _buttonScaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _draftDisposer.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _entranceController.dispose();
    _buttonScaleController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _error = '';
    });

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Please enter your User ID and password.';
      });
      return;
    }

    if (identifier.contains('@')) {
      setState(() {
        _error = 'Wrong User ID. ID only.';
      });
      return;
    }

    try {
      await ref.read(authProvider.notifier).login(identifier, password);
      final user = ref.read(authProvider);
      if (user != null) {
        // Mobile App is strictly for Students and Teachers
        if (user.role == 'admin' || user.role == 'super_admin') {
          await ref.read(authProvider.notifier).logout();
          setState(() {
            _error =
                'Administrator accounts can only access the AIRAMP Web Portal (via web browser). This mobile app is exclusively for Students and Teachers.';
          });
          return;
        }

        SessionDraftService.instance.clearForm(_formId);

        if (user.mustChangePassword) {
          final isTeacher = user.role == 'teacher';
          RequiredChangePasswordDialog.resetSession();
          if (mounted) {
            context.go(isTeacher ? '/teacher/profile' : '/student/profile');
          }
          return;
        }

        if (user.role == 'teacher') {
          if (mounted) context.go('/teacher/dashboard');
        } else if (user.role == 'student') {
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
    final isLoading = ref.watch(authProvider.notifier).isLoading;
    final isDark =
        Theme.of(context).brightness == Brightness.dark || AppTheme.isDark;

    // Palette tuned for a clean, formal academic institution portal
    final canvasBg = isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final inputFill = isDark
        ? const Color(0xFF1B2638)
        : const Color(0xFFF8FAFC);
    final primaryAccent = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;

    return Scaffold(
      backgroundColor: canvasBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Subtle, serene ambient lighting at the top
          Positioned(
            top: -100,
            left: 0,
            right: 0,
            height: 380,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.1,
                  colors: [
                    primaryAccent.withValues(alpha: isDark ? 0.08 : 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 2. Main Login Content with smooth entrance animation
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Clean Institutional Brand Hero
                            _buildBrandHero(isDark),

                            const SizedBox(height: 28),

                            // Elevated, Crisp Form Card
                            _buildFormCard(
                              context: context,
                              isDark: isDark,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              inputFill: inputFill,
                              primaryAccent: primaryAccent,
                              isLoading: isLoading,
                            ),

                            const SizedBox(height: 24),

                            // Quiet Institutional Footnote (No Register / Sign-up)
                            _buildFooter(isDark),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Authentic, clean branding without cheap border wrappers
  Widget _buildBrandHero(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Clean Mascot Emblem rendered naturally with soft ground depth
        SizedBox(
          width: 104,
          height: 104,
          child: Image.asset(
            'assets/images/aira_mascot_logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) =>
                Image.asset('assets/images/aira_logo.png', fit: BoxFit.contain),
          ),
        ),

        const SizedBox(height: 14),

        // Brand Title
        Text(
          'AIRA',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.5,
            color: isDark ? AppTheme.darkTextBright : AppTheme.lightText,
          ),
        ),

        const SizedBox(height: 4),

        // Institutional Subtitle
        Text(
          'Academic Integrated Review & Assessment',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  /// Modern, crisp institutional form card
  Widget _buildFormCard({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color inputFill,
    required Color primaryAccent,
    required bool isLoading,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 30.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF0F172A,
            ).withValues(alpha: isDark ? 0.30 : 0.04),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(
              0xFF0F172A,
            ).withValues(alpha: isDark ? 0.18 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Title
          Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: isDark ? AppTheme.darkTextBright : AppTheme.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sign in to your academic account',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextMuted,
            ),
          ),

          const SizedBox(height: 22),

          // Error banner
          if (_error.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkErrorSoft
                    : AppTheme.lightErrorSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark ? AppTheme.darkError : AppTheme.lightError)
                      .withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: isDark ? AppTheme.darkError : AppTheme.lightError,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error,
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkError
                            : AppTheme.lightError,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Identifier Field Label
          _buildFieldLabel('User ID', isDark),
          const SizedBox(height: 6),
          TextField(
            controller: _identifierController,
            maxLength: 50,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextBright : AppTheme.lightText,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: true,
            decoration: _inputDecoration(
              hint: 'e.g. S-100-0001, T-100-0001, or A-100-0001',
              prefixIcon: Icons.badge_outlined,
              fillColor: inputFill,
              borderColor: borderColor,
              focusColor: primaryAccent,
              isDark: isDark,
            ),
          ),

          const SizedBox(height: 18),

          // Password Field Label + Forgot Password link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldLabel('Password', isDark),
              GestureDetector(
                onTap: () => context.push('/forgot-password'),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: primaryAccent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            key: ValueKey('login_pass_$_showPassword'),
            focusNode: _passwordFocusNode,
            controller: _passwordController,
            maxLength: 64,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
            obscureText: !_showPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!isLoading) _handleLogin();
            },
            style: TextStyle(
              color: isDark ? AppTheme.darkTextBright : AppTheme.lightText,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDecoration(
              hint: 'Enter your password',
              prefixIcon: Icons.lock_outline_rounded,
              fillColor: inputFill,
              borderColor: borderColor,
              focusColor: primaryAccent,
              isDark: isDark,
              suffix: IconButton(
                focusNode: FocusNode(
                  canRequestFocus: false,
                  skipTraversal: true,
                ),
                splashRadius: 18,
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: isDark
                      ? AppTheme.darkTextMuted
                      : AppTheme.lightTextMuted,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _showPassword = !_showPassword);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _passwordFocusNode.requestFocus();
                      _passwordController
                          .selection = TextSelection.fromPosition(
                        TextPosition(offset: _passwordController.text.length),
                      );
                    }
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Sign In Action Button
          GestureDetector(
            onTapDown: (_) => _buttonScaleController.forward(),
            onTapUp: (_) {
              _buttonScaleController.reverse();
              if (!isLoading) _handleLogin();
            },
            onTapCancel: () => _buttonScaleController.reverse(),
            child: ScaleTransition(
              scale: _buttonScaleAnimation,
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppTheme.darkPrimary, AppTheme.darkPrimaryDark]
                        : [AppTheme.lightPrimary, AppTheme.lightPrimaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primaryAccent.withValues(
                        alpha: isDark ? 0.35 : 0.28,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sign In',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: isDark ? AppTheme.darkText : AppTheme.lightTextSecondary,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    required Color fillColor,
    required Color borderColor,
    required Color focusColor,
    required bool isDark,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      counterText: '',
      prefixIcon: Icon(
        prefixIcon,
        color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
        size: 20,
      ),
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: focusColor, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppTheme.darkError : AppTheme.lightError,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppTheme.darkError : AppTheme.lightError,
          width: 1.6,
        ),
      ),
    );
  }

  /// Quiet, dignified institutional footnote with Terms & Privacy Policy link
  Widget _buildFooter(bool isDark) {
    final mutedColor = isDark
        ? AppTheme.darkTextMuted
        : const Color(0xFF94A3B8);
    final linkColor = isDark
        ? AppTheme.darkPrimaryLight
        : AppTheme.lightPrimaryDark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: mutedColor),
              Text(
                'DepEd Senior High School Learning Portal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  color: mutedColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => context.push('/terms'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 14,
                  color: linkColor,
                ),
                Text(
                  'Terms of Service, Conditions & Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: linkColor,
                    decoration: TextDecoration.underline,
                    decorationColor: linkColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
