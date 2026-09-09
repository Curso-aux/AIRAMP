import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/components/post_announcement_dialog.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Teacher Announcements & Handled Section Filtering Tests', () {
    test('1. Database schema v18 contains announcement section and author metadata columns', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;

      final columns = await db.rawQuery('PRAGMA table_info(announcements)');
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      expect(columnNames.contains('id'), isTrue);
      expect(columnNames.contains('title'), isTrue);
      expect(columnNames.contains('message'), isTrue);
      expect(columnNames.contains('priority'), isTrue);
      expect(columnNames.contains('target_audience'), isTrue);
      expect(columnNames.contains('section'), isTrue, reason: 'section column must exist');
      expect(columnNames.contains('author_id'), isTrue, reason: 'author_id column must exist');
      expect(columnNames.contains('author_name'), isTrue, reason: 'author_name column must exist');
      expect(columnNames.contains('author_role'), isTrue, reason: 'author_role column must exist');
      expect(columnNames.contains('created_at'), isTrue);
    });

    test('2. Teacher can retrieve handled sections list', () async {
      final helper = DatabaseHelper();
      final sections = await helper.getSectionsForTeacher('teacher_1');

      expect(sections, isA<List<String>>());
      expect(sections.isNotEmpty, isTrue);
      expect(sections.any((s) => s.contains('Emerald')), isTrue);
    });

    test('3. Teacher can create announcement targeted to a specific section (Emerald)', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;

      final insertId = await db.insert('announcements', {
        'title': 'Robotics Lab Equipment Check',
        'message': 'Please bring your USB flash drives and lab notebooks tomorrow.',
        'priority': 'high',
        'target_audience': 'students',
        'section': 'Emerald',
        'author_id': 'teacher_1',
        'author_name': 'Sir John Reyes',
        'author_role': 'teacher',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(insertId, isPositive);

      final row = await db.query('announcements', where: 'id = ?', whereArgs: [insertId]);
      expect(row.length, equals(1));
      expect(row.first['section'], equals('Emerald'));
      expect(row.first['author_id'], equals('teacher_1'));
      expect(row.first['author_name'], equals('Sir John Reyes'));
      expect(row.first['priority'], equals('high'));
    });

    test('4. Teacher can create announcement targeted to All Handled Sections', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;

      final insertId = await db.insert('announcements', {
        'title': 'Midterm Exam Schedule Notification',
        'message': 'Midterm assessments for all my handled sections will commence next Monday.',
        'priority': 'medium',
        'target_audience': 'students',
        'section': 'All Handled Sections',
        'author_id': 'teacher_1',
        'author_name': 'Sir John Reyes',
        'author_role': 'teacher',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(insertId, isPositive);

      final row = await db.query('announcements', where: 'id = ?', whereArgs: [insertId]);
      expect(row.length, equals(1));
      expect(row.first['section'], equals('All Handled Sections'));
      expect(row.first['author_id'], equals('teacher_1'));
    });

    test('5. Teacher announcements filtering returns section-specific items', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;

      // Add a distinct announcement for a different section (Ruby)
      await db.insert('announcements', {
        'title': 'Ruby Exclusive Section Notice',
        'message': 'Only Ruby students need to attend the special Friday lecture.',
        'priority': 'normal',
        'target_audience': 'students',
        'section': 'Ruby',
        'author_id': 'teacher_1',
        'author_name': 'Sir John Reyes',
        'author_role': 'teacher',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Query with section filter = 'Emerald'
      final emeraldAnnouncements = await helper.getAnnouncementsForTeacher('teacher_1', section: 'Emerald');
      expect(emeraldAnnouncements.any((a) => a['title'] == 'Robotics Lab Equipment Check'), isTrue);
      expect(emeraldAnnouncements.any((a) => a['title'] == 'Ruby Exclusive Section Notice'), isFalse);

      // Query with section filter = 'Ruby'
      final rubyAnnouncements = await helper.getAnnouncementsForTeacher('teacher_1', section: 'Ruby');
      expect(rubyAnnouncements.any((a) => a['title'] == 'Ruby Exclusive Section Notice'), isTrue);
      expect(rubyAnnouncements.any((a) => a['title'] == 'Robotics Lab Equipment Check'), isFalse);

      // Query with section filter = 'All Handled Sections'
      final allAnnouncements = await helper.getAnnouncementsForTeacher('teacher_1', section: 'All Handled Sections');
      expect(allAnnouncements.any((a) => a['title'] == 'Robotics Lab Equipment Check'), isTrue);
      expect(allAnnouncements.any((a) => a['title'] == 'Ruby Exclusive Section Notice'), isTrue);
      expect(allAnnouncements.any((a) => a['title'] == 'Midterm Exam Schedule Notification'), isTrue);
    });

    test('6. Student section-aware filtering delivers only relevant announcements', () async {
      final helper = DatabaseHelper();

      // Student in Emerald
      final emeraldStudentAnnouncements = await helper.getAnnouncementsForStudent('Emerald');
      expect(emeraldStudentAnnouncements.any((a) => a['title'] == 'Robotics Lab Equipment Check'), isTrue);
      expect(emeraldStudentAnnouncements.any((a) => a['title'] == 'Midterm Exam Schedule Notification'), isTrue);
      // Must NOT see Ruby's exclusive announcement
      expect(emeraldStudentAnnouncements.any((a) => a['title'] == 'Ruby Exclusive Section Notice'), isFalse);

      // Student in Ruby
      final rubyStudentAnnouncements = await helper.getAnnouncementsForStudent('Ruby');
      expect(rubyStudentAnnouncements.any((a) => a['title'] == 'Ruby Exclusive Section Notice'), isTrue);
      expect(rubyStudentAnnouncements.any((a) => a['title'] == 'Midterm Exam Schedule Notification'), isTrue);
      // Must NOT see Emerald's announcement
      expect(rubyStudentAnnouncements.any((a) => a['title'] == 'Robotics Lab Equipment Check'), isFalse);
    });

    test('7. Teacher can update and delete their own announcement', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;

      final insertId = await db.insert('announcements', {
        'title': 'Draft Announcement',
        'message': 'Initial draft message.',
        'priority': 'normal',
        'target_audience': 'students',
        'section': 'Emerald',
        'author_id': 'teacher_1',
        'author_name': 'Sir John Reyes',
        'author_role': 'teacher',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update
      await db.update(
        'announcements',
        {'title': 'Updated Draft Announcement', 'priority': 'high'},
        where: 'id = ?',
        whereArgs: [insertId],
      );

      var row = await db.query('announcements', where: 'id = ?', whereArgs: [insertId]);
      expect(row.first['title'], equals('Updated Draft Announcement'));
      expect(row.first['priority'], equals('high'));

      // Delete
      final deletedCount = await db.delete('announcements', where: 'id = ?', whereArgs: [insertId]);
      expect(deletedCount, equals(1));

      row = await db.query('announcements', where: 'id = ?', whereArgs: [insertId]);
      expect(row.isEmpty, isTrue);
    });

    testWidgets('8. PostAnnouncementDialog renders cleanly without errors', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => PostAnnouncementDialog.show(context, defaultSection: 'Emerald'),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Post Announcement'), findsOneWidget);
      expect(find.text('Publish Announcement'), findsOneWidget);
    });
  });
}
