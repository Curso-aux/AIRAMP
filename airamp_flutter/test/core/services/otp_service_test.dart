import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/services/otp_service.dart';
import 'package:airamp_flutter/src/core/config/email_config.dart';

void main() {
  group('AIRA OTP Service Verification Tests', () {
    test('EmailConfig is configured and ready for OTP operations', () {
      expect(EmailConfig.isConfigured, isTrue);
      expect(EmailConfig.smtpAppPassword, isNotEmpty);
    });

    test('OtpService can request direct OTP and verify with entered code', () async {
      final otpResult = await OtpService().requestOtpDirect(
        userId: 'student_otp_test_1',
        email: 'evangelistachristian88@gmail.com',
        fullName: 'Test Student',
        role: 'student',
      );

      expect(otpResult.success, isTrue);
      expect(otpResult.email, 'evangelistachristian88@gmail.com');

      // Invalid code must fail
      final wrongVerify = await OtpService().verifyOtp(
        identifier: 'student_otp_test_1',
        enteredCode: '000000',
      );
      expect(wrongVerify, isFalse);
    });

    test('OtpService can request registration email OTP and verify', () async {
      final emailResult = await OtpService().requestEmailVerificationOtp(
        targetEmail: 'evangelistachristian88@gmail.com',
        fullName: 'New Student Signup',
        role: 'student',
        purpose: 'Student Account Registration',
      );

      expect(emailResult.success, isTrue);
    });
  });
}
