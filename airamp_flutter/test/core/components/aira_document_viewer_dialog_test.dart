import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/components/aira_document_viewer_dialog.dart';
import 'package:airamp_flutter/src/features/curriculum/presentation/curriculum_content_sheet.dart';

void main() {
  final sampleContent = {
    'id': 101,
    'title': 'Senior High School General Physics Module',
    'content_type': 'PDF',
    'content_data': 'https://example.com/materials/physics.pdf',
  };

  final sampleFileInfo = MaterialFileInfo(
    isFile: true,
    fileName: 'Physics_Module_1.pdf',
    fileSize: 2048500,
    fileExtension: 'pdf',
    description: 'Kinematics and Dynamics overview',
  );

  group('AiraDocumentViewerDialog - R1 Cleanliness & Responsiveness', () {
    testWidgets('1. Page-by-page text reading view and pagination controls are completely absent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AiraDocumentViewerDialog.show(
                  ctx,
                  content: sampleContent,
                  fileInfo: sampleFileInfo,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Assert pagination and reading controls are completely absent
      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('Previous'), findsNothing);
      expect(find.text('Next'), findsNothing);
      expect(find.textContaining('Page 1 of'), findsNothing);
      expect(find.text('OFFICIAL STUDY HANDOUT'), findsNothing);
      expect(find.byIcon(Icons.text_fields_rounded), findsNothing);
      expect(find.byIcon(Icons.copy_rounded), findsNothing);
    });

    testWidgets('2. Download and View PDF / Open External Link action buttons are present and functional', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AiraDocumentViewerDialog.show(
                  ctx,
                  content: sampleContent,
                  fileInfo: sampleFileInfo,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Assert actions and header elements are present
      expect(find.text('Download Material'), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.text('View PDF in System App'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify header details
      expect(find.text('Senior High School General Physics Module'), findsWidgets);
      expect(find.text('Kinematics and Dynamics overview'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(AiraDocumentViewerDialog), findsNothing);
    });

    testWidgets('3. Renders cleanly on mobile viewport (360x800) with zero RenderFlex overflow or pixel stretch', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AiraDocumentViewerDialog.show(
                  ctx,
                  content: sampleContent,
                  fileInfo: sampleFileInfo,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Zero exceptions allowed (no RenderFlex overflow)
      expect(tester.takeException(), isNull);

      // Verify buttons are fully visible and clickable
      expect(find.text('Download Material'), findsOneWidget);
      expect(find.text('View PDF in System App'), findsOneWidget);

      // Close modal cleanly
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(AiraDocumentViewerDialog), findsNothing);
    });

    testWidgets('4. Responsive layout stacks action buttons vertically on narrow dialog width', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AiraDocumentViewerDialog.show(
                  ctx,
                  content: sampleContent,
                  fileInfo: sampleFileInfo,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Download Material'), findsOneWidget);
      expect(find.text('View PDF in System App'), findsOneWidget);

      // Verify stacked layout (vertical offset between buttons)
      final downloadRect = tester.getRect(find.text('Download Material'));
      final viewPdfRect = tester.getRect(find.text('View PDF in System App'));
      expect(viewPdfRect.top, greaterThan(downloadRect.bottom));
    });
  });
}
