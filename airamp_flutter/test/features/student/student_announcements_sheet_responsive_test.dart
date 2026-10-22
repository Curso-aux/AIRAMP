import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/student/presentation/components/student_announcements_sheet.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('showStudentAnnouncementsSheet does not overflow on small device screens (320px width)',
      (WidgetTester tester) async {
    // Small device screen: 320x640 (iPhone SE / compact Android)
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testAnnouncements = [
      {
        'id': '1',
        'title': 'Flutter & Dart Assessment Scheduled with Extra Long Title for Testing',
        'message':
            'Topic assessments are now active. Students must achieve at least 70% passing score to complete each Learning Outcome.',
        'priority': 'high',
        'section': 'BSIT 3-A Very Long Section Name for Overflow Testing',
        'created_at': '2026-10-22T08:00:00Z',
        'author_name': 'Prof. Khevin Curso Senior Instructor and Administrator',
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showStudentAnnouncementsSheet(ctx, testAnnouncements),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap button to open the sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify sheet title and contents are displayed
    expect(find.text('Notifications & Updates'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Switch to Announcements tab
    await tester.tap(find.text('Announcements'));
    await tester.pumpAndSettle();

    expect(find.text('HIGH'), findsOneWidget);

    // If an overflow occurs, tester.takeException() returns a FlutterError
    expect(tester.takeException(), isNull);
  });
}
