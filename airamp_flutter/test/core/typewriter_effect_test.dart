import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/components/typewriter_effect.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';

void main() {
  group('TypewriterEffect Component Tests', () {
    testWidgets('renders all words in static test mode without hanging', (tester) async {
      final words = [
        const TypewriterWord(text: 'Ask'),
        const TypewriterWord(text: 'AIRA'),
        const TypewriterWord(text: 'School'),
        TypewriterWord(
          text: 'Management',
          color: AppTheme.darkPrimary,
          className: 'text-blue-500',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TypewriterEffect(
                words: words,
                textStyle: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        ),
      );

      // Verify the entire concatenated text is rendered
      expect(find.text('Ask AIRA School Management'), findsOneWidget);
    });

    testWidgets('animates character by character when forceAnimateInTest is enabled', (tester) async {
      bool completed = false;
      final words = [
        const TypewriterWord(text: 'AIRA'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TypewriterEffect(
                words: words,
                typingSpeed: const Duration(milliseconds: 50),
                forceAnimateInTest: true,
                onComplete: () {
                  completed = true;
                },
              ),
            ),
          ),
        ),
      );

      // Initial frame: 0 chars typed yet
      expect(find.text('AIRA'), findsNothing);

      // Pump through the 4 characters (4 * 50ms = 200ms)
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.textContaining('A'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      expect(completed, isTrue);
    });
  });
}
