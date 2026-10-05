import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/services/email_service.dart';
import 'package:airamp_flutter/src/core/config/email_config.dart';

void main() {
  group('AIRA SMTP Email Delivery Service Tests', () {
    test('EmailService can send Student account credentials via Gmail SMTP', () async {
      final result = await EmailService().sendAccountCredentials(
        toEmail: 'evangelistachristian88@gmail.com',
        fullName: 'Juan Dela Cruz',
        userId: 'student_test_smtp_1',
        username: 'juan.delacruz',
        plainPassword: 'Student@123',
        role: 'student',
        grade: 'Grade 10',
        section: 'Diamond',
      );

      expect(result.success, isTrue);
      expect(result.message, contains('evangelistachristian88@gmail.com'));
    });

    test('EmailService can send Faculty / Teacher account credentials via Gmail SMTP', () async {
      final result = await EmailService().sendAccountCredentials(
        toEmail: 'evangelistachristian88@gmail.com',
        fullName: 'Prof. Maria Clara Santos',
        userId: 'teacher_test_smtp_1',
        username: 'prof.santos',
        plainPassword: 'Teacher@123',
        role: 'teacher',
        assignedCourses: ['Mathematics 10', 'Physics 1'],
      );

      expect(result.success, isTrue);
      expect(result.message, contains('evangelistachristian88@gmail.com'));
    });
    test('EmailConfig is configured with default app password when env var not passed', () {
      expect(EmailConfig.isConfigured, isTrue);
      expect(EmailConfig.smtpAppPassword, isNotEmpty);
      expect(EmailConfig.senderEmail, 'evangelistachristian88@gmail.com');
    });

    test('EmailService can send Password Reset OTP via Gmail SMTP', () async {
      final result = await EmailService().sendPasswordResetOtp(
        toEmail: 'evangelistachristian88@gmail.com',
        fullName: 'King Khevin L. Curso',
        userId: 'student_1791021791263',
        otpCode: '852963',
        role: 'student',
      );

      expect(result.success, isTrue);
      expect(result.message, contains('evangelistachristian88@gmail.com'));
    });

    test('EmailService can send Account Registration Verification OTP via Gmail SMTP', () async {
      final result = await EmailService().sendVerificationOtp(
        toEmail: 'evangelistachristian88@gmail.com',
        fullName: 'New Student Test',
        otpCode: '741258',
        purpose: 'Student Account Registration',
        role: 'student',
      );

      expect(result.success, isTrue);
      expect(result.message, contains('evangelistachristian88@gmail.com'));
    });
  });
}
