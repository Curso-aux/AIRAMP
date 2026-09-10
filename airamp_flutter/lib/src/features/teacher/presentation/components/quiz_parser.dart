import 'dart:convert';

class ParsedQuestion {
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption; // 'A' | 'B' | 'C' | 'D'

  ParsedQuestion({
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
  });

  factory ParsedQuestion.fromJson(dynamic json) {
    if (json is Map) {
      return ParsedQuestion(
        questionText: (json['question_text'] ?? json['question'] ?? '').toString().trim(),
        optionA: (json['option_a'] ?? json['a'] ?? '').toString().trim(),
        optionB: (json['option_b'] ?? json['b'] ?? '').toString().trim(),
        optionC: (json['option_c'] ?? json['c'] ?? '').toString().trim(),
        optionD: (json['option_d'] ?? json['d'] ?? '').toString().trim(),
        correctOption: (json['correct_option'] ?? json['correct'] ?? 'A').toString().toUpperCase().trim(),
      );
    }
    // Handle database format
    return ParsedQuestion(
      questionText: (json['question_text'] ?? '').toString().trim(),
      optionA: (json['option_a'] ?? '').toString().trim(),
      optionB: (json['option_b'] ?? '').toString().trim(),
      optionC: (json['option_c'] ?? '').toString().trim(),
      optionD: (json['option_d'] ?? '').toString().trim(),
      correctOption: (json['correct_option'] ?? 'A').toString().toUpperCase().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question_text': questionText,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'correct_option': correctOption,
    };
  }
}

class QuizParserResult {
  final List<ParsedQuestion> questions;
  final List<String> errors;

  QuizParserResult({required this.questions, required this.errors});

  bool get hasErrors => errors.isNotEmpty;
  bool get hasQuestions => questions.isNotEmpty;
}

class QuizParser {
  /// Parses either formatted text or JSON string into a structured list of questions.
  static QuizParserResult parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return QuizParserResult(questions: [], errors: ['Input text is empty.']);
    }

    // Try parsing as JSON first
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          final questions = <ParsedQuestion>[];
          final errors = <String>[];

          for (int i = 0; i < decoded.length; i++) {
            final item = decoded[i];
            if (item is Map) {
              final qText = (item['question_text'] ?? item['question'] ?? '').toString().trim();
              final optA = (item['option_a'] ?? item['a'] ?? (item['options'] is List && (item['options'] as List).isNotEmpty ? item['options'][0] : '')).toString().trim();
              final optB = (item['option_b'] ?? item['b'] ?? (item['options'] is List && (item['options'] as List).length > 1 ? item['options'][1] : '')).toString().trim();
              final optC = (item['option_c'] ?? item['c'] ?? (item['options'] is List && (item['options'] as List).length > 2 ? item['options'][2] : '')).toString().trim();
              final optD = (item['option_d'] ?? item['d'] ?? (item['options'] is List && (item['options'] as List).length > 3 ? item['options'][3] : '')).toString().trim();
              String correct = (item['correct_option'] ?? item['answer'] ?? item['correct'] ?? 'A').toString().toUpperCase().trim();
              if (correct.length > 1) {
                // If the user wrote "Answer: B" or full text, extract first letter
                final match = RegExp(r'[ABCD]').firstMatch(correct);
                correct = match?.group(0) ?? 'A';
              }

              if (qText.isEmpty || optA.isEmpty || optB.isEmpty || optC.isEmpty || optD.isEmpty) {
                errors.add('Question #${i + 1} is missing required fields (question text or options A-D).');
              } else {
                questions.add(ParsedQuestion(
                  questionText: qText,
                  optionA: optA,
                  optionB: optB,
                  optionC: optC,
                  optionD: optD,
                  correctOption: correct,
                ));
              }
            }
          }

          return QuizParserResult(questions: questions, errors: errors);
        }
      } catch (e) {
        // Fall back to text parsing
      }
    }

    // Parse plain text block by block
    return _parseText(trimmed);
  }

  static QuizParserResult _parseText(String text) {
    final questions = <ParsedQuestion>[];
    final errors = <String>[];

    // Normalize line breaks
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawBlocks = normalized.split(RegExp(r'\n\s*\n+'));

    int blockIndex = 1;
    for (final rawBlock in rawBlocks) {
      final block = rawBlock.trim();
      if (block.isEmpty) continue;

      final lines = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.length < 5) {
        errors.add('Block #$blockIndex seems too short. Each question needs question text, options A-D, and an answer.');
        blockIndex++;
        continue;
      }

      String? questionText;
      String? optA;
      String? optB;
      String? optC;
      String? optD;
      String? correct;

      final optionPattern = RegExp(r'^[(\[]?([A-Da-d])[)\].:\-]\s*(.*)$');
      final answerPattern = RegExp(r'^(?:Answer|Ans|Correct|Correct Answer)\s*[:=\-]?\s*([A-Da-d])', caseSensitive: false);

      final questionLines = <String>[];

      for (final line in lines) {
        final ansMatch = answerPattern.firstMatch(line);
        if (ansMatch != null) {
          correct = ansMatch.group(1)?.toUpperCase();
          continue;
        }

        final optMatch = optionPattern.firstMatch(line);
        if (optMatch != null) {
          final letter = optMatch.group(1)!.toUpperCase();
          final content = optMatch.group(2) ?? '';
          switch (letter) {
            case 'A':
              optA = content;
              break;
            case 'B':
              optB = content;
              break;
            case 'C':
              optC = content;
              break;
            case 'D':
              optD = content;
              break;
          }
          continue;
        }

        // If options haven't started yet, it's question text
        if (optA == null && optB == null && optC == null && optD == null) {
          questionLines.add(line);
        }
      }

      // Clean up question text (remove leading numbers like "1." or "Q1:")
      var qRaw = questionLines.join(' ');
      qRaw = qRaw.replaceFirst(RegExp(r'^(?:Q\d+|Question\s*\d+|\d+)[.:\-]\s*', caseSensitive: false), '');
      questionText = qRaw.trim();

      if (questionText.isEmpty) {
        errors.add('Question #$blockIndex is missing question text.');
      } else if (optA == null || optB == null || optC == null || optD == null) {
        errors.add('Question #$blockIndex ("$questionText") is missing one or more options (A, B, C, D).');
      } else {
        questions.add(ParsedQuestion(
          questionText: questionText,
          optionA: optA,
          optionB: optB,
          optionC: optC,
          optionD: optD,
          correctOption: correct ?? 'A',
        ));
      }

      blockIndex++;
    }

    return QuizParserResult(questions: questions, errors: errors);
  }
}
