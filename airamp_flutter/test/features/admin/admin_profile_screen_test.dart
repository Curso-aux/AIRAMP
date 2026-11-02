import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/features/admin/presentation/admin_profile_screen.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';

class _MockAuthNotifier extends AuthNotifier {
  final User? _user;
  _MockAuthNotifier(this._user);

  @override
  User? build() => _user;
}

class _FakeAnalyticsNotifier extends AdminAnalyticsNotifier {
  @override
  Map<String, dynamic> build() {
    return {
      'totalStudents': 119,
      'totalTeachers': 12,
      'totalEnrollments': 5,
      'passRate': 100,
    };
  }

  @override
  Future<void> loadAnalytics({AnalyticsFilter? filter, bool syncCloud = false}) async {}
}

class _FakeStudentsNotifier extends AdminStudentsNotifier {
  @override
  List<Map<String, dynamic>> build() => [
        {'id': 'student_1', 'full_name': 'Test Student'},
      ];
}

class _FakeTeachersNotifier extends AdminTeachersNotifier {
  @override
  List<Map<String, dynamic>> build() => [
        {'id': 'teacher_1', 'full_name': 'Test Teacher'},
      ];
}

class _FakeSectionsNotifier extends SectionsNotifier {
  @override
  List<Map<String, dynamic>> build() => [
        {'name': 'Emerald'},
        {'name': 'Ruby'},
      ];
}

class _FakeKeysNotifier extends AdminKeysNotifier {
  @override
  List<Map<String, dynamic>> build() => [
        {'key': 'KEY-1234'},
      ];
}

class _FakeSubjectsNotifier extends SubjectsNotifier {
  @override
  List<Map<String, dynamic>> build() => [
        {'name': 'Science 10'},
      ];
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('AdminProfileScreen renders 2-column desktop layout matching Teacher profile', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testUser = User(
      id: 'admin_test_1',
      username: 'admin',
      fullName: 'School Administrator',
      email: 'admin@aira.edu',
      role: 'super_admin',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier(testUser)),
          adminAnalyticsProvider.overrideWith(() => _FakeAnalyticsNotifier()),
          adminStudentsProvider.overrideWith(() => _FakeStudentsNotifier()),
          adminTeachersProvider.overrideWith(() => _FakeTeachersNotifier()),
          sectionsProvider.overrideWith(() => _FakeSectionsNotifier()),
          adminKeysProvider.overrideWith(() => _FakeKeysNotifier()),
          subjectsProvider.overrideWith(() => _FakeSubjectsNotifier()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdminProfileScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    // Verify Header Bar
    expect(find.text('Back to Dashboard'), findsOneWidget);
    expect(find.text('Admin Profile & Settings'), findsOneWidget);
    expect(find.text('SUPER ADMINISTRATOR'), findsOneWidget);

    // Verify Hero Card & 4 Operational KPIs
    expect(find.text('School Administrator'), findsWidgets);
    expect(find.text('@admin'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Faculty'), findsOneWidget);
    expect(find.text('Sections'), findsOneWidget);
    expect(find.text('Keys'), findsOneWidget);

    // Verify Governance Modules & Cloud Sync
    expect(find.text('Institutional Governance & Modules'), findsOneWidget);
    expect(find.text('Student Directory'), findsOneWidget);
    expect(find.text('Cloud Synced & Operations Online'), findsOneWidget);
    expect(find.text('Sync Now'), findsOneWidget);

    // Verify Personal Info card
    expect(find.text('Personal & Institutional Info'), findsOneWidget);
    expect(find.text('admin@aira.edu'), findsOneWidget);

    // Verify Console Preferences (Theme Switcher)
    expect(find.text('Console Preferences'), findsOneWidget);
    expect(find.text('Light Mode'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);

    // Verify Sign Out button
    expect(find.text('Sign Out'), findsOneWidget);
  });
}
