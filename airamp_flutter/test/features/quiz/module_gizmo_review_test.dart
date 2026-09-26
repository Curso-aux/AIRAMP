import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/features/quiz/data/module_review_provider.dart';
import 'package:airamp_flutter/src/features/quiz/presentation/module_gizmo_review_screen.dart';

class FakeModuleReviewNotifier extends ModuleReviewNotifier {
  final ModuleDeckState initialState;
  FakeModuleReviewNotifier(this.initialState);

  @override
  ModuleDeckState build() => initialState;

  @override
  Future<void> loadDeck(int loId, {bool forceRefresh = false}) async {
    // Keep initial state for widget testing
  }

  @override
  Future<void> updateCardMastery(int cardId, bool isMastered) async {
    final updated = state.cards.map((c) {
      if (c['id'] == cardId) {
        return {
          ...c,
          'is_mastered': isMastered ? 1 : 0,
        };
      }
      return c;
    }).toList();

    int mastered = 0;
    int weak = 0;
    for (final c in updated) {
      if (c['is_mastered'] == 1 || c['is_mastered'] == true) {
        mastered++;
      } else {
        weak++;
      }
    }

    state = state.copyWith(
      cards: updated,
      masteredCount: mastered,
      weakCount: weak,
    );
  }
}

void main() {
  final sampleCards = [
    {
      'id': 1,
      'lo_id': 10,
      'card_type': 'concept',
      'front_text': 'What is State?',
      'back_text': 'Information that can be read synchronously when the widget is built.',
      'explanation': 'Key concept derived from reading material.',
      'source_snippet': 'State Management Guide',
      'is_mastered': 0,
      'review_count': 0,
    },
    {
      'id': 2,
      'lo_id': 10,
      'card_type': 'practice_quiz',
      'front_text': 'Which widget is immutable?',
      'back_text': 'Correct Answer (A): StatelessWidget',
      'options_json': jsonEncode(['A: StatelessWidget', 'B: StatefulWidget', 'C: InheritedWidget', 'D: State']),
      'correct_option': 'A',
      'explanation': 'StatelessWidget does not store mutable state.',
      'source_snippet': 'Module Assessment Question #1',
      'is_mastered': 0,
      'review_count': 0,
    },
  ];

  Widget buildTestWidget({required ModuleDeckState state, String initialMode = 'quiz'}) {
    return ProviderScope(
      overrides: [
        moduleReviewProvider.overrideWith(() => FakeModuleReviewNotifier(state)),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: ModuleGizmoReviewScreen(
          loId: 10,
          initialModuleTitle: 'Mobile UI & State',
          initialSubjectName: 'CS202',
          initialMode: initialMode,
        ),
      ),
    );
  }

  group('ModuleGizmoReviewScreen Widget & Interaction Tests', () {
    testWidgets('1. Renders Gizmo review in Flashcards mode with confidence grading', (tester) async {
      final state = ModuleDeckState(
        isLoading: false,
        moduleData: {
          'id': 10,
          'title': 'Mobile UI & State',
          'subject_code': 'CS202',
        },
        cards: sampleCards,
        masteredCount: 0,
        weakCount: 2,
      );

      await tester.pumpWidget(buildTestWidget(state: state, initialMode: 'flashcard'));
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Mobile UI & State'), findsOneWidget);
      expect(find.text('Gizmo Automated Review Deck'), findsOneWidget);
      expect(find.byIcon(Icons.psychology), findsWidgets);

      // Verify Mode Tabs
      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('Practice Quiz'), findsOneWidget);

      // Verify Card Front
      expect(find.text('What is State?'), findsOneWidget);
      expect(find.text('Card 1 of 2'), findsOneWidget);
      expect(find.text('Need Practice'), findsOneWidget);
      expect(find.text('Got It!'), findsOneWidget);
    });

    testWidgets('2. Tap to flip: reveals answer on card back in Flashcards mode', (tester) async {
      final state = ModuleDeckState(
        isLoading: false,
        moduleData: {
          'id': 10,
          'title': 'Mobile UI & State',
          'subject_code': 'CS202',
        },
        cards: sampleCards,
        masteredCount: 0,
        weakCount: 2,
      );

      await tester.pumpWidget(buildTestWidget(state: state, initialMode: 'flashcard'));
      await tester.pumpAndSettle();

      // Tap card to flip
      await tester.tap(find.text('What is State?'));
      await tester.pumpAndSettle();

      // Verify Back is visible
      expect(find.text('Answer / Definition'), findsOneWidget);
      expect(find.textContaining('Information that can be read synchronously'), findsOneWidget);
    });

    testWidgets('3. Confidence grading: tapping Got It advances to next card and increases streak', (tester) async {
      final state = ModuleDeckState(
        isLoading: false,
        moduleData: {
          'id': 10,
          'title': 'Mobile UI & State',
          'subject_code': 'CS202',
        },
        cards: sampleCards,
        masteredCount: 0,
        weakCount: 2,
      );

      await tester.pumpWidget(buildTestWidget(state: state, initialMode: 'flashcard'));
      await tester.pumpAndSettle();

      // Tap Got It!
      await tester.tap(find.text('Got It!'));
      await tester.pumpAndSettle();

      // Should advance to card 2
      expect(find.text('Card 2 of 2'), findsOneWidget);
    });

    testWidgets('4. Default Practice Quiz mode: renders selectable choices and advances via Next Question button', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final state = ModuleDeckState(
        isLoading: false,
        moduleData: {
          'id': 10,
          'title': 'Mobile UI & State',
          'subject_code': 'CS202',
        },
        cards: sampleCards,
        masteredCount: 0,
        weakCount: 2,
      );

      // Default mode is 'quiz'
      await tester.pumpWidget(buildTestWidget(state: state));
      await tester.pumpAndSettle();

      // Verify Card 1 shows Question & prompt
      expect(find.text('What is State?'), findsOneWidget);
      expect(find.textContaining('Select an option'), findsOneWidget);

      // Tap correct choice on Card 1
      await tester.tap(find.text('Information that can be read synchronously when the widget is built.'));
      await tester.pumpAndSettle();

      // Card 1 answered: reveals Next Question button
      expect(find.textContaining('Correct!'), findsOneWidget);
      expect(find.textContaining('Next Question'), findsOneWidget);

      // Advance to Card 2 via Next Question
      await tester.tap(find.textContaining('Next Question'));
      await tester.pumpAndSettle();

      // Card 2: Which widget is immutable?
      expect(find.text('Which widget is immutable?'), findsOneWidget);
      expect(find.text('StatelessWidget'), findsOneWidget);
      expect(find.text('StatefulWidget'), findsOneWidget);

      // Tap Option A (StatelessWidget)
      await tester.tap(find.text('StatelessWidget'));
      await tester.pumpAndSettle();

      // Last card answered: reveals Complete Quiz button
      expect(find.textContaining('Correct!'), findsOneWidget);
      expect(find.textContaining('Complete Quiz'), findsOneWidget);
    });
  });
}
