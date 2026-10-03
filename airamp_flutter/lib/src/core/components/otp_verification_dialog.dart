import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/otp_service.dart';
import '../theme/app_theme.dart';

/// Modal dialog that prompts the user for a 6-digit OTP sent to their email
/// with a 60-second resend cooldown timer and error feedback.
class OtpVerificationDialog extends StatefulWidget {
  final String email;
  final String userId;
  final String fullName;
  final String role;
  final Future<bool> Function(String otpCode) onVerify;
  final Future<bool> Function() onResend;

  const OtpVerificationDialog({
    super.key,
    required this.email,
    required this.userId,
    required this.fullName,
    required this.role,
    required this.onVerify,
    required this.onResend,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String email,
    required String userId,
    required String fullName,
    required String role,
    required Future<bool> Function(String otpCode) onVerify,
    required Future<bool> Function() onResend,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OtpVerificationDialog(
        email: email,
        userId: userId,
        fullName: fullName,
        role: role,
        onVerify: onVerify,
        onResend: onResend,
      ),
    );
  }

  @override
  State<OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends State<OtpVerificationDialog> {
  final TextEditingController _codeController = TextEditingController();
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
  }

  void _startCooldownTimer() {
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

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final lockoutMsg = OtpService().getLockoutMessage(widget.userId);
    if (lockoutMsg != null) {
      setState(() {
        _isVerifying = false;
        _errorMessage = lockoutMsg;
      });
      return;
    }

    try {
      final success = await widget.onVerify(code);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        final postLockout = OtpService().getLockoutMessage(widget.userId);
        setState(() {
          _isVerifying = false;
          _errorMessage = postLockout ?? 'Invalid or expired verification code. Please check your email or request a new code.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleResend() async {
    if (_secondsRemaining > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final ok = await widget.onResend();
      if (!mounted) return;
      setState(() => _isResending = false);
      if (ok) {
        _startCooldownTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A new 6-digit code has been sent to ${widget.email}'),
            backgroundColor: AppTheme.primary,
          ),
        );
      } else {
        setState(() => _errorMessage = 'Could not resend email. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _errorMessage = 'Resend error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maskedEmail = OtpService.maskEmail(widget.email);

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.border, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon Header
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mark_email_read_outlined, size: 28, color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Enter Security Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit OTP code to\n'),
                    TextSpan(
                      text: maskedEmail,
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                    TextSpan(text: ' (${widget.userId})'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Error display
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(fontSize: 12, color: AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 6-digit OTP Input
              TextField(
                controller: _codeController,
                autofocus: true,
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
                  hintText: '000000',
                  hintStyle: TextStyle(
                    fontSize: 28,
                    letterSpacing: 10,
                    color: AppTheme.textMuted.withValues(alpha: 0.3),
                    fontFamily: 'Courier',
                  ),
                  filled: true,
                  fillColor: AppTheme.inputBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                onSubmitted: (_) => _handleVerify(),
              ),
              const SizedBox(height: 16),

              // Resend code timer row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  if (_secondsRemaining > 0)
                    Text(
                      'Resend in ${_secondsRemaining}s',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    )
                  else
                    GestureDetector(
                      onTap: _isResending ? null : _handleResend,
                      child: Text(
                        _isResending ? 'Sending...' : 'Resend Code',
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
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _handleVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text(
                              'Verify & Update',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
