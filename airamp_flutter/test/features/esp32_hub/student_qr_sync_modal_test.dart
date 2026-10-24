import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/features/esp32_hub/presentation/student_esp32_sync_modal.dart';
import 'package:airamp_flutter/src/core/components/aira/aira_overlay_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudentEsp32SyncModal UI/UX Tests', () {
    testWidgets('renders institutional header, ledger bar, and student-friendly copy', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudentEsp32SyncModal(
              studentName: 'Juan Dela Cruz',
              studentSection: 'Grade 10 - Rizal',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Check header title & subtitle
      expect(find.text('Classroom Hub Sync'), findsOneWidget);
      expect(find.text('Download class lessons & quizzes offline'), findsOneWidget);

      // Verify close & refresh buttons exist
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byTooltip('Refresh'), findsOneWidget);

      // Verify hardware ledger bar
      expect(find.text('STATION NODE'), findsOneWidget);
      expect(find.text('STORAGE MEDIA'), findsOneWidget);
    });

    testWidgets('renders live connection reminder and manual Wi-Fi credential panel', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudentEsp32SyncModal(
              studentName: 'Juan Dela Cruz',
              studentSection: 'Grade 10 - Rizal',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Live connection reminder components
      expect(find.text('Classroom Hub Not Connected'), findsOneWidget);

      final verifyButton = find.text('Verify Connection Link');
      expect(verifyButton, findsOneWidget);

      // Tap verify button
      await tester.ensureVisible(verifyButton);
      await tester.tap(verifyButton);
      await tester.pump(const Duration(milliseconds: 200));

      // Should still be mounted and responsive
      expect(find.byType(StudentEsp32SyncModal), findsOneWidget);
    });

    testWidgets('AiraOverlayController hides overlay when modal is opened', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AiraOverlayController.show();
      expect(AiraOverlayController.isHidden.value, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                StudentEsp32SyncModal.show(
                  context,
                  studentName: 'Juan',
                  studentSection: 'Grade 10',
                );
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );

      // Open modal
      await tester.tap(find.text('Open Modal'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Floating assistant should be suppressed while modal is active
      expect(AiraOverlayController.isHidden.value, isTrue);

      // Close modal
      final closeButton = find.byTooltip('Close');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Floating assistant should be restored after modal is closed
      expect(AiraOverlayController.isHidden.value, isFalse);
    });
  });
}
