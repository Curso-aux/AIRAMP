import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_analytics_view.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_students_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_keys_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_announcements_screen.dart';
import 'package:airamp_flutter/src/features/landing/presentation/web_landing_screen.dart';
import 'package:airamp_flutter/src/features/auth/presentation/web/admin_web_login_screen.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';

class _MockAdminKeysNotifier extends AdminKeysNotifier {
  @override
  List<Map<String, dynamic>> build() => [
    {
      'code': 'SEC-EMR10',
      'section': 'Grade 10 - Emerald',
      'max_uses': 50,
      'times_used': 2,
      'created_at': '2026-09-12 10:00:00',
    }
  ];

  @override
  Future<void> loadKeys() async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper Admin Web Operations', () {
    test('getAdminAnalyticsSummary returns institutional metrics map', () async {
      final db = DatabaseHelper();
      final summary = await db.getAdminAnalyticsSummary();

      expect(summary.containsKey('totalUsers'), isTrue);
      expect(summary.containsKey('totalStudents'), isTrue);
      expect(summary.containsKey('totalTeachers'), isTrue);
      expect(summary.containsKey('totalAdmins'), isTrue);
      expect(summary.containsKey('totalEnrollments'), isTrue);
      expect(summary.containsKey('subjectEnrollments'), isTrue);
      expect(summary.containsKey('sectionDistribution'), isTrue);
      expect(summary.containsKey('passRate'), isTrue);
      expect(summary.containsKey('recentAttempts'), isTrue);
    });

    test('Enrollment keys management: generate, list, delete', () async {
      final db = DatabaseHelper();
      final testCode = 'TEST-KEY-${DateTime.now().millisecondsSinceEpoch}';

      await db.generateEnrollmentKey(
        code: testCode,
        section: 'Section Alpha',
        maxUses: 25,
      );

      final keys = await db.getEnrollmentKeysList();
      final found = keys.any((k) => k['code'] == testCode);
      expect(found, isTrue);

      await db.deleteEnrollmentKey(testCode);

      final keysAfter = await db.getEnrollmentKeysList();
      final foundAfter = keysAfter.any((k) => k['code'] == testCode);
      expect(foundAfter, isFalse);
    });

    test('getAdminStudentsList and updateStudentSection', () async {
      final db = DatabaseHelper();
      final students = await db.getAdminStudentsList();
      expect(students, isA<List<Map<String, dynamic>>>());

      if (students.isNotEmpty) {
        final first = students.first;
        final studentId = first['id'].toString();

        await db.updateStudentSection(
          studentId,
          'Stem 12-A',
          grade: 'Grade 12',
        );

        final filtered = await db.getAdminStudentsList(section: 'Stem 12-A');
        expect(filtered.any((s) => s['id'].toString() == studentId), isTrue);
      }
    });
  });

  group('Admin Web Views Smoke & Responsiveness Tests', () {
    testWidgets('AdminWebAnalyticsView renders KPI cards in dark theme', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: AdminWebAnalyticsView()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('School Analytics & Operations'), findsOneWidget);
      expect(find.text('Total Users Registered'), findsOneWidget);
      expect(find.text('Active Course Enrollments'), findsOneWidget);
      expect(find.text('Subject Enrollment Popularity'), findsOneWidget);
    });

    testWidgets('AdminWebAnalyticsView renders in light theme (Responsive Mobile 400x800)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAnalyticsProvider.overrideWith(() => _TestAnalyticsNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: AdminWebAnalyticsView()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('School Analytics & Operations'), findsOneWidget);
    });

    testWidgets('AdminWebStudentsScreen renders directory and filter controls', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableSectionsProvider.overrideWith((ref) => ['STEM A', 'Emerald', 'Ruby', 'Diamond']),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: AdminWebStudentsScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.text('Student Management & Section Arrangement'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // Search bar
    });

    testWidgets('AdminWebKeysScreen renders access key generation', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableSectionsProvider.overrideWith((ref) => ['STEM A', 'Emerald', 'Ruby', 'Diamond']),
            adminKeysProvider.overrideWith(() => _MockAdminKeysNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: AdminWebKeysScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Enrollment Keys & Access Codes'), findsOneWidget);
      expect(find.text('Manage Class Sections'), findsOneWidget);
      expect(find.text('Grade 10'), findsWidgets);
    });

    testWidgets('AdminWebAnnouncementsScreen renders broadcast hub and compose button', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: AdminWebAnnouncementsScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Announcements & Broadcasts'), findsOneWidget);
      expect(find.text('Post Announcement'), findsOneWidget);

      // Verify Edit icon appears for announcements
      final editButtons = find.byTooltip('Edit Announcement');
      if (editButtons.evaluate().isNotEmpty) {
        await tester.tap(editButtons.first);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Edit Announcement'), findsOneWidget);
        expect(find.text('Save Changes'), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('Cancel'));
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('WebLandingScreen renders hero, ecosystem cards, and restriction notice', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: WebLandingScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('AIRAMP Role Ecosystem'), findsOneWidget);
      expect(find.text('Admin Web Console'), findsOneWidget);
      expect(find.text('Teacher App'), findsOneWidget);
      expect(find.text('Student App'), findsOneWidget);
      expect(find.text('Web Access Restriction Notice'), findsOneWidget);
    });

    testWidgets('AdminWebLoginScreen renders administrative console sign-in form', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AdminWebLoginScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('AIRA Admin Console'), findsOneWidget);
      expect(find.text('Sign In to Web Admin'), findsOneWidget);
      expect(find.text('Return to AIRA Home Page'), findsOneWidget);
    });
  });

  group('Role Authorization Seeding Tests', () {
    test('teacher and admin roles are strictly separated in database', () async {
      final db = DatabaseHelper();
      final database = await db.database;
      final users = await database.query('users');

      final teacher = users.firstWhere(
        (u) => u['email'] == 'john.reyes@deped.gov.ph',
        orElse: () => {},
      );
      if (teacher.isNotEmpty) {
        expect(teacher['role'], equals('teacher'));
      }

      final admin = users.firstWhere(
        (u) => u['email'] == 'aira@admin',
        orElse: () => {},
      );
      expect(admin['role'], equals('super_admin'));
    });

    test('sections table persists room field and handles CRUD operations', () async {
      final db = DatabaseHelper();
      final sectionId = await db.insertSection({
        'name': 'Grade 12 - ICT Polaris',
        'description': 'Senior High ICT class',
        'grade': 'Grade 12',
        'room': 'Lab 402, IT Wing',
        'student_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(sectionId, isPositive);

      final sections = await db.getSectionsList();
      final created = sections.firstWhere((s) => s['id'] == sectionId);
      expect(created['room'], equals('Lab 402, IT Wing'));
      expect(created['name'], equals('Grade 12 - ICT Polaris'));

      // Update room
      await db.updateSection(sectionId, {
        'room': 'Lab 501, IT Complex',
      });

      final updatedSections = await db.getSectionsList();
      final updated = updatedSections.firstWhere((s) => s['id'] == sectionId);
      expect(updated['room'], equals('Lab 501, IT Complex'));

      // Delete
      await db.deleteSection(sectionId);
      final remaining = await db.getSectionsList();
      expect(remaining.any((s) => s['id'] == sectionId), isFalse);
    });

    test('subjects table persists assigned teacher and supports teacher-specific queries', () async {
      final db = DatabaseHelper();
      final database = await db.database;

      final subjectId = await database.insert('subjects', {
        'name': 'Robotics & Automation',
        'subject_code': 'ROBO-101',
        'description': 'Advanced robotics module',
        'grade_level': 'Grade 12',
        'semester': '1st Semester',
        'unlock_type': 'Sequential',
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(subjectId, isPositive);

      final teacherSubjects = await db.getSubjectsForTeacher('teacher_1');
      expect(teacherSubjects.any((s) => s['id'] == subjectId), isTrue);

      // Reassign teacher
      await db.assignTeacherToSubject(subjectId, 'teacher_2', 'Ma\'am Maria Santos');
      final reassigned = await db.getSubjectsForTeacher('teacher_2');
      expect(reassigned.any((s) => s['id'] == subjectId), isTrue);

      // Cleanup
      await database.delete('subjects', where: 'id = ?', whereArgs: [subjectId]);
    });
  });
}

class _TestAnalyticsNotifier extends AdminAnalyticsNotifier {
  @override
  Map<String, dynamic> build() {
    return {
      'totalUsers': 12,
      'totalStudents': 8,
      'totalTeachers': 3,
      'totalAdmins': 1,
      'totalEnrollments': 15,
      'totalSubjects': 4,
      'totalTopics': 8,
      'totalLos': 20,
      'totalAttempts': 10,
      'passedAttempts': 8,
      'passRate': 80,
      'avgScore': 85,
      'subjectEnrollments': <Map<String, dynamic>>[],
      'sectionDistribution': <Map<String, dynamic>>[],
      'recentAnnouncements': <Map<String, dynamic>>[],
      'recentAttempts': <Map<String, dynamic>>[],
    };
  }
}
