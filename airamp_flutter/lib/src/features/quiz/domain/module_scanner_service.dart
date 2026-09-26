import 'dart:convert';
import '../../../core/database/database_helper.dart';

/// Service responsible for scanning module contents, objectives, and question banks
/// and converting them into Gizmo-style active recall flashcards & interactive mini-quiz cards.
class ModuleScannerService {
  final DatabaseHelper _dbHelper;

  ModuleScannerService({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper();

  /// Scans a specific Learning Outcome module and returns the generated/cached flashcards.
  Future<List<Map<String, dynamic>>> scanAndGenerateCards({
    required int loId,
    bool forceRefresh = false,
  }) async {
    // 1. Check local cache first unless forced refresh or incomplete options
    if (!forceRefresh) {
      final cached = await _dbHelper.getModuleFlashcards(loId);
      final hasMissingOptions = cached.isEmpty || cached.any((c) {
        final optStr = c['options_json']?.toString().trim();
        final correct = c['correct_option']?.toString().trim();
        return optStr == null || optStr.isEmpty || optStr == '[]' || correct == null || correct.isEmpty;
      });
      if (cached.isNotEmpty && !hasMissingOptions) {
        return cached;
      }
    }

    // 2. Load module metadata, reading materials, and questions
    final moduleData = await _dbHelper.getModuleDataForReview(loId);
    if (moduleData == null) {
      return [];
    }

    // 3. Scan & generate flashcard cards
    final cards = parseModuleData(moduleData);

    // 4. Save to SQLite cache for offline instant recall
    if (cards.isNotEmpty) {
      await _dbHelper.saveModuleFlashcards(loId, moduleData['topic_id'] as int?, cards);
      return await _dbHelper.getModuleFlashcards(loId);
    }

    return [];
  }

  /// Scans all LOs under an entire Topic and returns combined flashcards
  Future<List<Map<String, dynamic>>> scanAndGenerateTopicCards({
    required int topicId,
    bool forceRefresh = false,
  }) async {
    final topicData = await _dbHelper.getTopicDataForReview(topicId);
    if (topicData == null) return [];

    final los = (topicData['learning_outcomes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    List<Map<String, dynamic>> combined = [];

    for (final lo in los) {
      final loId = lo['id'] as int;
      final cards = await scanAndGenerateCards(loId: loId, forceRefresh: forceRefresh);
      combined.addAll(cards);
    }

    return combined;
  }

  /// Core Pure Function: Scans raw module data into a list of Gizmo-style flashcards
  List<Map<String, dynamic>> parseModuleData(Map<String, dynamic> moduleData) {
    final List<Map<String, dynamic>> cards = [];
    final Set<String> seenFronts = {};

    final loId = moduleData['id'] as int? ?? 0;
    final topicId = moduleData['topic_id'] as int?;
    final loTitle = moduleData['title']?.toString().trim() ?? 'Module Concept';
    final loDescription = moduleData['description']?.toString().trim() ?? '';
    final performanceCriteria = moduleData['performance_criteria']?.toString().trim() ?? '';

    final contents = (moduleData['contents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final questions = (moduleData['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Collect all vocabulary terms across the module for smart multiple-choice distractor generation
    final Set<String> vocabularyPool = {};

    // ── 1. Process Assessment Questions (Highest Educational Precision) ──
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final qText = (q['question_text']?.toString() ?? '').trim();
      final optA = (q['option_a']?.toString() ?? '').trim();
      final optB = (q['option_b']?.toString() ?? '').trim();
      final optC = (q['option_c']?.toString() ?? '').trim();
      final optD = (q['option_d']?.toString() ?? '').trim();
      final correct = (q['correct_option']?.toString() ?? 'A').toUpperCase().trim();

      if (qText.isEmpty) continue;

      String correctText = optA;
      if (correct == 'B') correctText = optB;
      if (correct == 'C') correctText = optC;
      if (correct == 'D') correctText = optD;

      vocabularyPool.add(correctText);

      final optionsList = [
        'A: $optA',
        'B: $optB',
        'C: $optC',
        'D: $optD',
      ];

      // Add as Interactive Practice Quiz card
      cards.add({
        'lo_id': loId,
        'topic_id': topicId,
        'card_type': 'practice_quiz',
        'front_text': qText,
        'back_text': 'Correct Answer ($correct): $correctText',
        'options_json': jsonEncode(optionsList),
        'correct_option': correct,
        'explanation': 'Correct option is ($correct). This is a verified competency question from the module assessment.',
        'source_snippet': 'Module Assessment Question #${i + 1}',
        'is_mastered': 0,
        'review_count': 0,
      });
      seenFronts.add(qText.toLowerCase());
    }

    // ── 2. Scan Reading Materials (lo_contents) ──
    for (final content in contents) {
      final contentTitle = (content['title']?.toString() ?? '').trim();
      final rawText = (content['content_data']?.toString() ?? '').trim();

      if (rawText.isEmpty) continue;

      // Extract Definitions & Concept Pairs
      final extractedDefinitions = _extractDefinitions(rawText, contentTitle);
      for (final def in extractedDefinitions) {
        final front = def['front']!;
        final back = def['back']!;
        if (!seenFronts.contains(front.toLowerCase())) {
          seenFronts.add(front.toLowerCase());
          vocabularyPool.add(front.replaceAll('What is ', '').replaceAll('?', '').trim());

          cards.add({
            'lo_id': loId,
            'topic_id': topicId,
            'card_type': 'concept',
            'front_text': front,
            'back_text': back,
            'options_json': null,
            'correct_option': null,
            'explanation': 'Key concept derived from reading material: "$contentTitle"',
            'source_snippet': contentTitle,
            'is_mastered': 0,
            'review_count': 0,
          });
        }
      }

      // Extract Bullet Point Takeaways
      final bulletTakeaways = _extractBulletTakeaways(rawText, contentTitle);
      for (final b in bulletTakeaways) {
        final front = b['front']!;
        final back = b['back']!;
        if (!seenFronts.contains(front.toLowerCase())) {
          seenFronts.add(front.toLowerCase());
          cards.add({
            'lo_id': loId,
            'topic_id': topicId,
            'card_type': 'qa',
            'front_text': front,
            'back_text': back,
            'options_json': null,
            'correct_option': null,
            'explanation': 'Takeaway from lesson material: "$contentTitle"',
            'source_snippet': contentTitle,
            'is_mastered': 0,
            'review_count': 0,
          });
        }
      }
    }

    // ── 3. Guarantee 4 Multiple-Choice Options on EVERY Card (Gizmo Practice Mode) ──
    final List<String> domainPool = [
      ...vocabularyPool,
      'Encapsulation & Scoping',
      'Dependency Injection',
      'Reactive State Stream',
      'Immutable Widget Tree',
      'Asynchronous Event Loop',
      'Lifecycle Management',
      'Build Context Hierarchy',
      'Client-Server Sync Protocol',
      'Memory Cache Optimization',
      'Stateful Architecture',
    ];

    for (int i = 0; i < cards.length; i++) {
      final card = cards[i];
      if (card['options_json'] == null) {
        final frontClean = card['front_text'].toString()
            .replaceAll('What is ', '')
            .replaceAll('Define: ', '')
            .replaceAll('?', '')
            .trim();

        // 1. Determine the correct choice and pool
        String correctChoice = frontClean;
        if (correctChoice.length > 50 || card['card_type'] == 'qa') {
          correctChoice = card['back_text'].toString().trim();
        }

        // 2. Select 3 distinct distractors
        final List<String> distractors = domainPool
            .where((v) => v.toLowerCase().trim() != correctChoice.toLowerCase().trim())
            .toSet()
            .toList()
          ..shuffle();

        final chosenDistractors = distractors.take(3).toList();
        while (chosenDistractors.length < 3) {
          chosenDistractors.add('General Competency Standard ${chosenDistractors.length + 1}');
        }

        final allChoices = [correctChoice, ...chosenDistractors]..shuffle();
        final correctIdx = allChoices.indexOf(correctChoice);
        final correctLetter = String.fromCharCode(65 + correctIdx); // 'A', 'B', 'C', 'D'

        final formattedOptions = allChoices.asMap().entries.map((e) {
          final letter = String.fromCharCode(65 + e.key);
          return '$letter: ${e.value}';
        }).toList();

        card['options_json'] = jsonEncode(formattedOptions);
        card['correct_option'] = correctLetter;
      }
    }

    // ── 4. Fallback: Core Competency Cards from Metadata (Always guarantees minimum 3 cards) ──
    if (cards.length < 3) {
      if (loTitle.isNotEmpty) {
        final front1 = 'What is the primary topic of this module?';
        if (!seenFronts.contains(front1.toLowerCase())) {
          seenFronts.add(front1.toLowerCase());
          final choices = [loTitle, 'General System Configuration', 'Legacy Database Indexing', 'Network Socket Protocols']..shuffle();
          final cIdx = choices.indexOf(loTitle);
          cards.add({
            'lo_id': loId,
            'topic_id': topicId,
            'card_type': 'concept',
            'front_text': front1,
            'back_text': loTitle,
            'options_json': jsonEncode(choices.asMap().entries.map((e) => '${String.fromCharCode(65 + e.key)}: ${e.value}').toList()),
            'correct_option': String.fromCharCode(65 + cIdx),
            'explanation': 'Main module title and core focus area.',
            'source_snippet': 'Module Learning Outcome',
            'is_mastered': 0,
            'review_count': 0,
          });
        }
      }

      if (loDescription.isNotEmpty) {
        final front2 = 'What is the core learning objective for $loTitle?';
        if (!seenFronts.contains(front2.toLowerCase())) {
          seenFronts.add(front2.toLowerCase());
          final choices = [loDescription, 'Memorize arbitrary syntax definitions', 'Configure external hardware ports only', 'Skip prerequisites and tests']..shuffle();
          final cIdx = choices.indexOf(loDescription);
          cards.add({
            'lo_id': loId,
            'topic_id': topicId,
            'card_type': 'qa',
            'front_text': front2,
            'back_text': loDescription,
            'options_json': jsonEncode(choices.asMap().entries.map((e) => '${String.fromCharCode(65 + e.key)}: ${e.value}').toList()),
            'correct_option': String.fromCharCode(65 + cIdx),
            'explanation': 'Official competency statement for this learning unit.',
            'source_snippet': 'Curriculum Specifications',
            'is_mastered': 0,
            'review_count': 0,
          });
        }
      }

      if (performanceCriteria.isNotEmpty) {
        final front3 = 'What are the performance criteria required to pass $loTitle?';
        if (!seenFronts.contains(front3.toLowerCase())) {
          seenFronts.add(front3.toLowerCase());
          final choices = [performanceCriteria, 'Attendance without demonstration', 'Unverified theoretical submission', 'Standard waiver criteria']..shuffle();
          final cIdx = choices.indexOf(performanceCriteria);
          cards.add({
            'lo_id': loId,
            'topic_id': topicId,
            'card_type': 'qa',
            'front_text': front3,
            'back_text': performanceCriteria,
            'options_json': jsonEncode(choices.asMap().entries.map((e) => '${String.fromCharCode(65 + e.key)}: ${e.value}').toList()),
            'correct_option': String.fromCharCode(65 + cIdx),
            'explanation': 'Criteria required for mastery and certification.',
            'source_snippet': 'Performance Assessment Standard',
            'is_mastered': 0,
            'review_count': 0,
          });
        }
      }
    }

    return cards;
  }

  // ── Helper Heuristics: Definition Extraction ──
  static List<Map<String, String>> _extractDefinitions(String text, String sourceTitle) {
    final List<Map<String, String>> results = [];
    final lines = text.split('\n');

    for (final line in lines) {
      final clean = line.trim();
      if (clean.isEmpty) continue;

      // Pattern 1: **Term**: Definition or Term: Definition
      final colonMatch = RegExp(r'^(\*{0,2}[A-Za-z0-9\s\-_/]{2,40}\*{0,2})\s*:\s*(.+)$').firstMatch(clean);
      if (colonMatch != null) {
        final term = colonMatch.group(1)!.replaceAll('*', '').trim();
        final def = colonMatch.group(2)!.trim();
        if (term.length >= 3 && def.length >= 8 && !term.toLowerCase().startsWith('http')) {
          results.add({
            'front': 'What is $term?',
            'back': def,
          });
          continue;
        }
      }

      // Pattern 2: Term - Definition
      final dashMatch = RegExp(r'^(\*{0,2}[A-Za-z0-9\s\-_/]{2,40}\*{0,2})\s*[-–—]\s*(.+)$').firstMatch(clean);
      if (dashMatch != null) {
        final term = dashMatch.group(1)!.replaceAll('*', '').trim();
        final def = dashMatch.group(2)!.trim();
        if (term.length >= 3 && def.length >= 8 && !term.toLowerCase().startsWith('http')) {
          results.add({
            'front': 'What is $term?',
            'back': def,
          });
          continue;
        }
      }

      // Pattern 3: "X is defined as Y" or "X refers to Y"
      final isDefinedAsMatch = RegExp(r'^([A-Z][A-Za-z0-9\s]{2,35})\s+(?:is defined as|refers to|is a|is an)\s+(.+)$', caseSensitive: false).firstMatch(clean);
      if (isDefinedAsMatch != null) {
        final term = isDefinedAsMatch.group(1)!.trim();
        final def = clean;
        if (term.length >= 3) {
          results.add({
            'front': 'Define: $term',
            'back': def,
          });
        }
      }
    }

    return results;
  }

  // ── Helper Heuristics: Bullet Points & List Items ──
  static List<Map<String, String>> _extractBulletTakeaways(String text, String sourceTitle) {
    final List<Map<String, String>> results = [];
    final lines = text.split('\n');
    String? currentHeading;

    for (final line in lines) {
      final clean = line.trim();
      if (clean.isEmpty) continue;

      // Track section headings (e.g. ## Key Features)
      if (clean.startsWith('#')) {
        currentHeading = clean.replaceAll('#', '').trim();
        continue;
      }

      // Detect bullet points: *, -, •, or 1., 2.
      final bulletMatch = RegExp(r'^(?:[*•\-]|\d+\.)\s+(.+)$').firstMatch(clean);
      if (bulletMatch != null) {
        final itemText = bulletMatch.group(1)!.trim();
        if (itemText.length >= 12 && itemText.length <= 250) {
          final prompt = currentHeading != null
              ? 'Key takeaway under "$currentHeading":'
              : 'Recall key point from "$sourceTitle":';

          results.add({
            'front': prompt,
            'back': itemText,
          });
        }
      }
    }

    return results;
  }
}
