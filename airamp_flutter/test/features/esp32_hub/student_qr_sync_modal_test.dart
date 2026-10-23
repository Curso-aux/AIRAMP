import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/features/esp32_hub/presentation/student_esp32_sync_modal.dart';
import 'package:airamp_flutter/src/core/components/aira/aira_overlay_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudentEsp32SyncModal UI/UX Tests', () {
    testWidgets('renders institutional header and student-friendly copy', (WidgetTester tester) async {
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

      // Verify close button exists
      expect(find.byTooltip('Close'), findsOneWidget);

      // Check tabs
      expect(find.text('Scan Hub QR'), findsOneWidget);
      expect(find.text('Saved Files'), findsOneWidget);
      expect(find.text('Manual Connect'), findsOneWidget);
    });

    testWidgets('renders 3-step micro-guide and manual Wi-Fi fallback', (WidgetTester tester) async {
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

      // Instructional headline and subtext
      expect(find.text('Scan Classroom Hub QR'), findsOneWidget);
      expect(
        find.text('Point your camera at the QR code on the teacher\'s hub or classroom projector to sync modules offline.'),
        findsOneWidget,
      );

      // 3-step micro-guide
      expect(find.text('Frame QR'), findsOneWidget);
      expect(find.text('Auto-Sync'), findsOneWidget);
      expect(find.text('Save & Learn'), findsOneWidget);

      // Manual Wi-Fi fallback button
      final fallbackFinder = find.text('Can\'t scan? Connect via Wi-Fi manually');
      expect(fallbackFinder, findsOneWidget);

      // Tap fallback button and verify it switches to Manual Connect tab
      await tester.ensureVisible(fallbackFinder);
      await tester.tap(fallbackFinder);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Manual Classroom Hub Connection'), findsOneWidget);
      expect(find.text('Classroom Hub Wi-Fi Name (SSID)'), findsOneWidget);
      expect(find.text('Hub Gateway IP Address'), findsOneWidget);
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
