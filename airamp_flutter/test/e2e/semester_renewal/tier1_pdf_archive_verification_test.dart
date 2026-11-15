// Tier 1 E2E Test Suite: PDF Record Archiving & Binary Verification
// Tests: Student data query, Syncfusion PDF compilation, %PDF- magic bytes, checksum, corruption handling.

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'harness/academic_term_fixture.dart';
import 'harness/semester_renewal_test_harness.dart';

void main() {
  late SemesterRenewalTestHarness harness;
  late AcademicTermFixture fixture;

  setUp(() async {
    harness = await SemesterRenewalTestHarness.initialize();
    fixture = AcademicTermFixture();
    await harness.seedAcademicTerm(fixture);
  });

  tearDown(() async {
    await harness.dispose();
  });

  group('Tier 1: PDF Record Archiving & Binary Verification', () {
    test('1. Querying student records retrieves complete profiles, sections, grades, and achievements', () async {
      final records = await harness.service.fetchAllStudentRecords();

      // Expect exactly 2 students from fixture
      expect(records.length, equals(2));

      // Assert Student 1 details
      final student1 = records.firstWhere((s) => s.studentId == 'S-100-0001');
      expect(student1.fullName, equals('Juan Dela Cruz'));
      expect(student1.section, equals('10-Rizal'));
      expect(student1.gradeLevel, equals('Grade 10'));
      expect(student1.studentType, equals('regular'));

      // Check grades across Math and English
      expect(student1.grades.length, equals(2));
      final mathGrade = student1.grades.firstWhere((g) => g.subjectId == 'SUBJ-MATH10');
      expect(mathGrade.subjectName, equals('Mathematics 10'));
      expect(mathGrade.quizAverage, isNotNull);
      expect(mathGrade.quizAverage!, greaterThanOrEqualTo(90.0));
      expect(mathGrade.assignmentAverage, isNotNull);
      expect(mathGrade.finalGrade, isNotNull);

      // Check achievements
      expect(student1.achievements.totalQuizzesCompleted, greaterThanOrEqualTo(2));
      expect(student1.achievements.totalAssignmentsSubmitted, greaterThanOrEqualTo(1));
      expect(student1.achievements.gpa, greaterThan(85.0));

      // Assert Student 2 details
      final student2 = records.firstWhere((s) => s.studentId == 'S-100-0002');
      expect(student2.fullName, equals('Maria Clara'));
      expect(student2.section, equals('10-Bonifacio'));
      expect(student2.grades.length, equals(1));
    });

    test('2. PDF compilation generates valid document using syncfusion_flutter_pdf with non-zero bytes', () async {
      final records = await harness.service.fetchAllStudentRecords();
      final pdfBytes = await harness.service.generatePdfArchive(records);

      // Validate byte array properties
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.lengthInBytes, greaterThan(500),
          reason: 'Compiled PDF with 2 student pages should comfortably exceed 500 bytes');

      // Verify header magic bytes (%PDF-)
      expect(pdfBytes[0], equals(0x25)); // '%'
      expect(pdfBytes[1], equals(0x50)); // 'P'
      expect(pdfBytes[2], equals(0x44)); // 'D'
      expect(pdfBytes[3], equals(0x46)); // 'F'
      expect(pdfBytes[4], equals(0x2D)); // '-'
    });

    test('3. Binary verification validates header magic bytes, page count, and SHA-256 checksum', () async {
      final records = await harness.service.fetchAllStudentRecords();
      final pdfBytes = await harness.service.generatePdfArchive(records);

      final result = harness.service.verifyPdfArchive(pdfBytes, records.length);

      // Verification assertions
      expect(result.isValid, isTrue);
      expect(result.studentCount, equals(2));
      expect(result.pageCount, equals(2));
      expect(result.byteLength, equals(pdfBytes.lengthInBytes));
      expect(result.checksum, isNotEmpty);
      expect(result.checksum.length, equals(64), reason: 'SHA-256 hex string must be 64 characters');
      expect(result.errorMessage, isNull);
    });

    test('4. Corrupted header bytes trigger verification failure and descriptive error', () {
      // Craft corrupted buffer: replace %PDF- with invalid bytes
      final corruptBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]);
      final result = harness.service.verifyPdfArchive(corruptBytes, 2);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('%PDF-'));
    });

    test('5. Empty or truncated buffer is rejected with zero-byte length error', () {
      final emptyBytes = Uint8List(0);
      final result = harness.service.verifyPdfArchive(emptyBytes, 2);

      expect(result.isValid, isFalse);
      expect(result.byteLength, equals(0));
      expect(result.errorMessage, contains('empty'));
    });

    test('6. Incomplete archive with fewer pages than expected students fails verification', () async {
      // Generate archive for only 1 student while expecting 2
      final records = await harness.service.fetchAllStudentRecords();
      final singleStudentRecord = [records.first];
      final pdfBytes = await harness.service.generatePdfArchive(singleStudentRecord);

      // Verify expecting 2 students, but PDF contains only 1 page
      final result = harness.service.verifyPdfArchive(pdfBytes, 2);

      expect(result.isValid, isFalse);
      expect(result.pageCount, equals(1));
      expect(result.errorMessage, contains('less than expected student count'));
    });
  });
}
