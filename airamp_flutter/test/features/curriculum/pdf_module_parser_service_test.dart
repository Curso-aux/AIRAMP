import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/curriculum/domain/pdf_module_parser_service.dart';

Uint8List createSamplePdf(String content) {
  final doc = PdfDocument();
  final page = doc.pages.add();
  page.graphics.drawString(
    content,
    PdfStandardFont(PdfFontFamily.helvetica, 10),
  );
  final bytes = doc.saveSync();
  doc.dispose();
  return Uint8List.fromList(bytes);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PdfModuleParserService Tests', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      // Clean test tables
      await db.delete('module_flashcards');
      await db.delete('questions');
      await db.delete('contents');
      await db.delete('learning_outcomes');
      await db.delete('topics');
      await db.delete('subjects');

      // Create test subject
      await db.insert('subjects', {
        'id': 101,
        'name': 'Mobile Application Development',
        'subject_code': 'CS301',
        'description': 'Flutter and Android architecture',
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    test('Parses Single Topic PDF with LOs, Reading Content, and Multiple-Choice Questions', () async {
      const pdfText = '''
Topic 1: Flutter Fundamentals and Widgets

Learning Outcomes:
1. Explain the reactive architecture of Flutter applications
2. Construct dynamic user interfaces using StatelessWidget and StatefulWidget

Lecture Notes:
Flutter is an open-source UI software development kit created by Google.
Widgets are the primary building blocks of every Flutter application.
StatelessWidget is an immutable widget that does not require mutable state.
StatefulWidget maintains state that might change during the widget lifetime.

Review Questions:
1. Who created the Flutter framework?
A) Microsoft
B) Google
C) Apple
D) Meta
Answer: B

2. What is the fundamental building block of a Flutter UI?
A) Database Schema
B) Activity Controller
C) Widget
D) Thread Pool
Answer: C
''';

      final pdfBytes = createSamplePdf(pdfText);
      final parser = PdfModuleParserService(dbHelper: dbHelper);

      final result = await parser.parseAndImportPdf(
        pdfBytes: pdfBytes,
        fileName: 'Topic_1_Flutter.pdf',
        subjectId: 101,
        uploadType: 'topic',
        term: 'Prelim',
      );

      expect(result.success, isTrue);
      expect(result.totalTopicsCreated, 1);
      expect(result.totalLosCreated, greaterThanOrEqualTo(2));
      expect(result.totalContentsCreated, greaterThanOrEqualTo(1));
      expect(result.totalQuestionsCreated, greaterThanOrEqualTo(2));
      expect(result.totalFlashcardsGenerated, greaterThanOrEqualTo(2));

      // Verify DB persistence
      final db = await dbHelper.database;
      final topics = await db.query('topics', where: 'subject_id = 101');
      expect(topics.length, 1);
      expect(topics.first['title'], contains('Topic 1: Flutter Fundamentals and Widgets'));

      final los = await db.query('learning_outcomes');
      expect(los.isNotEmpty, isTrue);

      final questions = await db.query('questions');
      expect(questions.length, greaterThanOrEqualTo(2));
      expect(questions.first['option_a'], isNotEmpty);
      expect(questions.first['option_b'], isNotEmpty);
      expect(questions.first['correct_option'], isNotEmpty);

      // Verify Gizmo Flashcards generated automatically!
      final flashcards = await db.query('module_flashcards');
      expect(flashcards.isNotEmpty, isTrue);
      expect(flashcards.first['front_text'], isNotEmpty);
      expect(flashcards.first['back_text'], isNotEmpty);
    });

    test('Parses Whole Module / Term-Level PDF with Multiple Topics (Prelim Module)', () async {
      const pdfText = '''
PRELIMINARY TERM COMPREHENSIVE MODULE

Topic 1: Dart Language Essentials
Learning Outcomes:
1. Understand Dart variables and null safety
2. Implement object-oriented classes in Dart
Reading Content:
Dart is a client-optimized language for fast apps on any platform.
Null safety prevents errors that result from unintentional null access.
Review Questions:
1. What language is primarily used in Flutter?
A) Kotlin
B) Swift
C) Dart
D) Rust
Answer: C

Topic 2: State Management with Riverpod
Learning Outcomes:
1. Compare local state vs global state management
2. Implement StateNotifier and Provider patterns
Reading Content:
Riverpod is a reactive caching and state management framework.
Providers are declarative ways to encapsulate business logic.
Review Questions:
1. What is Riverpod used for in Flutter?
A) Graphics rendering
B) State management and dependency injection
C) Audio playback
D) Push notification dispatching
Answer: B
''';

      final pdfBytes = createSamplePdf(pdfText);
      final parser = PdfModuleParserService(dbHelper: dbHelper);

      final result = await parser.parseAndImportPdf(
        pdfBytes: pdfBytes,
        fileName: 'Prelim_Full_Module.pdf',
        subjectId: 101,
        uploadType: 'whole_module',
        term: 'Prelim',
      );

      expect(result.success, isTrue);
      expect(result.totalTopicsCreated, 2);
      expect(result.totalLosCreated, greaterThanOrEqualTo(2));
      expect(result.totalQuestionsCreated, greaterThanOrEqualTo(2));
      expect(result.totalFlashcardsGenerated, greaterThanOrEqualTo(2));

      final db = await dbHelper.database;
      final topics = await db.query('topics', where: 'subject_id = 101');
      expect(topics.length, 2);
      expect(topics[0]['title'], contains('Topic 1'));
      expect(topics[1]['title'], contains('Topic 2'));
    });

    test('Auto-generates Quiz Practice Questions from definitions when explicit quiz is missing', () async {
      const pdfText = '''
Topic 3: Mobile Security Principles

Overview and Study Guide:
Cryptography is the practice and study of techniques for secure communication in the presence of adversarial third parties.
Hashing is a one-way mathematical function that converts arbitrary data into a fixed-length string.
Salt is random data used as an additional input to a one-way function that hashes passwords.
Encryption is the process of encoding information so that only authorized parties can access it.
''';

      final pdfBytes = createSamplePdf(pdfText);
      final parser = PdfModuleParserService(dbHelper: dbHelper);

      final result = await parser.parseAndImportPdf(
        pdfBytes: pdfBytes,
        fileName: 'Security_Notes.pdf',
        subjectId: 101,
        uploadType: 'topic',
        term: 'Midterm',
      );

      expect(result.success, isTrue);
      expect(result.totalQuestionsCreated, greaterThanOrEqualTo(2));
      expect(result.totalFlashcardsGenerated, greaterThanOrEqualTo(2));

      final db = await dbHelper.database;
      final questions = await db.query('questions');
      expect(questions.isNotEmpty, isTrue);
      // Option A, B, C, D are present
      final firstQ = questions.first;
      expect(firstQ['option_a'], isNotEmpty);
      expect(firstQ['option_b'], isNotEmpty);
      expect(firstQ['option_c'], isNotEmpty);
      expect(firstQ['option_d'], isNotEmpty);
    });

    test('createSubjectAndImportPdf creates subject in DB, populates topics, LOs, contents and Gizmo flashcards', () async {
      const pdfText = '''
Course Syllabus: Fundamentals of Business Analytics

Topic 1: Data Analytics Foundations
Learning Outcomes:
1. Identify the 4 types of analytics: descriptive, diagnostic, predictive, and prescriptive
2. Formulate business hypotheses using analytical frameworks
Reading Content:
Business analytics refers to the skills, technologies, practices for continuous iterative exploration and investigation of past business performance to gain insight and drive business planning.
Descriptive analytics answers what happened.
Predictive analytics answers what will happen.
Review Questions:
1. Which type of analytics explains what happened in the past?
A) Prescriptive
B) Descriptive
C) Predictive
D) Diagnostic
Answer: B
''';

      final pdfBytes = createSamplePdf(pdfText);
      final parser = PdfModuleParserService(dbHelper: dbHelper);

      final result = await parser.createSubjectAndImportPdf(
        pdfBytes: pdfBytes,
        fileName: 'Fundamentals_of_Business_Analytics.pdf',
        uploadType: 'whole_module',
        term: 'Prelim',
        semester: '1st Semester',
      );

      expect(result.success, isTrue);
      expect(result.createdSubjectId, isNotNull);
      expect(result.createdSubjectName, 'Fundamentals of Business Analytics');
      expect(result.totalTopicsCreated, 1);
      expect(result.totalLosCreated, greaterThanOrEqualTo(2));
      expect(result.totalContentsCreated, greaterThanOrEqualTo(1));
      expect(result.totalQuestionsCreated, greaterThanOrEqualTo(1));
      expect(result.totalFlashcardsGenerated, greaterThanOrEqualTo(1));

      // Verify the new subject is in the subjects table
      final db = await dbHelper.database;
      final subjects = await db.query(
        'subjects',
        where: 'id = ?',
        whereArgs: [result.createdSubjectId],
      );
      expect(subjects.length, 1);
      expect(subjects.first['name'], 'Fundamentals of Business Analytics');
      expect(subjects.first['semester'], '1st Semester');

      // Verify topics are attached to this new subject
      final topics = await db.query(
        'topics',
        where: 'subject_id = ?',
        whereArgs: [result.createdSubjectId],
      );
      expect(topics.length, 1);
      expect(topics.first['title'], contains('Topic 1: Data Analytics Foundations'));
    });
  });
}
