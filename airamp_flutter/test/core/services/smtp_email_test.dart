import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/services/email_service.dart';

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
  });
}
