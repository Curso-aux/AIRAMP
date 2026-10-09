import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/components/placeholders_and_vanish_input.dart';
import 'package:airamp_flutter/src/features/landing/presentation/components/placeholders_and_vanish_input_demo.dart';
import 'package:airamp_flutter/src/features/landing/presentation/web_landing_screen.dart';

void main() {
  const testPlaceholders = [
    "What's the first rule of Fight Club?",
    "Who is Tyler Durden?",
    "Where is Andrew Laeddis Hiding?",
    "Write a Javascript method to reverse a string",
    "How to assemble your own PC?",
  ];

  group('PlaceholdersAndVanishInput Component Tests', () {
    testWidgets('renders input and initial placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PlaceholdersAndVanishInput(
                placeholders: testPlaceholders,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text("What's the first rule of Fight Club?"), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });

    testWidgets('triggers onChange and onSubmit callbacks with vanish effect', (tester) async {
      String changedText = '';
      String submittedText = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PlaceholdersAndVanishInput(
                placeholders: testPlaceholders,
                onChange: (val) => changedText = val,
                onSubmit: (val) => submittedText = val,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Who is Tyler Durden?');
      await tester.pump();

      expect(changedText, 'Who is Tyler Durden?');

      // Tap submit button
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pump();

      expect(submittedText, 'Who is Tyler Durden?');
      // Dissolve animation runs
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('PlaceholdersAndVanishInputDemo Widget Tests', () {
    testWidgets('renders headline and responds with answer card upon submit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlaceholdersAndVanishInputDemo(isDark: true),
            ),
          ),
        ),
      );

      // Verify school management title
      expect(find.text('Ask AIRA School Management'), findsOneWidget);
      expect(find.byType(PlaceholdersAndVanishInput), findsOneWidget);

      // Submit section key query
      await tester.enterText(find.byType(TextField), 'How do students join a section using an access key?');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify answer bubble appears with section key guidance
      expect(find.textContaining('Section Key Enrollment'), findsOneWidget);
    });

    testWidgets('App Information button opens dialog with School Management demo and platform info', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WebLandingScreen(),
          ),
        ),
      );
      await tester.pump();

      // Find the "App Information" button
      final appInfoBtn = find.widgetWithText(OutlinedButton, 'App Information');
      expect(appInfoBtn, findsOneWidget);

      // Tap to open modal
      await tester.tap(appInfoBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify dialog is shown with demo and ecosystem cloud
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Ask AIRA School Management'), findsWidgets);
      expect(find.text('Cross-Platform Ecosystem'), findsWidgets);
      expect(find.text('Web Console'), findsWidgets);
      expect(find.text('Windows Desktop'), findsWidgets);
      expect(find.text('Android Native'), findsWidgets);
    });
  });
}
