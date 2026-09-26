import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/features/quiz/domain/module_scanner_service.dart';

void main() {
  late ModuleScannerService scanner;

  setUp(() {
    scanner = ModuleScannerService();
  });

  group('ModuleScannerService Parser & Extraction Tests', () {
    test('1. Extracts concept flashcards from definition patterns in reading materials', () {
      final moduleData = {
        'id': 101,
        'title': 'State Management in Flutter',
        'description': 'Comprehensive overview of state management patterns.',
        'performance_criteria': 'Build responsive applications.',
        'contents': [
          {
            'title': 'Core Definitions',
            'content_data': '''
State: Information that can be read synchronously when the widget is built and might change during the lifetime of the widget.
StatefulWidget: A widget that has mutable state.
StatelessWidget: A widget that does not require mutable state.
Riverpod: A reactive caching and state-management framework for Dart and Flutter.
''',
          }
        ],
        'questions': [],
      };

      final cards = scanner.parseModuleData(moduleData);

      expect(cards.isNotEmpty, isTrue);
      // Verify concept cards were generated
      final stateCard = cards.firstWhere((c) => c['front_text'] == 'What is State?');
      expect(stateCard['back_text'], contains('Information that can be read synchronously'));
      expect(stateCard['card_type'], 'concept');

      final riverpodCard = cards.firstWhere((c) => c['front_text'] == 'What is Riverpod?');
      expect(riverpodCard['back_text'], contains('reactive caching and state-management framework'));
    });

    test('2. Converts assessment questions into interactive practice quiz cards', () {
      final moduleData = {
        'id': 102,
        'title': 'Dart Basics',
        'description': 'Introduction to Dart language basics.',
        'performance_criteria': 'Write simple Dart programs.',
        'contents': [],
        'questions': [
          {
            'question_text': 'Which keyword is used to declare an immutable variable in Dart?',
            'option_a': 'final',
            'option_b': 'var',
            'option_c': 'dynamic',
            'option_d': 'mutable',
            'correct_option': 'A',
          },
        ],
      };

      final cards = scanner.parseModuleData(moduleData);

      expect(cards.isNotEmpty, isTrue);
      final quizCard = cards.firstWhere((c) => c['card_type'] == 'practice_quiz');
      expect(quizCard['front_text'], 'Which keyword is used to declare an immutable variable in Dart?');
      expect(quizCard['correct_option'], 'A');
      expect(quizCard['options_json'], contains('final'));
      expect(quizCard['options_json'], contains('var'));
    });

    test('3. Generates smart multiple-choice options for concepts when vocabulary pool permits', () {
      final moduleData = {
        'id': 103,
        'title': 'Widget Fundamentals',
        'description': 'Understanding widgets in Flutter.',
        'contents': [
          {
            'title': 'Widgets',
            'content_data': '''
Container: A convenience widget that combines common painting, positioning, and sizing widgets.
Scaffold: Implements the basic material design visual layout structure.
AppBar: A material design app bar.
Column: A widget that displays its children in a vertical array.
Row: A widget that displays its children in a horizontal array.
''',
          }
        ],
        'questions': [],
      };

      final cards = scanner.parseModuleData(moduleData);

      // Verify that options were generated for concept cards from the vocabulary pool
      final cardWithOptions = cards.firstWhere((c) => c['options_json'] != null);
      expect(cardWithOptions['options_json'], isNotNull);
      expect(cardWithOptions['correct_option'], isNotNull);
    });

    test('4. Gracefully falls back to module objectives if reading material is empty', () {
      final moduleData = {
        'id': 104,
        'title': 'Asynchronous Programming',
        'description': 'Master Futures, async/await, and Streams.',
        'performance_criteria': 'Handle network calls safely without blocking the UI thread.',
        'contents': [],
        'questions': [],
      };

      final cards = scanner.parseModuleData(moduleData);

      // Must generate minimum fallback cards from metadata so students never get an empty deck
      expect(cards.length, greaterThanOrEqualTo(3));
      expect(cards.any((c) => c['back_text'] == 'Asynchronous Programming'), isTrue);
      expect(cards.any((c) => c['back_text'].toString().contains('Futures, async/await')), isTrue);
    });
  });
}
