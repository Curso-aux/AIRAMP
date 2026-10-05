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
  int _currentStep = 1; // 1: Enter ID/Email, 2: Enter OTP & New Password

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Captured user recovery info
  String _targetEmail = '';
  String _maskedEmail = '';
  String _userId = '';
  String _fullName = '';
  String _role = '';

  // Resend cooldown timer
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _identifierController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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

  // ── Step 1: Send OTP to User's Email via SMTP ──
  Future<void> _handleSendOtp() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Student ID, Teacher ID, or registered email.');
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
        _startTimer();
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

  // ── Resend OTP ──
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

  // ── Step 2: Verify OTP and Reset Password ──
  Future<void> _handleResetPassword() async {
    final otp = _otpController.text.replaceAll(' ', '').trim();
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit verification code.');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _errorMessage = 'New password must be at least 6 characters long.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).resetPasswordWithOtp(
            identifier: _userId,
            otpCode: otp,
            newPassword: newPass,
          );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      // Show success modal and navigate back to login
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                'Password Reset Complete',
                style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            'Your password for account $_userId has been successfully updated in the system.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
              ),
              child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.text),
          onPressed: () {
            if (_currentStep == 2) {
              setState(() {
                _currentStep = 1;
                _errorMessage = null;
              });
            } else {
              context.pop();
            }
          },
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
                        _currentStep == 1 ? Icons.lock_reset : Icons.shield_outlined,
                        size: 32,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header Titles
                  Text(
                    _currentStep == 1 ? 'Reset Password' : 'Enter Verification Code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentStep == 1
                        ? 'Enter your Student ID (001-XXXX), Teacher ID (002-XXXX), or registered school email to receive an OTP code.'
                        : 'Enter the 6-digit verification code sent to $_maskedEmail and create a new password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

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
                      'Account ID or Email',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _identifierController,
                      maxLength: 50,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      style: TextStyle(color: AppTheme.text, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'e.g. 001-0001 or name@gmail.com',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        counterText: '',
                        prefixIcon: Icon(Icons.person_search_outlined, color: AppTheme.textMuted),
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
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text(
                                'Send Verification Code',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],

                  // ══════ STEP 2: OTP & NEW PASSWORD INPUTS ══════
                  if (_currentStep == 2) ...[
                    // Account info pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_circle_outlined, size: 20, color: AppTheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$_fullName ($_userId) &bull; ${_role.toUpperCase()}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // OTP Code Field
                    Text(
                      '6-Digit Security Code (OTP)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: AppTheme.primary,
                        fontFamily: 'Courier',
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        hintStyle: TextStyle(
                          fontSize: 26,
                          letterSpacing: 8,
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
                    ),
                    const SizedBox(height: 12),

                    // Resend timer row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive the email? ",
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        if (_secondsRemaining > 0)
                          Text(
                            'Resend in ${_secondsRemaining}s',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                          )
                        else
                          GestureDetector(
                            onTap: _isLoading ? null : _handleResendOtp,
                            child: Text(
                              'Resend Code',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // New Password Field
                    Text(
                      'New Password',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _newPasswordController,
                      maxLength: 16,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      obscureText: _obscureNewPass,
                      style: TextStyle(color: AppTheme.text, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Minimum 6 characters',
                        counterText: '',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textMuted),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppTheme.textMuted,
                          ),
                          onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
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
                      controller: _confirmPasswordController,
                      maxLength: 16,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      obscureText: _obscureConfirmPass,
                      style: TextStyle(color: AppTheme.text, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Repeat new password',
                        counterText: '',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        prefixIcon: Icon(Icons.lock_reset_outlined, color: AppTheme.textMuted),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppTheme.textMuted,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
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
                      onSubmitted: (_) => _handleResetPassword(),
                    ),
                    const SizedBox(height: 24),

                    // Reset Password Button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleResetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text(
                                'Confirm & Reset Password',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

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
}
