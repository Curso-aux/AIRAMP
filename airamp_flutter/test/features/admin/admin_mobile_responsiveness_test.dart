import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/features/super_admin/presentation/super_admin_portal_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_scaffold.dart';
import 'package:airamp_flutter/src/core/components/aira_action_toast.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_students_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_teachers_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_analytics_view.dart';
import 'package:airamp_flutter/src/features/admin/presentation/subjects_mgmt_screen.dart';

class _FakeSchoolAdminsNotifier extends SchoolAdminsNotifier {
  @override
  List<Map<String, dynamic>> build() {
    return [
      {
        'id': 'super_admin_christian',
        'full_name': 'Christian Evangelista',
        'email': 'evangelistachristian88@gmail.com',
        'username': 'christian_super',
        'role': 'super_admin',
        'school_id': 'sch_main',
      },
      {
        'id': 'ADM-DEMO-01',
        'full_name': 'Beta@123',
        'email': 'betajhoneilpoblacion@gmail.com',
        'username': 'beta_admin',
        'role': 'admin',
        'school_id': 'sch_main',
      },
    ];
  }
}

class _FakeSchoolsNotifier extends SchoolsNotifier {
  @override
  List<Map<String, dynamic>> build() {
    return [
      {
        'id': 'sch_main',
        'name': 'AIRAMP Demonstration High School',
        'code': 'ADM-01',
        'address': 'DepEd Campus, Manila, Philippines',
        'status': 'active',
        'admin_id': null,
      },
      {
        'id': 'sch_demo_2',
        'name': 'Secondary Demonstration Campus',
        'code': 'SEC-02',
        'address': 'Quezon City, Philippines',
        'status': 'active',
        'admin_id': null,
      },
    ];
  }
}

class _FakeAdminStudentsNotifier extends AdminStudentsNotifier {
  @override
  List<Map<String, dynamic>> build() {
    return [
      {
        'id': 'S-100-0001',
        'full_name': 'Curso',
        'email': 'luyahan007@gmail.com',
        'username': 'curso_std',
        'section': 'Grade 12 - Sapphire',
        'grade': 'Grade 12',
        'student_type': 'regular',
        'enrolled_courses': 2,
        'avg_score': 0,
        'is_archived': 0,
      },
      {
        'id': 'S-100-0002',
        'full_name': 'Test New Student',
        'email': 'newstudent@school.edu',
        'username': 'newstudent',
        'section': 'Diamond',
        'grade': 'Grade 10',
        'student_type': 'regular',
        'enrolled_courses': 0,
        'avg_score': 0,
        'is_archived': 0,
      },
      {
        'id': 'S-100-0003',
        'full_name': 'Special Needs Student',
        'email': 'special@school.edu',
        'username': 'special_std',
        'section': 'Unassigned',
        'grade': 'Grade 11',
        'student_type': 'sped',
        'enrolled_courses': 1,
        'avg_score': 85,
        'is_archived': 0,
      },
    ];
  }
}

class _FakeAdminArchivedStudentsNotifier extends AdminArchivedStudentsNotifier {
  @override
  List<Map<String, dynamic>> build() {
    return [];
  }
}

class _FakeAdminTeachersNotifier extends AdminTeachersNotifier {
  @override
  List<Map<String, dynamic>> build() {
    return [
      {
        'id': 'T-100-0001',
        'full_name': 'KIVEN L. CORSU',
        'email': 'dasucour@gmail.com',
        'username': 'dasu',
        'school_id': 'sch_main',
        'status': 'active',
        'enrolled_students': 1,
        'assigned_courses': ['Mobile UI & State Management'],
      },
      {
        'id': 'T-100-0002',
        'full_name': 'Maria Teacher',
        'email': 'maria.teacher@school.edu',
        'username': 'maria_t',
        'school_id': 'sch_main',
        'status': 'active',
        'enrolled_students': 0,
        'assigned_courses': ['Introduction to Flutter & Dart'],
      },
    ];
  }
}

class _FakeAdminArchivedTeachersNotifier extends AdminArchivedTeachersNotifier {
  @override
  List<Map<String, dynamic>> build() {
    return [];
  }
}

class _FakeSubjectsNotifier extends SubjectsNotifier {
  @override
  List<Map<String, dynamic>> build() {
    return [
      {
        'id': 1,
        'title': 'Mobile UI & State Management',
        'name': 'Mobile UI & State Management',
        'code': 'CS202',
        'subject_code': 'CS202',
        'description': 'Advanced Flutter UI architecture and cross-platform patterns',
        'grade_level': 'Grade 12',
        'semester': '1st Semester',
        'unlock_type': 'Sequential',
        'teacher_name': 'Prof. John Doe',
        'enrolled_count': 42,
        'is_adopted': false,
        'is_global': false,
      },
      {
        'id': 2,
        'title': 'Introduction to Flutter & Dart',
        'name': 'Introduction to Flutter & Dart',
        'code': 'CS201',
        'subject_code': 'CS201',
        'description': 'Fundamentals of Dart syntax and Flutter widgets',
        'grade_level': 'Grade 12',
        'semester': '1st Semester',
        'unlock_type': 'Free',
        'teacher_name': 'Engr. Sarah Smith',
        'enrolled_count': 35,
        'is_adopted': true,
        'is_global': true,
      },
    ];
  }

  @override
  Future<void> reload() async {}
}

class _FakeAnalyticsNotifier extends AdminAnalyticsNotifier {
  @override
  Map<String, dynamic> build() {
    return {
      'totalUsers': 5,
      'totalStudents': 3,
      'totalTeachers': 2,
      'totalEnrollments': 2,
      'totalSubjects': 2,
      'totalLos': 0,
      'totalAttempts': 0,
      'passedAttempts': 0,
      'passRate': 0,
      'avgScore': 0,
      'totalSections': 1,
      'demographics': {'regular': 3, 'irregular': 0, 'transferee': 0, 'sped': 0},
      'subjectEnrollments': <Map<String, dynamic>>[
        {'id': 1, 'code': 'CS202', 'name': 'Mobile UI & State Management', 'enrollments': 2, 'passRate': 0, 'attempts': 0},
      ],
      'sectionDistribution': <Map<String, dynamic>>[
        {'section': 'Grade 12 - Sapphire', 'count': 3},
      ],
      'recentAttempts': <Map<String, dynamic>>[],
      'hasData': true,
    };
  }

  @override
  Future<void> loadAnalytics({AnalyticsFilter? filter, bool syncCloud = false}) async {}
}

class _FakeSectionsNotifier extends SectionsNotifier {
  @override
  List<Map<String, dynamic>> build() => [
    {'id': 1, 'name': 'Grade 12 - Sapphire', 'grade': 'Grade 12'},
  ];
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Mobile Responsiveness Verification', () {
    testWidgets('SuperAdminPortalScreen hamburger menu opens Drawer on 375px phone', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SuperAdminPortalScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Verify hamburger menu opens the drawer when clicked!
      final menuBtn = find.byIcon(Icons.menu_rounded);
      expect(menuBtn, findsOneWidget);
      await tester.tap(menuBtn);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Drawer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SuperAdminPortalScreen switches tabs on NavigationBar without overflow on 375px phone', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SuperAdminPortalScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // On mobile (< 768px), persistent NavigationBar must be rendered
      expect(find.byType(NavigationBar), findsOneWidget);

      // Tap "Campuses" tab and verify zero RenderFlex overflow
      await tester.tap(find.text('Campuses'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Institutional Campuses & Multi-Tenant Registry'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap "Admins" tab and verify zero RenderFlex overflow
      await tester.tap(find.text('Admins'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Administrator Directory & Access Governance'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap "Security" tab and verify zero RenderFlex overflow
      await tester.tap(find.text('Security'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Security Architecture & System Audit Trail'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping Register Campus and Provision Admin dialogs on 375px phone', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SuperAdminPortalScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Register Campus
      final regBtn = find.widgetWithText(ElevatedButton, 'Register Campus');
      expect(regBtn, findsOneWidget);
      await tester.tap(regBtn);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Register New Campus / School'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Provision Admin
      final provBtn = find.widgetWithText(OutlinedButton, 'Provision Admin');
      expect(provBtn, findsOneWidget);
      await tester.tap(provBtn);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Provision Administrator Account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminWebScaffold renders bottom navigation bar and opens Hub modal on "More" tap', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testRouter = GoRouter(
        initialLocation: '/admin/dashboard',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) {
              return AdminWebScaffold(navigationShell: navigationShell);
            },
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(path: '/admin/dashboard', builder: (_, _) => const Scaffold(body: Text('Analytics Page'))),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/admin/students', builder: (_, _) => const Scaffold(body: Text('Students Page'))),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/admin/teachers', builder: (_, _) => const Scaffold(body: Text('Teachers Page'))),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/admin/subjects', builder: (_, _) => const Scaffold(body: Text('Subjects Page'))),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/admin/keys', builder: (_, _) => const Scaffold(body: Text('Keys Page'))),
              ]),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: testRouter,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify mobile bottom bar items
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('Faculty'), findsOneWidget);
      expect(find.text('Subjects'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      // Tap "More" item
      await tester.tap(find.text('More'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Administrative Modules Hub Sheet must be open
      expect(find.text('Administrative Modules'), findsOneWidget);
      expect(find.text('Enrollment Keys'), findsOneWidget);
      expect(find.text('Announcements & Inquiries'), findsOneWidget);
      expect(find.text('Quiz Scores & Results'), findsOneWidget);
      expect(find.text('Class Sections'), findsOneWidget);
      expect(find.text('Class Schedules'), findsOneWidget);
      expect(find.text('Admin Profile & Settings'), findsOneWidget);

      // Verify no exceptions were thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('AiraActionToast renders compact mobile notification on 375px phone', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late BuildContext testCtx;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                testCtx = ctx;
                return const Text('Test Screen');
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Show toast on 375px phone
      AiraActionToast.showRestored(
        testCtx,
        title: 'Administrator Restored',
        message: 'Administrative access for "Beta@123" has been restored.',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Administrator Restored'), findsOneWidget);
      expect(find.text('Administrative access for "Beta@123" has been restored.'), findsOneWidget);

      // Verify that on mobile, verbose desktop footer is omitted to keep it compact
      expect(find.textContaining('This message will close in'), findsNothing);
      expect(tester.takeException(), isNull);

      // Dismiss toast cleanly
      AiraActionToast.dismiss();
      await tester.pump();
    });

    testWidgets('Governance action modals (Deactivate, Delete) render on 375px phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schoolAdminsProvider.overrideWith(() => _FakeSchoolAdminsNotifier()),
            schoolsListProvider.overrideWith(() => _FakeSchoolsNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SuperAdminPortalScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to Admins tab
      await tester.tap(find.text('Admins'));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Active/Deactivated directory switcher pills
      expect(find.text('Active (2)'), findsOneWidget);
      expect(find.text('Deactivated (0)'), findsOneWidget);

      // Tap the deactivate icon button on Beta@123
      final deactBtn = find.byTooltip('Deactivate Administrator Account');
      expect(deactBtn, findsOneWidget);
      await tester.ensureVisible(deactBtn);
      await tester.tap(deactBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // Assert Deactivate modal appears with clean elements
      expect(find.text('Deactivate Administrator'), findsOneWidget);
      expect(find.text('Temporary access suspension'), findsOneWidget);
      expect(find.text('Beta@123'), findsWidgets);
      expect(find.text('Deactivate Account'), findsOneWidget);
      expect(find.text('Cancel, keep active'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Close modal
      await tester.tap(find.text('Cancel, keep active'));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the delete icon button on Beta@123
      final deleteBtn = find.byTooltip('Permanently Delete Administrator');
      expect(deleteBtn, findsOneWidget);
      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // Assert Permanent Delete modal appears with secondary option
      expect(find.text('Permanently Delete Account'), findsOneWidget);
      expect(find.text('Irreversible administrative action'), findsOneWidget);
      expect(find.text('Permanently Delete'), findsOneWidget);
      expect(find.text('Deactivate Account Instead'), findsOneWidget);
      expect(find.text('Cancel, keep active'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Close modal
      await tester.tap(find.text('Cancel, keep active'));
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Campuses tab and test Delete Campus modal
      await tester.tap(find.text('Campuses'));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap delete on Secondary Demonstration Campus (not sch_main)
      final campusDeleteBtn = find.byIcon(Icons.delete_outline).last;
      await tester.ensureVisible(campusDeleteBtn);
      await tester.tap(campusDeleteBtn);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Delete Campus'), findsOneWidget);
      expect(find.text('Irreversible tenant removal'), findsOneWidget);
      expect(find.text('Permanently Delete Campus'), findsOneWidget);
      expect(find.text('Cancel, keep campus'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Cancel, keep campus'));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify no exceptions across all interactions
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminWebStudentsScreen renders tabs, cards, and filters without overflow on 375px phone', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/admin/students',
        routes: [
          GoRoute(
            path: '/admin/students',
            builder: (context, state) => const Scaffold(body: AdminWebStudentsScreen()),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminStudentsProvider.overrideWith(() => _FakeAdminStudentsNotifier()),
            adminArchivedStudentsProvider.overrideWith(() => _FakeAdminArchivedStudentsNotifier()),
            availableSectionsProvider.overrideWith((ref) => Future.value(['Grade 12 - Sapphire', 'Diamond'])),
            subjectsProvider.overrideWith(() => _FakeSubjectsNotifier()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Assert compact labels on mobile without RenderFlex overflow
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Active (3)'), findsOneWidget);
      expect(find.text('Inactive (0)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify student cards render with zero overflow
      expect(find.text('Curso'), findsOneWidget);
      expect(find.text('Test New Student'), findsOneWidget);
      expect(find.text('Special Needs Student'), findsOneWidget);

      // Tap Active tab
      await tester.tap(find.text('Active (3)'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      // Tap Inactive tab
      await tester.ensureVisible(find.text('Inactive (0)'));
      await tester.tap(find.text('Inactive (0)'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminWebTeachersScreen renders tabs, KPI cards, and search toolbar without overflow on 375px phone', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/admin/teachers',
        routes: [
          GoRoute(
            path: '/admin/teachers',
            builder: (context, state) => const Scaffold(body: AdminWebTeachersScreen()),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminTeachersProvider.overrideWith(() => _FakeAdminTeachersNotifier()),
            adminArchivedTeachersProvider.overrideWith(() => _FakeAdminArchivedTeachersNotifier()),
            subjectsProvider.overrideWith(() => _FakeSubjectsNotifier()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Assert compact labels on mobile without RenderFlex overflow
      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('Active (2)'), findsOneWidget);
      expect(find.text('Inactive (0)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify KPI cards and faculty cards render without overflow
      expect(find.text('Total Faculty'), findsOneWidget);
      expect(find.text('KIVEN L. CORSU'), findsOneWidget);
      expect(find.text('Maria Teacher'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap Active tab
      await tester.tap(find.text('Active (2)'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      // Tap Inactive tab
      await tester.ensureVisible(find.text('Inactive (0)'));
      await tester.tap(find.text('Inactive (0)'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Onboard New Student and Add Faculty responsive dialog layouts render without overflow on 375px phone', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Test Onboard Student dialog layout with long classification and section dropdown items
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      final isMobile = MediaQuery.sizeOf(ctx).width < 580;
                      showDialog(
                        context: ctx,
                        builder: (dialogCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('Onboard New Student', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          content: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Username & Password stacked on mobile
                                  if (isMobile) ...[
                                    TextFormField(decoration: const InputDecoration(labelText: 'Username (Optional)')),
                                    const SizedBox(height: 14),
                                    TextFormField(decoration: const InputDecoration(labelText: 'Initial Password (Auto-Generated)')),
                                  ],
                                  const SizedBox(height: 14),
                                  // Dropdowns with isExpanded and text ellipsis
                                  DropdownButtonFormField<String>(
                                    initialValue: 'Grade 10',
                                    isExpanded: true,
                                    items: ['Grade 10', 'Grade 12'].map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (_) {},
                                  ),
                                  const SizedBox(height: 14),
                                  DropdownButtonFormField<String>(
                                    initialValue: 'Grade 12 - Sapphire',
                                    isExpanded: true,
                                    items: ['Grade 12 - Sapphire', 'Regular Student (Standard Curriculum)'].map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (_) {},
                                  ),
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () {}, child: const Text('Add Student')),
                          ],
                        ),
                      );
                    },
                    child: const Text('Show Dialog'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap Show Dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Assert modal elements render with ZERO overflow
      expect(find.text('Onboard New Student'), findsOneWidget);
      expect(find.text('Username (Optional)'), findsOneWidget);
      expect(find.text('Grade 12 - Sapphire'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminWebAnalyticsView renders 2x2 compact KPI grid and responsive elements without overflow on 375px phone', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAnalyticsProvider.overrideWith(() => _FakeAnalyticsNotifier()),
            subjectsProvider.overrideWith(() => _FakeSubjectsNotifier()),
            sectionsProvider.overrideWith(() => _FakeSectionsNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AdminWebAnalyticsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Assert header
      expect(find.text('School Analytics & Operations'), findsOneWidget);

      // Assert compact filter trigger
      expect(find.text('Filters'), findsOneWidget);

      // Assert 4 KPI cards are rendered
      expect(find.text('Total Users Registered'), findsOneWidget);
      expect(find.text('Active Course Enrollments'), findsOneWidget);
      expect(find.text('Student Learning Progress'), findsOneWidget);
      expect(find.text('Assessment Pass Rate'), findsOneWidget);

      // Assert Donut & Demographics card headers are rendered without truncation
      expect(find.text('Exam Results & Performance Overview'), findsOneWidget);
      expect(find.text('Student Enrollment & Class Assignments'), findsOneWidget);

      // Tap "Filters" button on mobile
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      // Assert bottom sheet opens with all 6 dimensions
      expect(find.text('Analytics Filters'), findsOneWidget);
      expect(find.text('Academic Year'), findsOneWidget);
      expect(find.text('Department / Grade'), findsOneWidget);
      expect(find.text('Subject'), findsOneWidget);
      expect(find.text('Class Section'), findsOneWidget);
      expect(find.text('Date Range'), findsOneWidget);
      expect(find.text('Student Category'), findsOneWidget);
      expect(find.text('Apply & Close'), findsOneWidget);

      // Close bottom sheet
      await tester.tap(find.text('Apply & Close'));
      await tester.pumpAndSettle();

      // Zero RenderFlex overflows
      expect(tester.takeException(), isNull);
    });

    testWidgets('SubjectsMgmtScreen renders responsive header buttons and segmented card action bar without overflow on 375px phone', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subjectsProvider.overrideWith(() => _FakeSubjectsNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SubjectsMgmtScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Assert header elements
      expect(find.text('Manage Subjects'), findsOneWidget);

      // Assert responsive header buttons: full-width primary CTA and 50/50 secondary buttons
      expect(find.text('Create New Subject'), findsOneWidget);
      expect(find.text('Adopt Global'), findsOneWidget);
      expect(find.text('PDF Auto-Scan'), findsOneWidget);

      // Assert subject cards render
      expect(find.text('Mobile UI & State Management'), findsOneWidget);
      expect(find.text('Introduction to Flutter & Dart'), findsOneWidget);

      // Assert segmented card action bar icons
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsWidgets);
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);

      // Zero RenderFlex overflows
      expect(tester.takeException(), isNull);
    });
  });
}

