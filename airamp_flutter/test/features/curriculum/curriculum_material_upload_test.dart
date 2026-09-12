import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';
import 'package:airamp_flutter/src/features/curriculum/presentation/curriculum_content_sheet.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_repository.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/teacher_subject_detail_screen.dart';

class MockTeacherSubjectsNotifier extends TeacherSubjectsNotifier {
  final Map<int, Map<String, dynamic>> _subjectsMap;
  MockTeacherSubjectsNotifier(this._subjectsMap);

  @override
  List<Map<String, dynamic>> build() => _subjectsMap.values.toList();

  @override
  Future<Map<String, dynamic>?> getSubjectById(int id) async {
    return _subjectsMap[id];
  }
}

class MockSubjectDetailNotifier extends SubjectDetailNotifier {
  final List<Map<String, dynamic>> _mockHierarchy;
  MockSubjectDetailNotifier(this._mockHierarchy);

  @override
  List<Map<String, dynamic>> build() => _mockHierarchy;

  @override
  Future<void> loadHierarchy(int subjectId) async {
    state = _mockHierarchy;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MaterialFileInfo & Format Helpers', () {
    test('Format file sizes accurately', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(1024), '1.0 KB');
      expect(formatFileSize(1536), '1.5 KB');
      expect(formatFileSize(1024 * 1024 * 3), '3.0 MB');
    });

    test('MaterialFileInfo parses JSON correctly and ignores plain text', () {
      const plainText = 'Just standard lecture text';
      expect(MaterialFileInfo.tryParse(plainText), isNull);
      expect(MaterialFileInfo.tryParse(null), isNull);
      expect(MaterialFileInfo.tryParse(''), isNull);

      final fileMeta = MaterialFileInfo(
        isFile: true,
        fileName: 'Lesson_1_Flutter.pdf',
        fileSize: 2048500,
        fileExtension: 'pdf',
        filePath: '/storage/Lesson_1_Flutter.pdf',
        description: 'Read chapters 1 and 2',
      );

      final jsonString = jsonEncode(fileMeta.toJson());
      final parsed = MaterialFileInfo.tryParse(jsonString);

      expect(parsed, isNotNull);
      expect(parsed!.isFile, isTrue);
      expect(parsed.fileName, equals('Lesson_1_Flutter.pdf'));
      expect(parsed.fileSize, equals(2048500));
      expect(parsed.fileExtension, equals('pdf'));
      expect(parsed.filePath, equals('/storage/Lesson_1_Flutter.pdf'));
      expect(parsed.description, equals('Read chapters 1 and 2'));
    });

    test('Allowed extensions match content types', () {
      expect(allowedExtensionsFor('pdf'), contains('pdf'));
      expect(allowedExtensionsFor('ppt'), containsAll(['ppt', 'pptx']));
      expect(allowedExtensionsFor('doc'), containsAll(['doc', 'docx', 'txt']));
      expect(allowedExtensionsFor('image'), containsAll(['png', 'jpg', 'webp']));
      expect(allowedExtensionsFor('video'), containsAll(['mp4', 'mov', 'avi']));
    });
  });

  group('Teacher Mobile Subject Detail Screen - Curriculum Tab', () {
    final sampleSubject = {
      'id': 201,
      'name': 'Mobile Development with Flutter',
      'subject_code': 'MOB201',
      'description': 'Advanced mobile UI development with Riverpod.',
      'grade_level': 'Grade 11',
      'semester': '1st Semester',
      'unlock_type': 'Sequential',
      'teacher_id': 'teacher_1',
    };

    final sampleHierarchy = [
      {
        'id': 1,
        'subject_id': 201,
        'title': 'Flutter Fundamentals',
        'description': 'Widgets and UI Layouts',
        'learning_outcomes': [
          {
            'id': 10,
            'topic_id': 1,
            'title': 'Stateless & Stateful Widgets',
            'description': 'Build interactive widgets',
            'performance_criteria': '1. Creates custom widgets',
            'contents': [
              {
                'id': 100,
                'lo_id': 10,
                'title': 'Lecture Slides',
                'content_type': 'PDF',
                'content_data': jsonEncode({
                  'is_file': true,
                  'file_name': 'Week1_Widgets.pdf',
                  'file_size': 1572864,
                  'file_extension': 'pdf',
                  'description': 'Lecture presentation slides',
                }),
              },
            ],
            'questions': [],
          },
        ],
      },
    ];

    testWidgets('1. Teacher view has NO "Open in Admin View" and displays interactive curriculum', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherSubjectsProvider.overrideWith(
              () => MockTeacherSubjectsNotifier({201: sampleSubject}),
            ),
            subjectDetailProvider.overrideWith(
              () => MockSubjectDetailNotifier(sampleHierarchy),
            ),
          ],
          child: const MaterialApp(
            home: TeacherSubjectDetailScreen(subjectId: '201'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // "Open in Admin View" MUST NOT be present
      expect(find.text('Open in Admin View'), findsNothing);
      expect(find.textContaining('curated and structured by institution administrators'), findsNothing);

      // Subject info is present
      expect(find.text('Mobile Development with Flutter'), findsOneWidget);

      // Tab selector: Curriculum and My Quizzes
      expect(find.text('Curriculum'), findsOneWidget);
      expect(find.text('My Quizzes'), findsOneWidget);

      // Curriculum action bar is present
      expect(find.text('Course Curriculum'), findsOneWidget);
      expect(find.text('Add Topic'), findsOneWidget);

      // Topic 1 card is present
      expect(find.text('TOPIC 1'), findsOneWidget);
      expect(find.text('Flutter Fundamentals'), findsOneWidget);
    });

    testWidgets('2. Empty curriculum shows "Add First Topic" state without admin view button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherSubjectsProvider.overrideWith(
              () => MockTeacherSubjectsNotifier({201: sampleSubject}),
            ),
            subjectDetailProvider.overrideWith(
              () => MockSubjectDetailNotifier([]),
            ),
          ],
          child: const MaterialApp(
            home: TeacherSubjectDetailScreen(subjectId: '201'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // "Open in Admin View" MUST NOT be present
      expect(find.text('Open in Admin View'), findsNothing);

      // Empty state messaging
      expect(find.text('No Curriculum Topics Yet'), findsOneWidget);
      expect(find.text('Add First Topic'), findsOneWidget);
    });

    testWidgets('3. AddContentSheet displays file drop/upload zone when selecting file type', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subjectDetailProvider.overrideWith(
              () => MockSubjectDetailNotifier([]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AddContentSheet(loId: 10, subjectId: 201),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Modal title
      expect(find.text('Add Learning Material'), findsOneWidget);

      // Initial type is Text
      expect(find.text('Text Content / Lecture Notes'), findsOneWidget);

      // Tap PDF ChoiceChip
      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();

      // Drop & Browse file zone must appear for PDF
      expect(find.text('Upload File (PDF)'), findsOneWidget);
      expect(find.text('Drop your PDF file here'), findsOneWidget);
      expect(find.text('Browse File'), findsOneWidget);
      expect(find.text('Instructions / Notes (Optional)'), findsOneWidget);

      // Tap PPT ChoiceChip
      await tester.tap(find.text('PPT'));
      await tester.pumpAndSettle();

      expect(find.text('Upload File (PPT)'), findsOneWidget);
      expect(find.text('Drop your PPT file here'), findsOneWidget);

      // Tap Video ChoiceChip
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();

      expect(find.text('Upload File (Video)'), findsOneWidget);
      expect(find.text('Drop your Video file here'), findsOneWidget);

      // Tap YouTube ChoiceChip
      await tester.tap(find.text('YouTube'));
      await tester.pumpAndSettle();

      expect(find.text('YouTube Video Link'), findsOneWidget);
    });
  });

  group('Database Persistence of Learning Materials', () {
    test('Insert and query topic with file material metadata', () async {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final subId = await db.insert('subjects', {
        'name': 'Material Test Subject $now',
        'subject_code': 'MAT-$now',
        'description': 'Testing file uploads in curriculum',
        'unlock_type': 'Sequential',
        'semester': '1st Semester',
        'created_at': DateTime.now().toIso8601String(),
      });

      final topicId = await db.insert('topics', {
        'subject_id': subId,
        'title': 'Chapter 1: Network Protocols',
        'description': 'OSI model and TCP/IP',
        'created_at': DateTime.now().toIso8601String(),
      });

      final loId = await db.insert('learning_outcomes', {
        'topic_id': topicId,
        'title': 'LO 1.1: Describe OSI 7 Layers',
        'description': 'Understand layer functions',
        'performance_criteria': 'Identifies layer responsibilities',
        'created_at': DateTime.now().toIso8601String(),
      });

      final fileMeta = MaterialFileInfo(
        isFile: true,
        fileName: 'OSI_Reference_Guide.pdf',
        fileSize: 3145728,
        fileExtension: 'pdf',
        filePath: '/docs/OSI_Reference_Guide.pdf',
        description: 'Read section 3 before quiz',
      );

      final contentId = await db.insert('contents', {
        'lo_id': loId,
        'content_type': 'PDF',
        'title': 'OSI Model Deep Dive',
        'content_data': jsonEncode(fileMeta.toJson()),
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(contentId, greaterThan(0));

      // Query contents
      final contents = await db.query('contents', where: 'id = ?', whereArgs: [contentId]);
      expect(contents.length, equals(1));
      expect(contents.first['content_type'], equals('PDF'));
      expect(contents.first['title'], equals('OSI Model Deep Dive'));

      final parsedInfo = MaterialFileInfo.tryParse(contents.first['content_data'] as String);
      expect(parsedInfo, isNotNull);
      expect(parsedInfo!.fileName, equals('OSI_Reference_Guide.pdf'));
      expect(parsedInfo.fileSize, equals(3145728));
      expect(formatFileSize(parsedInfo.fileSize), equals('3.0 MB'));
    });
  });
}
