import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airamp_flutter/src/features/esp32_hub/data/saved_materials_service.dart';
import 'package:airamp_flutter/src/features/esp32_hub/domain/esp32_hub_models.dart';
import 'package:airamp_flutter/src/features/esp32_hub/presentation/saved_offline_materials_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SavedMaterialsService.instance.init(force: true);
  });

  group('SavedMaterialsService Tests', () {
    test('loads default seeded materials when storage is empty', () async {
      final materials = await SavedMaterialsService.instance.getSavedMaterials();
      expect(materials.isNotEmpty, isTrue);
      expect(materials.length, greaterThanOrEqualTo(4));
    });

    test('correctly calculates formatted storage size', () {
      final items = [
        HubMaterialItem(
          id: 'test_1',
          title: 'Item 1',
          subjectName: 'Math',
          fileType: HubFileType.pdf,
          sizeBytes: 1048576, // 1 MB
        ),
        HubMaterialItem(
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

    test('can remove and add offline materials', () async {
      final initial = await SavedMaterialsService.instance.getSavedMaterials();
      final firstId = initial.first.id;

      await SavedMaterialsService.instance.removeMaterial(firstId);
      final afterRemove = await SavedMaterialsService.instance.getSavedMaterials();
      expect(afterRemove.any((m) => m.id == firstId), isFalse);

      final newItem = HubMaterialItem(
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
  });
}
