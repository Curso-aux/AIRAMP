import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/components/create_quiz_dialog.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseHelper().database;
  });

  Widget buildTestWidget() {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const CreateQuizDialog(
          subjectId: 1,
          subjectName: 'Test Subject',
        ),
      ),
    );
  }

  testWidgets('CreateQuizDialog renders responsive Scaffold with AppBar and close button', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verify AppBar and Header
    expect(find.text('Create & Assign Quiz'), findsOneWidget);
    expect(find.text('Test Subject'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Verify Stepper Pills
    expect(find.text('1. Details'), findsOneWidget);
    expect(find.textContaining('2. Questions'), findsOneWidget);
    expect(find.textContaining('3. Assign'), findsOneWidget);

    // Verify Action Bar buttons
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Next Step'), findsOneWidget);
  });

  testWidgets('Next Step validation: requires title, then advances step', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap Next Step without title -> shows snackbar
    await tester.tap(find.text('Next Step'));
    await tester.pump();
    expect(find.text('Please enter a quiz title'), findsOneWidget);

    // Pump past the snackbar timer so it disappears
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Fill title
    final titleField = find.byType(TextField).first;
    await tester.enterText(titleField, 'Midterm Quiz');
    await tester.pumpAndSettle();

    // Tap Next Step -> advances to Step 2
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();

    // Verify Step 2 is active
    expect(find.text('Bulk Upload / Quick-Paste'), findsOneWidget);
    expect(find.textContaining('Manual Entry'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('Close button pops navigator without getting stuck', (tester) async {
    bool didPop = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const CreateQuizDialog(subjectId: 1, subjectName: 'Subject 1'),
                    ),
                  );
                  didPop = true;
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open screen
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify it opened
    expect(find.text('Create & Assign Quiz'), findsOneWidget);

    // Tap Close (X)
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Verify it popped cleanly and didPop is true
    expect(find.text('Create & Assign Quiz'), findsNothing);
    expect(didPop, isTrue);
  });

  testWidgets('Advances through all 3 steps: Details -> Questions -> Students & Assign', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    // Step 1: Fill title
    final titleField = find.byType(TextField).first;
    await tester.enterText(titleField, 'End-to-End Quiz');
    await tester.pumpAndSettle();

    // Next to Step 2
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();

    expect(find.text('Bulk Upload / Quick-Paste'), findsOneWidget);

    // Next to Step 3 (questions are preloaded from sample text)
    await tester.tap(find.text('Next Step'));
    await tester.pump();
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Verify Step 3: Assign is active
    expect(find.textContaining('Select All'), findsOneWidget);
    expect(find.textContaining('Publish & Assign'), findsOneWidget);
  });
}
