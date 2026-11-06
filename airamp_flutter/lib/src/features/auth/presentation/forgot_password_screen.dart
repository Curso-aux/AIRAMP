import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/theme/app_theme.dart';
import '../application/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  // Step 1: Identify Account
  // Step 2: Verify 6-Digit Code
  // Step 3: Set New Password
  int _currentStep = 1;

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FocusNode _identifierFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();
  final FocusNode _newPasswordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Account identity retrieved after Step 1
  String _targetEmail = '';
  String _maskedEmail = '';
  String _userId = '';
  String _fullName = '';
  String _role = '';

  // Ephemeral Reset Ticket issued after Step 2 verification
  String? _resetTicket;

  // Resend cooldown timer
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onPasswordFieldsChanged);
    _confirmPasswordController.addListener(_onPasswordFieldsChanged);
    _otpController.addListener(_onOtpChanged);
  }

  void _onPasswordFieldsChanged() {
    if (mounted) setState(() {});
  }

  void _onOtpChanged() {
    final code = _otpController.text.replaceAll(' ', '').trim();
    if (code.length == 6 && _currentStep == 2 && !_isLoading) {
      _handleVerifyOtp();
    }
  }

  void _toggleObscureNewPass() {
    setState(() => _obscureNewPass = !_obscureNewPass);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _newPasswordFocusNode.requestFocus();
        _newPasswordController.selection = TextSelection.fromPosition(
          TextPosition(offset: _newPasswordController.text.length),
        );
      }
    });
  }

  void _toggleObscureConfirmPass() {
    setState(() => _obscureConfirmPass = !_obscureConfirmPass);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _confirmPasswordFocusNode.requestFocus();
        _confirmPasswordController.selection = TextSelection.fromPosition(
          TextPosition(offset: _confirmPasswordController.text.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _newPasswordController.removeListener(_onPasswordFieldsChanged);
    _confirmPasswordController.removeListener(_onPasswordFieldsChanged);
    _otpController.removeListener(_onOtpChanged);

    _identifierController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    _identifierFocusNode.dispose();
    _otpFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _secondsRemaining = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'super_admin':
        return 'Administrator';
      case 'teacher':
        return 'Faculty / Teacher';
      case 'student':
        return 'Student';
      default:
        return 'School Account';
    }
  }

  // ── Step 1: Send Verification Code ──
  Future<void> _handleSendOtp() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Account ID.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await OtpService().requestOtpForUser(identifier: identifier);
      if (!mounted) return;

      if (res.success) {
        setState(() {
          _isLoading = false;
          _targetEmail = res.email ?? '';
          _maskedEmail = OtpService.maskEmail(_targetEmail);
          _userId = res.userId ?? identifier;
          _fullName = res.fullName ?? 'User';
          _role = res.role ?? 'student';
          _currentStep = 2;
          _errorMessage = null;
        });
        _otpController.clear();
        _startTimer();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpFocusNode.requestFocus();
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  // ── Step 2: Resend Verification Code ──
  Future<void> _handleResendOtp() async {
    if (_secondsRemaining > 0 || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await OtpService().requestOtpDirect(
        userId: _userId,
        email: _targetEmail,
        fullName: _fullName,
        role: _role,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success) {
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A fresh verification code was sent to $_maskedEmail'),
            backgroundColor: AppTheme.primary,
          ),
        );
      } else {
        setState(() => _errorMessage = res.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Resend error: $e';
      });
    }
  }

  // ── Step 2: Verify Code and Issue Reset Ticket ──
  Future<void> _handleVerifyOtp() async {
    final code = _otpController.text.replaceAll(' ', '').trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final verifyRes = await OtpService().verifyOtpAndIssueTicket(
        identifier: _userId,
        enteredCode: code,
      );

      if (!mounted) return;

      if (verifyRes.success && verifyRes.resetTicket != null) {
        setState(() {
          _isLoading = false;
          _resetTicket = verifyRes.resetTicket;
          _currentStep = 3;
          _errorMessage = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _newPasswordFocusNode.requestFocus();
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = verifyRes.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Verification error: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  // ── Step 3: Complete Password Reset with Ticket ──
  Future<void> _handleCompletePasswordReset() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters long.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    if (_resetTicket == null || _resetTicket!.isEmpty) {
      setState(() => _errorMessage = 'Verification session expired. Please verify your code again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).completePasswordResetWithTicket(
            identifier: _userId,
            resetTicket: _resetTicket!,
            newPassword: newPass,
          );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Show success modal and navigate back to login
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                'Password Reset Complete',
                style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            'Your password has been successfully updated! You can now sign in using your new password.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Back to Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _handleBackNavigation() {
    if (_currentStep == 2) {
      setState(() {
        _currentStep = 1;
        _errorMessage = null;
      });
    } else if (_currentStep == 3) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Leave password reset?', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
          content: Text(
            'If you exit now, your verification session will end and you will need to request a new code.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Stay Here', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _currentStep = 1;
                  _resetTicket = null;
                  _errorMessage = null;
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              child: const Text('Start Over', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;
    final hasMinLength = newPass.length >= 6;
    final doPasswordsMatch = newPass.isNotEmpty && newPass == confirmPass;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.text),
          onPressed: _handleBackNavigation,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step Progress Stepper
                  _buildProgressStepper(),
                  const SizedBox(height: 24),

                  // Icon badge
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _currentStep == 1
                            ? Icons.lock_reset_rounded
                            : _currentStep == 2
                                ? Icons.mark_email_read_outlined
                                : Icons.lock_outline_rounded,
                        size: 32,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header Titles
                  Text(
                    _currentStep == 1
                        ? 'Reset Password'
                        : _currentStep == 2
                            ? 'Enter Verification Code'
                            : 'Create New Password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentStep == 1
                        ? 'Enter your Account ID (e.g. S-100-0001) to receive a verification code.'
                        : _currentStep == 2
                            ? 'We sent a 6-digit security code to $_maskedEmail. Enter it below to verify your account.'
                            : 'Your identity has been confirmed. Choose a secure new password for your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Error notification box
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 18, color: AppTheme.error),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(fontSize: 13, color: AppTheme.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ══════ STEP 1: IDENTIFIER INPUT ══════
                  if (_currentStep == 1) ...[
                    Text(
                      'Account ID',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _identifierController,
                      focusNode: _identifierFocusNode,
                      maxLength: 60,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      style: TextStyle(color: AppTheme.text, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'e.g. S-100-0001, T-100-0001, or A-100-0001',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        counterText: '',
                        prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.primary, width: 2),
                        ),
                      ),
                      onSubmitted: (_) => _handleSendOtp(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Send Verification Code',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],

                  // ══════ STEP 2: CODE VERIFICATION ══════
                  if (_currentStep == 2) ...[
                    // Friendly Account Card (No raw IDs, clean bullet)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.person_outline_rounded, color: AppTheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fullName,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.text),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getRoleLabel(_role),
                                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Verified Target',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    Text(
                      '6-Digit Verification Code',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _otpController,
                      focusNode: _otpFocusNode,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 10,
                        color: AppTheme.primary,
                        fontFamily: 'Courier',
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••••',
                        hintStyle: TextStyle(
                          fontSize: 28,
                          letterSpacing: 10,
                          color: AppTheme.textMuted.withValues(alpha: 0.3),
                          fontFamily: 'Courier',
                        ),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.primary, width: 2),
                        ),
                      ),
                      onSubmitted: (_) => _handleVerifyOtp(),
                    ),
                    const SizedBox(height: 14),

                    // Resend countdown row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive the email? ",
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                        if (_secondsRemaining > 0)
                          Text(
                            'Resend in ${_secondsRemaining}s',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                          )
                        else
                          GestureDetector(
                            onTap: _isLoading ? null : _handleResendOtp,
                            child: Text(
                              'Resend Code',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _otpController.text.trim().length < 6) ? null : _handleVerifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Verify Code',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _currentStep = 1;
                            _errorMessage = null;
                          });
                        },
                        child: Text(
                          'Use a different account',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ),
                    ),
                  ],

                  // ══════ STEP 3: CREATE NEW PASSWORD ══════
                  if (_currentStep == 3) ...[
                    // New Password Field
                    Text(
                      'New Password',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: ValueKey('forgot_step3_new_pass_$_obscureNewPass'),
                      focusNode: _newPasswordFocusNode,
                      controller: _newPasswordController,
                      maxLength: 16,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      obscureText: _obscureNewPass,
                      style: TextStyle(color: AppTheme.text, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Enter new password (min. 6 chars)',
                        counterText: '',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.textMuted),
                        suffixIcon: IconButton(
                          focusNode: FocusNode(canRequestFocus: false, skipTraversal: true),
                          icon: Icon(
                            _obscureNewPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppTheme.textMuted,
                            size: 19,
                          ),
                          onPressed: _toggleObscureNewPass,
                        ),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Confirm New Password Field
                    Text(
                      'Confirm New Password',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: ValueKey('forgot_step3_confirm_pass_$_obscureConfirmPass'),
                      focusNode: _confirmPasswordFocusNode,
                      controller: _confirmPasswordController,
                      maxLength: 16,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      obscureText: _obscureConfirmPass,
                      style: TextStyle(color: AppTheme.text, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Repeat new password',
                        counterText: '',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        prefixIcon: Icon(Icons.lock_reset_rounded, color: AppTheme.textMuted),
                        suffixIcon: IconButton(
                          focusNode: FocusNode(canRequestFocus: false, skipTraversal: true),
                          icon: Icon(
                            _obscureConfirmPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppTheme.textMuted,
                            size: 19,
                          ),
                          onPressed: _toggleObscureConfirmPass,
                        ),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.primary, width: 2),
                        ),
                      ),
                      onSubmitted: (_) {
                        if (hasMinLength && doPasswordsMatch && !_isLoading) {
                          _handleCompletePasswordReset();
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Live requirement checklist
                    _buildRequirementCheck(
                      text: 'At least 6 characters long',
                      isMet: hasMinLength,
                    ),
                    const SizedBox(height: 6),
                    _buildRequirementCheck(
                      text: 'Passwords match',
                      isMet: doPasswordsMatch,
                    ),
                    const SizedBox(height: 24),

                    // Reset Password Button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (!hasMinLength || !doPasswordsMatch || _isLoading)
                            ? null
                            : _handleCompletePasswordReset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Save Password & Unlock Account',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Return to login link
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        'Return to Sign In',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
    );
  }

  // ── Step Progress Stepper Bar ──
  Widget _buildProgressStepper() {
    return Row(
      children: [
        _buildStepNode(step: 1, label: 'Account', isActive: _currentStep >= 1, isCurrent: _currentStep == 1),
        _buildStepConnector(isPassed: _currentStep >= 2),
        _buildStepNode(step: 2, label: 'Verification', isActive: _currentStep >= 2, isCurrent: _currentStep == 2),
        _buildStepConnector(isPassed: _currentStep >= 3),
        _buildStepNode(step: 3, label: 'Password', isActive: _currentStep >= 3, isCurrent: _currentStep == 3),
      ],
    );
  }

  Widget _buildStepNode({required int step, required String label, required bool isActive, required bool isCurrent}) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppTheme.primary
                  : isActive
                      ? AppTheme.primary.withValues(alpha: 0.25)
                      : AppTheme.border.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCurrent
                  ? Text(
                      '$step',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    )
                  : isActive
                      ? Icon(Icons.check_rounded, color: AppTheme.primary, size: 16)
                      : Text(
                          '$step',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: isCurrent
                  ? AppTheme.text
                  : isActive
                      ? AppTheme.textSecondary
                      : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector({required bool isPassed}) {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: isPassed ? AppTheme.primary : AppTheme.border.withValues(alpha: 0.5),
    );
  }

  Widget _buildRequirementCheck({required String text, required bool isMet}) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: isMet ? Colors.green : AppTheme.textMuted,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            color: isMet ? AppTheme.text : AppTheme.textMuted,
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
