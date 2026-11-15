import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airamp_flutter/src/features/esp32_hub/data/saved_materials_service.dart';
import 'package:airamp_flutter/src/features/esp32_hub/domain/esp32_hub_models.dart';
import 'package:airamp_flutter/src/features/esp32_hub/presentation/saved_offline_materials_modal.dart';
import 'package:open_filex/open_filex.dart';

import 'dart:convert';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final initialTestItems = [
    const HubMaterialItem(
      id: 'mat_01',
      title: 'Module 1: Cellular Biology & Mitosis',
      subjectName: 'General Science',
      fileType: HubFileType.module,
      sizeBytes: 1450000,
      fileName: 'bio_module1.pdf',
    ),
    const HubMaterialItem(
      id: 'mat_02',
      title: 'Unit 2: Quadratic Functions & Parabolas',
      subjectName: 'Mathematics',
      fileType: HubFileType.pdf,
      sizeBytes: 980000,
      fileName: 'math_unit2.pdf',
    ),
    const HubMaterialItem(
      id: 'mat_03',
      title: 'Quarter 1 Diagnostic Assessment (20 Items)',
      subjectName: 'General Science',
      fileType: HubFileType.quiz,
      sizeBytes: 320000,
      fileName: 'science_quiz_q1.json',
    ),
    const HubMaterialItem(
      id: 'mat_04',
      title: 'Reading Comprehension & Critical Analysis',
      subjectName: 'English',
      fileType: HubFileType.doc,
      sizeBytes: 650000,
      fileName: 'english_module1.pdf',
    ),
  ];

  setUp(() async {
    final encoded = jsonEncode(initialTestItems.map((e) => e.toJson()).toList());
    SharedPreferences.setMockInitialValues({
      'airamp_saved_esp32_materials_v1': encoded,
    });
    await SavedMaterialsService.instance.init(force: true);
  });

  group('SavedMaterialsService & Compression Tests', () {
    test('loads seeded materials', () async {
      final materials = await SavedMaterialsService.instance.getSavedMaterials();
      expect(materials.isNotEmpty, isTrue);
      expect(materials.length, greaterThanOrEqualTo(4));
    });

    test('correctly calculates formatted storage size', () {
      final items = [
        const HubMaterialItem(
          id: 'test_1',
          title: 'Item 1',
          subjectName: 'Math',
          fileType: HubFileType.pdf,
          sizeBytes: 1048576, // 1 MB
        ),
        const HubMaterialItem(
          id: 'test_2',
          title: 'Item 2',
          subjectName: 'Science',
          fileType: HubFileType.quiz,
          sizeBytes: 524288, // 0.5 MB
        ),
      ];
      final formatted = SavedMaterialsService.instance.getFormattedStorageUsed(items);
      expect(formatted, contains('MB'));
    });

    test('correctly calculates compression savings in formattedSize', () {
      const compressedItem = HubMaterialItem(
        id: 'test_comp',
        title: 'Compressed Biology Module',
        subjectName: 'Science',
        fileType: HubFileType.pdf,
        sizeBytes: 300000,
        originalSizeBytes: 1000000,
        isCompressed: true,
      );

      expect(compressedItem.isCompressed, isTrue);
      expect(compressedItem.formattedSize, contains('Saved 70%'));
    });

    test('can remove and add offline materials', () async {
      final initial = await SavedMaterialsService.instance.getSavedMaterials();
      final firstId = initial.first.id;

      await SavedMaterialsService.instance.removeMaterial(firstId);
      final afterRemove = await SavedMaterialsService.instance.getSavedMaterials();
      expect(afterRemove.any((m) => m.id == firstId), isFalse);

      const newItem = HubMaterialItem(
        id: 'new_item_99',
        title: 'New Offline Material',
        subjectName: 'Filipino',
        fileType: HubFileType.doc,
        sizeBytes: 150000,
      );

      await SavedMaterialsService.instance.saveMaterials([newItem]);
      final afterAdd = await SavedMaterialsService.instance.getSavedMaterials();
      expect(afterAdd.any((m) => m.id == 'new_item_99'), isTrue);
    });

    test('exportDirectlyToDownloads writes file and returns path', () async {
      const itemToExport = HubMaterialItem(
        id: 'test_export_1',
        title: 'Exportable Lesson Note',
        subjectName: 'Science',
        fileType: HubFileType.pdf,
        sizeBytes: 4096,
        fileName: 'lesson_note_exported.pdf',
        content: '# Mitosis and Cytokinesis Guide\n\nCellular biology review.',
      );

      final exportedPath = await SavedMaterialsService.instance.exportDirectlyToDownloads(itemToExport);
      expect(exportedPath, isNotNull);
      final file = File(exportedPath!);
      expect(await file.exists(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('Mitosis and Cytokinesis'));

      // Clean up test file
      await file.delete();
    });

    test('removeMaterial deletes physical file from disk when localPath is set', () async {
      final tempDir = Directory.systemTemp.createTempSync('airamp_test_');
      final tempFile = File('${tempDir.path}/test_cleanup_material.pdf');
      await tempFile.writeAsString('Dummy material data');
      expect(await tempFile.exists(), isTrue);

      final itemWithLocalFile = HubMaterialItem(
        id: 'test_item_cleanup',
        title: 'Cleanup Test Material',
        subjectName: 'Test Subject',
        fileType: HubFileType.pdf,
        sizeBytes: 100,
        localPath: tempFile.path,
      );

      await SavedMaterialsService.instance.saveMaterials([itemWithLocalFile]);
      final savedList = await SavedMaterialsService.instance.getSavedMaterials();
      expect(savedList.any((m) => m.id == 'test_item_cleanup'), isTrue);

      await SavedMaterialsService.instance.removeMaterial('test_item_cleanup');
      final updatedList = await SavedMaterialsService.instance.getSavedMaterials();
      expect(updatedList.any((m) => m.id == 'test_item_cleanup'), isFalse);
      expect(await tempFile.exists(), isFalse);

      tempDir.deleteSync(recursive: true);
    });

    test('openMaterial returns fileNotFound when local file does not exist and has no content', () async {
      const missingItem = HubMaterialItem(
        id: 'missing_123',
        title: 'Non-existent item',
        subjectName: 'General',
        fileType: HubFileType.pdf,
        sizeBytes: 500,
        localPath: '/non/existent/path/file.pdf',
      );

      final result = await SavedMaterialsService.instance.openMaterial(missingItem);
      expect(result.type, equals(ResultType.fileNotFound));
    });
  });

  group('SavedOfflineMaterialsModal Widget Tests', () {
    testWidgets('renders header, storage badge, and materials list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SavedOfflineMaterialsModal(
              studentName: 'Juan Dela Cruz',
              studentSection: 'Grade 10 - Emerald',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline Learning Materials'), findsOneWidget);
      expect(find.text('100% Offline'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('All'), findsOneWidget);
      expect(find.textContaining('Modules'), findsOneWidget);
      expect(find.textContaining('Quizzes'), findsOneWidget);

      // Verify at least one item card rendered
      expect(find.text('Module 1: Cellular Biology & Mitosis'), findsOneWidget);
    });

    testWidgets('filters list by category chip', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SavedOfflineMaterialsModal(
              studentName: 'Juan Dela Cruz',
              studentSection: 'Grade 10 - Emerald',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Modules filter chip
      await tester.tap(find.textContaining('Modules'));
      await tester.pumpAndSettle();

      expect(find.text('Module 1: Cellular Biology & Mitosis'), findsOneWidget);
      expect(find.text('Unit 2: Quadratic Functions & Parabolas'), findsNothing);
    });

    testWidgets('filters list by search query', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SavedOfflineMaterialsModal(
              studentName: 'Juan Dela Cruz',
              studentSection: 'Grade 10 - Emerald',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Mitosis');
      await tester.pumpAndSettle();

      expect(find.text('Module 1: Cellular Biology & Mitosis'), findsOneWidget);
      expect(find.text('Unit 2: Quadratic Functions & Parabolas'), findsNothing);
    });

    testWidgets('renders Save button and opens export options modal when tapped', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SavedOfflineMaterialsModal(
              studentName: 'Juan Dela Cruz',
              studentSection: 'Grade 10 - Emerald',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the "Save" button on a material card
      final saveBtnFinder = find.widgetWithText(OutlinedButton, 'Save');
      expect(saveBtnFinder, findsWidgets);

      await tester.tap(saveBtnFinder.first);
      await tester.pumpAndSettle();

      // Verify bottom sheet appears with export options
      expect(find.text('Save to Device Storage'), findsOneWidget);
      expect(find.text('Save to Downloads Folder'), findsOneWidget);
      expect(find.text('Choose Storage Folder...'), findsOneWidget);
      expect(find.text('Open in Default System Viewer'), findsOneWidget);
    });

    testWidgets('OfflineMaterialReaderDialog renders document action buttons for PDF files', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      final pdfItem = initialTestItems.first; // Module 1: Cellular Biology & Mitosis (pdf)

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineMaterialReaderDialog(item: pdfItem),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open in System Reader'), findsOneWidget);
      expect(find.text('Save to Downloads'), findsOneWidget);
      expect(find.text('Choose Folder...'), findsOneWidget);
      expect(find.textContaining('This learning module is saved as a complete file'), findsOneWidget);
    });
  });

  group('ESP32 OLED QR Payload & Teacher Scanner Tests', () {
    test('HubQrPayload accurately parses OLED QR screen payload format', () {
      const oledPayload = 'WIFI:S:AIRAMP-HUB-01;T:WPA;P:aira1234;;AIRAMP:SEC=Grade 10 - Rizal;IP=192.168.4.1';
      final parsed = HubQrPayload.parse(oledPayload);

      expect(parsed.ssid, equals('AIRAMP-HUB-01'));
      expect(parsed.password, equals('aira1234'));
      expect(parsed.sectionName, equals('Grade 10 - Rizal'));
      expect(parsed.ipAddress, equals('192.168.4.1'));
    });

    test('HubQrPayload parses custom SSID and IP gateway', () {
      const customPayload = 'WIFI:S:ROOM-101-HUB;P:securePass99;;AIRAMP:SEC=Science 9;IP=192.168.4.254';
      final parsed = HubQrPayload.parse(customPayload);

      expect(parsed.ssid, equals('ROOM-101-HUB'));
      expect(parsed.password, equals('securePass99'));
      expect(parsed.sectionName, equals('Science 9'));
      expect(parsed.ipAddress, equals('192.168.4.254'));
    });
  });
}

