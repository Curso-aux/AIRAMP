import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/components/admin_command_palette.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AdminCommandPalette Widget Tests', () {
    testWidgets('renders search field and navigation pages by default', (tester) async {
      int? selectedBranch;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: AdminCommandPalette(
                onSelectTab: (index) {
                  selectedBranch = index;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check search field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search pages, students, teachers, sections, or actions...'), findsOneWidget);

      // Check default category badges / hints
      expect(find.text('ESC'), findsNWidgets(2));
      expect(find.text('Pages & Screens'), findsWidgets);
      expect(find.text('Student Directory'), findsOneWidget);
      expect(find.text('Faculty & Staff'), findsOneWidget);

      // Select Student Directory (branch 1)
      await tester.tap(find.text('Student Directory'));
      await tester.pumpAndSettle();

      expect(selectedBranch, 1);
    });

    testWidgets('filters items when typing in search field', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: AdminCommandPalette(
                onSelectTab: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Type "CSV"
      await tester.enterText(find.byType(TextField), 'CSV');
      await tester.pumpAndSettle();

      expect(find.text('Bulk Import Students & Faculty (CSV)'), findsOneWidget);
      expect(find.text('Export Student Roster (CSV)'), findsOneWidget);
      expect(find.text('Class Sections'), findsNothing);
    });

    testWidgets('keyboard navigation with arrow keys and Enter executes selected item', (tester) async {
      int? selectedBranch;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: AdminCommandPalette(
                onSelectTab: (index) {
                  selectedBranch = index;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Press ArrowDown to move to item index 1 (Student Directory)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Press Enter to activate
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(selectedBranch, 1);
    });
  });
}
