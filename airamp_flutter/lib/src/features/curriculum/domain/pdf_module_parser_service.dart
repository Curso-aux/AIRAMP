import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/database/database_helper.dart';
import '../../quiz/domain/module_scanner_service.dart';

/// Detailed result of parsing and importing a PDF module into the subject curriculum.
class PdfModuleParseResult {
  final bool success;
  final String? errorMessage;
  final int? createdSubjectId;
  final String? createdSubjectName;
  final int totalTopicsCreated;
  final int totalLosCreated;
  final int totalContentsCreated;
  final int totalQuestionsCreated;
  final int totalFlashcardsGenerated;
  final List<String> topicTitles;

  const PdfModuleParseResult({
    required this.success,
    this.errorMessage,
    this.createdSubjectId,
    this.createdSubjectName,
    this.totalTopicsCreated = 0,
    this.totalLosCreated = 0,
    this.totalContentsCreated = 0,
    this.totalQuestionsCreated = 0,
    this.totalFlashcardsGenerated = 0,
    this.topicTitles = const [],
  });
}

/// Advanced PDF Module Scanner & Parser Service.
/// Extracts lessons, learning outcomes, lecture reading notes, core definitions,
/// and assessment questions from real-world school, university, and DepEd/CHED curriculum PDFs.
/// Automatically persists the curriculum into SQLite and generates interactive Gizmo flashcards.
class PdfModuleParserService {
  final DatabaseHelper _dbHelper;

  PdfModuleParserService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  /// Creates a new subject from an uploaded PDF module and populates its topics, LOs, and quizzes
  Future<PdfModuleParseResult> createSubjectAndImportPdf({
    required Uint8List pdfBytes,
    required String fileName,
    String? customSubjectName,
    String? subjectCode,
    String? semester,
    String uploadType = 'whole_module',
    String term = 'Prelim',
    void Function(String status, double progress)? onProgress,
  }) async {
    try {
      onProgress?.call('Analyzing PDF module for course creation...', 0.08);

      final db = await _dbHelper.database;
      final nowStr = DateTime.now().toIso8601String();

      // Determine subject name
      String resolvedName = customSubjectName?.trim() ?? '';
      if (resolvedName.isEmpty) {
        final dotIdx = fileName.lastIndexOf('.');
        final cleanName = dotIdx != -1 ? fileName.substring(0, dotIdx) : fileName;
        resolvedName = cleanName
            .replaceAll(RegExp(r'[_+\-]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (resolvedName.isEmpty) {
          resolvedName = 'New Course Subject';
        }
      }

      // Generate or use subject code
      String resolvedCode = subjectCode?.trim() ?? '';
      if (resolvedCode.isEmpty) {
        final words = resolvedName.split(' ').where((w) => w.isNotEmpty).take(3).toList();
        final initials = words.map((w) => w[0].toUpperCase()).join();
        resolvedCode = initials.isNotEmpty ? '$initials-101' : 'SUB-101';
      }

      final subjectId = await db.insert('subjects', {
        'name': resolvedName,
        'subject_code': resolvedCode,
        'description': 'Created from PDF module: $fileName',
        'semester': semester ?? '1st Semester',
        'unlock_type': 'Sequential',
        'created_at': nowStr,
      });

      // Parse topics, LOs, contents, and questions into this new subject
      final importResult = await parseAndImportPdf(
        pdfBytes: pdfBytes,
        fileName: fileName,
        subjectId: subjectId,
        uploadType: uploadType,
        term: term,
        onProgress: onProgress,
      );

      return PdfModuleParseResult(
        success: importResult.success,
        errorMessage: importResult.errorMessage,
        createdSubjectId: subjectId,
        createdSubjectName: resolvedName,
        totalTopicsCreated: importResult.totalTopicsCreated,
        totalLosCreated: importResult.totalLosCreated,
        totalContentsCreated: importResult.totalContentsCreated,
        totalQuestionsCreated: importResult.totalQuestionsCreated,
        totalFlashcardsGenerated: importResult.totalFlashcardsGenerated,
        topicTitles: importResult.topicTitles,
      );
    } catch (e, st) {
      debugPrint('Error in createSubjectAndImportPdf: $e\n$st');
      return PdfModuleParseResult(
        success: false,
        errorMessage: 'Failed to create subject from PDF: $e',
      );
    }
  }

  /// Parse and import a PDF into a subject
  Future<PdfModuleParseResult> parseAndImportPdf({
    required Uint8List pdfBytes,
    required String fileName,
    required int subjectId,
    required String uploadType, // 'topic' or 'whole_module'
    String term = 'Prelim', // 'Prelim', 'Midterm', 'Finals', 'Full Course'
    int? targetTopicId, // Used if appending to an existing topic
    String? customTopicTitle,
    void Function(String status, double progress)? onProgress,
  }) async {
    try {
      // ── Step 1: Extract Text from PDF ──
      onProgress?.call('Extracting text from PDF document...', 0.15);
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      final int pageCount = document.pages.count;
      final String rawText = PdfTextExtractor(document).extractText();
      document.dispose();

      if (rawText.trim().isEmpty || rawText.trim().length < 40) {
        return const PdfModuleParseResult(
          success: false,
          errorMessage:
              'The selected PDF contains no readable text or is a scanned image without OCR text.',
        );
      }

      onProgress?.call('Analyzing curriculum structure & lessons ($pageCount pages)...', 0.35);

      // Clean raw text
      final cleanedText = _cleanPdfText(rawText);

      // ── Step 2: Segment into Topics / Lessons ──
      List<_ParsedTopic> parsedTopics = [];

      if (uploadType == 'topic') {
        // Single Topic Upload
        String title = customTopicTitle?.trim() ?? '';
        if (title.isEmpty) {
          title = _detectSingleTopicTitle(cleanedText, fileName);
        }
        final topicData = _parseTopicContent(
          topicTitle: title,
          bodyText: cleanedText,
          term: term,
          targetTopicId: targetTopicId,
        );
        parsedTopics.add(topicData);
      } else {
        // Whole Module / Term Upload (split into multiple lessons)
        parsedTopics = _splitWholeModuleIntoTopics(cleanedText, term, fileName);
        if (parsedTopics.isEmpty) {
          // Fallback: Treat as one comprehensive topic
          parsedTopics.add(
            _parseTopicContent(
              topicTitle: _detectSingleTopicTitle(cleanedText, fileName),
              bodyText: cleanedText,
              term: term,
            ),
          );
        }
      }

      // ── Step 3: Insert into SQLite Database ──
      onProgress?.call('Persisting structured curriculum to Subject database...', 0.60);
      final db = await _dbHelper.database;
      final nowStr = DateTime.now().toIso8601String();

      int totalTopicsCreated = 0;
      int totalLosCreated = 0;
      int totalContentsCreated = 0;
      int totalQuestionsCreated = 0;
      int totalFlashcardsGenerated = 0;
      final List<String> createdTopicTitles = [];
      final List<int> createdLoIds = [];

      for (int i = 0; i < parsedTopics.length; i++) {
        final parsed = parsedTopics[i];
        int topicId;

        if (parsed.targetTopicId != null && parsed.targetTopicId! > 0) {
          topicId = parsed.targetTopicId!;
        } else {
          // Insert new topic
          final newTopicId = await db.insert('topics', {
            'subject_id': subjectId,
            'title': parsed.title,
            'description': parsed.description,
            'created_at': nowStr,
          });
          topicId = newTopicId;
          totalTopicsCreated++;
        }
        createdTopicTitles.add(parsed.title);

        // Insert Learning Outcomes
        for (final lo in parsed.learningOutcomes) {
          final loId = await db.insert('learning_outcomes', {
            'topic_id': topicId,
            'title': lo.title,
            'description': lo.description,
            'performance_criteria': lo.performanceCriteria,
            'passing_score': 70,
            'created_at': nowStr,
          });
          totalLosCreated++;
          createdLoIds.add(loId);

          // Insert Contents for this LO
          for (final content in lo.contents) {
            await db.insert('contents', {
              'lo_id': loId,
              'content_type': content.contentType,
              'title': content.title,
              'content_data': content.contentData,
              'created_at': nowStr,
            });
            totalContentsCreated++;
          }

          // Insert Questions for this LO
          for (final q in lo.questions) {
            await db.insert('questions', {
              'lo_id': loId,
              'question_text': q.questionText,
              'option_a': q.optionA,
              'option_b': q.optionB,
              'option_c': q.optionC,
              'option_d': q.optionD,
              'correct_option': q.correctOption,
              'created_at': nowStr,
            });
            totalQuestionsCreated++;
          }
        }
      }

      // ── Step 4: Automatically Auto-Enroll All Students ──
      // Guarantees all student devices immediately see this updated/created subject!
      onProgress?.call('Syncing course enrollment for all class students...', 0.80);
      await _dbHelper.autoEnrollAllStudentsInSubject(subjectId);

      // ── Step 5: Automatically Scan & Generate Gizmo Flashcards ──
      onProgress?.call('Generating Gizmo practice flashcards & interactive quizzes...', 0.90);
      final scanner = ModuleScannerService(dbHelper: _dbHelper);

      for (int i = 0; i < createdLoIds.length; i++) {
        final loId = createdLoIds[i];
        final cards = await scanner.scanAndGenerateCards(loId: loId, forceRefresh: true);
        totalFlashcardsGenerated += cards.length;
      }

      onProgress?.call('Completed successfully!', 1.0);

      return PdfModuleParseResult(
        success: true,
        totalTopicsCreated: totalTopicsCreated,
        totalLosCreated: totalLosCreated,
        totalContentsCreated: totalContentsCreated,
        totalQuestionsCreated: totalQuestionsCreated,
        totalFlashcardsGenerated: totalFlashcardsGenerated,
        topicTitles: createdTopicTitles,
      );
    } catch (e, st) {
      debugPrint('Error in PdfModuleParserService.parseAndImportPdf: $e\n$st');
      return PdfModuleParseResult(
        success: false,
        errorMessage: 'Failed to process PDF module: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // TEXT CLEANING & NORMALIZATION
  // ─────────────────────────────────────────────────────────────

  String _cleanPdfText(String text) {
    // 1. Normalize line breaks
    String cleaned = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 2. Remove common header/footer noise
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*Page\s+\d+(\s+of\s+\d+)?\s*$', multiLine: true, caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*\d+\s*(?:/|of|\|)\s*\d+\s*$', multiLine: true, caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*Page\s+\d+\s*$', multiLine: true, caseSensitive: false),
      '',
    );

    // 3. Fix hyphenated word breaks at line ends (e.g. "ana- \nlytics" -> "analytics")
    cleaned = cleaned.replaceAll(RegExp(r'(\b[a-zA-Z]+)-\s*\n\s*([a-zA-Z]+\b)'), r'$1$2');

    // 4. Remove excessive blank lines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return cleaned.trim();
  }

  String _detectSingleTopicTitle(String text, String fileName) {
    final lines = text.split('\n').take(60).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Pattern 1: Same line "Topic 1: Flutter Fundamentals" or "Lesson 1: Intro"
      final sameLineMatch = RegExp(
        r'^(?:(Topic|Module|Chapter|Unit|Lesson|Week|Session|Part))\s*([0-9IVXLCDM]+)?[\s:\.\-–—]+(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (sameLineMatch != null) {
        final rawType = sameLineMatch.group(1) ?? 'Lesson';
        final type = rawType[0].toUpperCase() + rawType.substring(1).toLowerCase();
        final numPart = sameLineMatch.group(2);
        final titlePart = sameLineMatch.group(3)?.trim() ?? '';
        if (titlePart.length > 3) {
          final prefix = numPart != null && numPart.isNotEmpty ? '$type $numPart: ' : '';
          return '$prefix$titlePart';
        }
      }

      // Pattern 2: Two-line "TOPIC 1" then next line "FLUTTER FUNDAMENTALS"
      final twoLineMatch = RegExp(
        r'^(?:(Topic|Module|Chapter|Unit|Lesson|Week|Session|Part))\s*([0-9IVXLCDM]+)?\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      if (twoLineMatch != null && i + 1 < lines.length) {
        final rawType = twoLineMatch.group(1) ?? 'Lesson';
        final type = rawType[0].toUpperCase() + rawType.substring(1).toLowerCase();
        final numPart = twoLineMatch.group(2);
        final nextLine = lines[i + 1].trim();
        if (nextLine.length > 3 && !nextLine.toLowerCase().startsWith('page')) {
          final prefix = numPart != null && numPart.isNotEmpty ? '$type $numPart: ' : '';
          return '$prefix$nextLine';
        }
      }
    }

    // Fallback: Cleaned file name
    final dotIdx = fileName.lastIndexOf('.');
    final baseName = dotIdx != -1 ? fileName.substring(0, dotIdx) : fileName;
    final cleanName = baseName.replaceAll(RegExp(r'[_\-\+]'), ' ').trim();
    if (cleanName.isNotEmpty) {
      return cleanName;
    }

    return 'Uploaded Course Module';
  }

  // ─────────────────────────────────────────────────────────────
  // ADVANCED LESSON & TOPIC SPLITTING
  // ─────────────────────────────────────────────────────────────

  List<_ParsedTopic> _splitWholeModuleIntoTopics(
    String fullText,
    String term,
    String fileName,
  ) {
    final List<_ParsedTopic> result = [];

    // Find all lesson / topic boundary matches
    final List<_HeaderMatch> headerMatches = [];

    final lines = fullText.split('\n');
    int runningCharOffset = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      final lineStart = runningCharOffset;
      runningCharOffset += line.length + 1; // +1 for \n

      if (trimmed.isEmpty) continue;

      // 1. Single-line pattern: "Lesson 1: Introduction to Business Analytics"
      final singleLineMatch = RegExp(
        r'^(?:(TOPIC|MODULE|CHAPTER|UNIT|WEEK|LESSON|SESSION|PART)\s*([0-9IVXLCDM]+)?)[\s:\.\-–—]+([^\n]{3,100})$',
        caseSensitive: false,
      ).firstMatch(trimmed);

      if (singleLineMatch != null) {
        final rawType = singleLineMatch.group(1) ?? 'Lesson';
        final type = rawType[0].toUpperCase() + rawType.substring(1).toLowerCase();
        final numStr = singleLineMatch.group(2) ?? '${headerMatches.length + 1}';
        final rawTitle = singleLineMatch.group(3)?.trim() ?? 'Untitled';

        headerMatches.add(
          _HeaderMatch(
            startIndex: lineStart,
            title: '$type $numStr: $rawTitle',
          ),
        );
        continue;
      }

      // 2. Multi-line pattern: Line 1 = "LESSON 1", Line 2 = "INTRODUCTION TO DATA ANALYTICS"
      final multiLineMatch = RegExp(
        r'^(?:(TOPIC|MODULE|CHAPTER|UNIT|WEEK|LESSON|SESSION|PART)\s*([0-9IVXLCDM]+)?)\s*$',
        caseSensitive: false,
      ).firstMatch(trimmed);

      if (multiLineMatch != null) {
        // Find next non-empty line
        int nextLineIdx = i + 1;
        while (nextLineIdx < lines.length && lines[nextLineIdx].trim().isEmpty) {
          nextLineIdx++;
        }

        if (nextLineIdx < lines.length) {
          final nextLineText = lines[nextLineIdx].trim();
          if (nextLineText.length >= 3 &&
              nextLineText.length <= 100 &&
              !nextLineText.toLowerCase().startsWith('page')) {
            final rawType = multiLineMatch.group(1) ?? 'Lesson';
            final type = rawType[0].toUpperCase() + rawType.substring(1).toLowerCase();
            final numStr = multiLineMatch.group(2) ?? '${headerMatches.length + 1}';

            headerMatches.add(
              _HeaderMatch(
                startIndex: lineStart,
                title: '$type $numStr: $nextLineText',
              ),
            );
            i = nextLineIdx; // Skip to next line
            continue;
          }
        }
      }

      // 3. Numbered chapter sections if no keywords found: "1.0 Overview of ..." or "1. Introduction to ..."
      if (headerMatches.isEmpty || headerMatches.every((h) => h.title.startsWith('Section'))) {
        final numberedSection = RegExp(
          r'^(?:([1-9]\.0|[1-9]\.)\s+([A-Z][^\n]{4,80}))$',
        ).firstMatch(trimmed);

        if (numberedSection != null) {
          final numStr = numberedSection.group(1)?.replaceAll('.', '').trim() ?? '${headerMatches.length + 1}';
          final titleStr = numberedSection.group(2)?.trim() ?? 'Untitled';
          headerMatches.add(
            _HeaderMatch(
              startIndex: lineStart,
              title: 'Lesson $numStr: $titleStr',
            ),
          );
        }
      }
    }

    // If we found at least 2 distinct lessons/topics:
    if (headerMatches.length >= 2) {
      for (int i = 0; i < headerMatches.length; i++) {
        final current = headerMatches[i];
        final start = current.startIndex;
        final end = (i + 1 < headerMatches.length) ? headerMatches[i + 1].startIndex : fullText.length;

        if (end > start) {
          final sectionText = fullText.substring(start, end).trim();
          final termPrefix = (term.isNotEmpty && term.toLowerCase() != 'all') ? '[$term] ' : '';
          final finalTitle = '$termPrefix${current.title}';

          final parsed = _parseTopicContent(
            topicTitle: finalTitle,
            bodyText: sectionText,
            term: term,
          );
          result.add(parsed);
        }
      }
    } else if (headerMatches.length == 1) {
      // 1 single lesson found
      final termPrefix = (term.isNotEmpty && term.toLowerCase() != 'all') ? '[$term] ' : '';
      final finalTitle = '$termPrefix${headerMatches.first.title}';
      result.add(
        _parseTopicContent(
          topicTitle: finalTitle,
          bodyText: fullText,
          term: term,
        ),
      );
    } else {
      // Fallback: Detect single topic title or use file name
      final singleTitle = (term.isNotEmpty && term.toLowerCase() != 'all')
          ? '[$term] ${_detectSingleTopicTitle(fullText, fileName)}'
          : _detectSingleTopicTitle(fullText, fileName);

      result.add(
        _parseTopicContent(
          topicTitle: singleTitle,
          bodyText: fullText,
          term: term,
        ),
      );
    }

    return result;
  }

  // ─────────────────────────────────────────────────────────────
  // LESSON CONTENT, OUTCOMES & QUESTIONS PARSER
  // ─────────────────────────────────────────────────────────────

  _ParsedTopic _parseTopicContent({
    required String topicTitle,
    required String bodyText,
    required String term,
    int? targetTopicId,
  }) {
    // 1. Separate assessment questions from body text
    final questionSplit = _extractQuestionsSection(bodyText);
    final questionsText = questionSplit.questionsText;
    final readingText = questionSplit.remainingText;

    // 2. Extract Learning Outcomes
    final los = _extractLearningOutcomes(readingText, topicTitle);

    // 3. Extract Definitions from reading text
    final definitions = _extractDefinitions(readingText);

    // 4. Extract Questions from PDF Assessment block
    List<_ParsedQuestion> questions = _extractMultipleChoiceQuestions(questionsText);

    // Also check if any multiple choice questions exist in reading text itself
    if (questions.isEmpty) {
      questions.addAll(_extractMultipleChoiceQuestions(readingText));
    }

    // 5. Intelligent Fallback: If questions are missing or fewer than 4, synthesize rich questions!
    if (questions.length < 4) {
      final synthesized = _synthesizeQuestions(
        definitions: definitions,
        learningOutcomes: los,
        topicTitle: topicTitle,
        readingText: readingText,
      );
      questions.addAll(synthesized);
    }

    // 6. Structure Reading Content Sections
    final List<_ParsedContent> contents = [];

    // Main Lecture Reading Material
    final cleanReading = _cleanReadingContent(readingText);
    if (cleanReading.isNotEmpty) {
      contents.add(
        _ParsedContent(
          contentType: 'reading',
          title: 'Lecture Notes & Core Concepts',
          contentData: cleanReading,
        ),
      );
    }

    // Key Terms & Definitions summary sheet
    if (definitions.isNotEmpty) {
      final defSummary = definitions.entries
          .map((e) => '**${e.key}**: ${e.value}')
          .join('\n\n');
      contents.add(
        _ParsedContent(
          contentType: 'text',
          title: 'Key Terms & Core Definitions',
          contentData: defSummary,
        ),
      );
    }

    // 7. Distribute contents and questions across Learning Outcomes
    if (los.isNotEmpty) {
      final primaryLo = los.first;
      primaryLo.contents.addAll(contents);
      primaryLo.questions.addAll(questions);

      // Distribute a slice of questions to secondary LOs so every LO has flashcards
      for (int i = 1; i < los.length; i++) {
        final subLo = los[i];
        if (i < questions.length) {
          subLo.questions.add(questions[i]);
        } else {
          subLo.questions.add(
            _ParsedQuestion(
              questionText: 'What is the primary mastery focus of "${subLo.title}"?',
              optionA: subLo.description,
              optionB: 'Memorizing unrelated theoretical facts without practical application',
              optionC: 'Bypassing compliance verification in system architecture',
              optionD: 'Disregarding core established industry standards',
              correctOption: 'A',
            ),
          );
        }
      }
    }

    // Topic Overview description
    String overview = 'Comprehensive curriculum module covering $topicTitle.';
    final firstP = readingText.split('\n\n').firstWhere(
          (p) =>
              p.trim().length > 35 &&
              !p.toLowerCase().contains('learning outcome') &&
              !p.toLowerCase().contains('objective'),
          orElse: () => '',
        );
    if (firstP.isNotEmpty) {
      overview = firstP.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (overview.length > 250) overview = '${overview.substring(0, 247)}...';
    }

    return _ParsedTopic(
      title: topicTitle,
      description: overview,
      learningOutcomes: los,
      targetTopicId: targetTopicId,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LEARNING OUTCOMES EXTRACTION
  // ─────────────────────────────────────────────────────────────

  List<_ParsedLO> _extractLearningOutcomes(String text, String topicTitle) {
    final List<_ParsedLO> los = [];

    // Search for explicit Learning Outcomes / Objectives block
    final loBlockMatch = RegExp(
      r'(?:learning\s+outcomes?|intended\s+learning\s+outcomes?|objectives?|what\s+i\s+need\s+to\s+know|target\s+competencies?|goals?|by\s+the\s+end\s+of\s+this\s+[^\n]*:?)([\s\S]*?)(?=(?:\n\s*\n\s*(?:lecture|reading|introduction|lesson|discussion|what\s+is\s+it|concept|assessment|review\s+questions?|self[- ]check)|$))',
      caseSensitive: false,
    ).firstMatch(text);

    if (loBlockMatch != null) {
      final block = loBlockMatch.group(1) ?? '';
      final items = RegExp(
        r'(?:(?:LO\s*\d+|Learning\s+Outcome\s*\d+|\d+[\.\)]|[•\-\*▪▫✦–—])\s*([^\n]{10,250}))',
        caseSensitive: false,
      ).allMatches(block);

      int loIndex = 1;
      for (final m in items) {
        final itemText = m.group(1)?.trim() ?? '';
        if (itemText.isNotEmpty && itemText.length > 8) {
          los.add(
            _ParsedLO(
              title: 'LO $loIndex: $itemText',
              description: 'Demonstrate competency in $itemText',
              performanceCriteria: 'Student must score 70% or higher in practice assessments.',
            ),
          );
          loIndex++;
          if (los.length >= 6) break;
        }
      }
    }

    // If no explicit LO block found, synthesize contextual competencies from topic name
    if (los.isEmpty) {
      final cleanTopic = topicTitle
          .replaceAll(RegExp(r'^(?:\[.*?\]\s*)?(?:Lesson|Topic|Module|Chapter)\s*\d*:\s*', caseSensitive: false), '')
          .trim();

      los.add(
        _ParsedLO(
          title: 'LO 1: Conceptual Foundations of $cleanTopic',
          description: 'Understand foundational terminology, architecture, and core principles.',
          performanceCriteria: 'Student accurately identifies and defines foundational concepts.',
        ),
      );
      los.add(
        _ParsedLO(
          title: 'LO 2: Methodologies & Application of $cleanTopic',
          description: 'Apply analytical techniques, frameworks, and problem-solving methodologies.',
          performanceCriteria: 'Student demonstrates ability to evaluate practical scenarios.',
        ),
      );
    }

    return los;
  }

  // ─────────────────────────────────────────────────────────────
  // QUESTIONS & QUIZ EXTRACTION
  // ─────────────────────────────────────────────────────────────

  _QuestionSplitResult _extractQuestionsSection(String text) {
    final match = RegExp(
      r'(?:\n\s*(?:REVIEW\s+QUESTIONS?|SELF[- ]CHECK|ASSESSMENT|PRACTICE\s+QUIZ|QUIZ\s+QUESTIONS?|EVALUATION|TEST\s+YOURSELF|WHAT\s+I\s+CAN\s+DO|CHECK\s+YOUR\s+UNDERSTANDING)[\s:\.\-–—]*\n)([\s\S]*)$',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      final questionsText = match.group(1) ?? '';
      final remainingText = text.substring(0, match.start).trim();
      return _QuestionSplitResult(questionsText: questionsText, remainingText: remainingText);
    }

    return _QuestionSplitResult(questionsText: '', remainingText: text);
  }

  List<_ParsedQuestion> _extractMultipleChoiceQuestions(String questionsText) {
    final List<_ParsedQuestion> result = [];
    if (questionsText.trim().isEmpty) return result;

    // Build answer key lookup if present at the end
    final answerKeyMap = <int, String>{};
    final keyMatches = RegExp(r'(?:Answer|Key)[\s\S]*?(?:(\d+)[\.\:\s]+([A-D]))', caseSensitive: false)
        .allMatches(questionsText);
    for (final km in keyMatches) {
      final num = int.tryParse(km.group(1) ?? '');
      final ans = km.group(2)?.toUpperCase();
      if (num != null && ans != null) {
        answerKeyMap[num] = ans;
      }
    }

    // Regex matching vertical multiple choice questions
    final qBlockRegex = RegExp(
      r'(?:^|\n)\s*(\d+)[\.\)]\s*(.*?)\s*\n+\s*([aA][\.\)\-]\s*.*?)\s*\n+\s*([bB][\.\)\-]\s*.*?)\s*\n+\s*([cC][\.\)\-]\s*.*?)\s*\n+\s*([dD][\.\)\-]\s*.*?)(?=(?:\n+\s*(?:Answer|Key|Correct|Ans)[\s:\-]*([ABCD]))|(?:\n+\s*\d+[\.\)])|$)',
      dotAll: true,
      caseSensitive: false,
    );

    final matches = qBlockRegex.allMatches(questionsText);
    for (final m in matches) {
      final qNum = int.tryParse(m.group(1) ?? '') ?? 0;
      final qPrompt = _cleanSingleLine(m.group(2) ?? '');
      final optA = _stripOptionPrefix(_cleanSingleLine(m.group(3) ?? ''));
      final optB = _stripOptionPrefix(_cleanSingleLine(m.group(4) ?? ''));
      final optC = _stripOptionPrefix(_cleanSingleLine(m.group(5) ?? ''));
      final optD = _stripOptionPrefix(_cleanSingleLine(m.group(6) ?? ''));
      String correct = m.group(7)?.toUpperCase().trim() ?? '';

      if (correct.isEmpty && answerKeyMap.containsKey(qNum)) {
        correct = answerKeyMap[qNum]!;
      }
      if (!['A', 'B', 'C', 'D'].contains(correct)) {
        correct = 'A';
      }

      if (qPrompt.isNotEmpty && optA.isNotEmpty && optB.isNotEmpty) {
        result.add(
          _ParsedQuestion(
            questionText: qPrompt,
            optionA: optA,
            optionB: optB,
            optionC: optC.isNotEmpty ? optC : 'None of the above',
            optionD: optD.isNotEmpty ? optD : 'All of the above',
            correctOption: correct,
          ),
        );
      }
    }

    // Also support inline/horizontal options: "1. What is X? A) Cat B) Dog C) Bird D) Fish"
    if (result.isEmpty) {
      final horizontalRegex = RegExp(
        r'(?:^|\n)\s*(\d+)[\.\)]\s*(.*?)\s*[aA][\.\)]\s*(.*?)\s*[bB][\.\)]\s*(.*?)\s*[cC][\.\)]\s*(.*?)\s*[dD][\.\)]\s*(.*?)(?=(?:\s*(?:Answer|Ans)[\s:\-]*([ABCD]))|(?:\n+\s*\d+[\.\)])|$)',
        caseSensitive: false,
      );

      final hMatches = horizontalRegex.allMatches(questionsText);
      for (final hm in hMatches) {
        final qPrompt = _cleanSingleLine(hm.group(2) ?? '');
        final optA = _cleanSingleLine(hm.group(3) ?? '');
        final optB = _cleanSingleLine(hm.group(4) ?? '');
        final optC = _cleanSingleLine(hm.group(5) ?? '');
        final optD = _cleanSingleLine(hm.group(6) ?? '');
        final correct = hm.group(7)?.toUpperCase().trim() ?? 'A';

        if (qPrompt.isNotEmpty && optA.isNotEmpty && optB.isNotEmpty) {
          result.add(
            _ParsedQuestion(
              questionText: qPrompt,
              optionA: optA,
              optionB: optB,
              optionC: optC.isNotEmpty ? optC : 'None of the above',
              optionD: optD.isNotEmpty ? optD : 'All of the above',
              correctOption: ['A', 'B', 'C', 'D'].contains(correct) ? correct : 'A',
            ),
          );
        }
      }
    }

    return result;
  }

  // ─────────────────────────────────────────────────────────────
  // DEFINITIONS & SMART QUESTION SYNTHESIS
  // ─────────────────────────────────────────────────────────────

  Map<String, String> _extractDefinitions(String text) {
    final Map<String, String> defs = {};

    // Pattern 1: Term : Definition
    final p1 = RegExp(
      r'(?:^|\n)\s*([A-Z][a-zA-Z0-9\s]{2,40})\s*[:—–]\s*([A-Z0-9][^\.\n]{15,280}\.)',
    ).allMatches(text);

    for (final m in p1) {
      final term = m.group(1)?.trim() ?? '';
      final def = m.group(2)?.trim() ?? '';
      if (term.isNotEmpty && def.isNotEmpty && !term.toLowerCase().startsWith('page')) {
        defs[term] = def;
        if (defs.length >= 15) break;
      }
    }

    // Pattern 2: Term is defined as / refers to / means
    if (defs.length < 8) {
      final p2 = RegExp(
        r'(?:^|\n)\s*([A-Z][a-zA-Z0-9\s]{2,40})\s+(?:is\s+defined\s+as|refers\s+to|means|represents)\s+([^\.\n]{15,280}\.)',
        caseSensitive: false,
      ).allMatches(text);

      for (final m in p2) {
        final term = m.group(1)?.trim() ?? '';
        final def = m.group(2)?.trim() ?? '';
        if (term.isNotEmpty && def.isNotEmpty && !defs.containsKey(term)) {
          defs[term] = def;
          if (defs.length >= 15) break;
        }
      }
    }

    // Pattern 3: Bullet points: • Data Analytics: The discipline of...
    if (defs.length < 6) {
      final p3 = RegExp(
        r'[•\-\*▪▫✦]\s*([A-Z][a-zA-Z0-9\s]{2,40})[:—–]\s*([^\.\n]{15,280}\.)',
      ).allMatches(text);

      for (final m in p3) {
        final term = m.group(1)?.trim() ?? '';
        final def = m.group(2)?.trim() ?? '';
        if (term.isNotEmpty && def.isNotEmpty && !defs.containsKey(term)) {
          defs[term] = def;
          if (defs.length >= 15) break;
        }
      }
    }

    return defs;
  }

  /// Synthesizes comprehensive multiple choice practice questions from lesson definitions & text
  List<_ParsedQuestion> _synthesizeQuestions({
    required Map<String, String> definitions,
    required List<_ParsedLO> learningOutcomes,
    required String topicTitle,
    required String readingText,
  }) {
    final List<_ParsedQuestion> questions = [];
    final entries = definitions.entries.toList();
    final rng = Random();

    // 1. Generate questions from definitions
    for (int i = 0; i < entries.length; i++) {
      final current = entries[i];
      final term = current.key;
      final correctDef = current.value;

      final otherDefs = entries.where((e) => e.key != term).map((e) => e.value).toList();
      String distractor1 = otherDefs.isNotEmpty ? otherDefs[0] : 'A non-standard theoretical concept without application';
      String distractor2 = otherDefs.length > 1 ? otherDefs[1] : 'An obsolete legacy method for data serialization';
      String distractor3 = otherDefs.length > 2 ? otherDefs[2] : 'A hardware mechanism for auxiliary bus communication';

      // Type A: "Which concept refers to..."
      final options = [correctDef, distractor1, distractor2, distractor3];
      // Randomize correct option position (A, B, C, or D)
      final correctIndex = rng.nextInt(4);
      final temp = options[0];
      options[0] = options[correctIndex];
      options[correctIndex] = temp;
      final correctLetter = String.fromCharCode('A'.codeUnitAt(0) + correctIndex);

      questions.add(
        _ParsedQuestion(
          questionText: 'Which of the following best defines or describes "$term"?',
          optionA: options[0],
          optionB: options[1],
          optionC: options[2],
          optionD: options[3],
          correctOption: correctLetter,
        ),
      );

      if (questions.length >= 6) break;
    }

    // 2. Generate questions from LO competencies if questions are still under 4
    if (questions.length < 4 && learningOutcomes.isNotEmpty) {
      for (final lo in learningOutcomes) {
        questions.add(
          _ParsedQuestion(
            questionText: 'What is the key competency expected in "${lo.title}"?',
            optionA: lo.description,
            optionB: 'Memorizing unrelated theoretical facts without practical application',
            optionC: 'Bypassing compliance verification in system architecture',
            optionD: 'Disregarding core established industry standards',
            correctOption: 'A',
          ),
        );
        if (questions.length >= 4) break;
      }
    }

    // 3. Fallback: Core Topic Question
    if (questions.isEmpty) {
      questions.add(
        _ParsedQuestion(
          questionText: 'What is the primary subject matter examined in $topicTitle?',
          optionA: 'Core foundational principles, systematic methodologies, and practical applications',
          optionB: 'Unverified conjectures unrelated to modern technical practice',
          optionC: 'Deprecated legacy hardware architectures',
          optionD: 'Purely decorative formatting protocols',
          correctOption: 'A',
        ),
      );
    }

    return questions;
  }

  // ─────────────────────────────────────────────────────────────
  // STRING HELPERS
  // ─────────────────────────────────────────────────────────────

  String _cleanSingleLine(String str) {
    return str.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _stripOptionPrefix(String str) {
    return str.replaceFirst(RegExp(r'^[a-dA-D][\.\)\-:\s]+'), '').trim();
  }

  String _cleanReadingContent(String text) {
    final lines = text.split('\n');
    final cleaned = lines.map((l) => l.trimRight()).join('\n');
    return cleaned.trim();
  }
}

// ─────────────────────────────────────────────────────────────
// PRIVATE DATA MODELS
// ─────────────────────────────────────────────────────────────

class _HeaderMatch {
  final int startIndex;
  final String title;

  _HeaderMatch({required this.startIndex, required this.title});
}

class _ParsedTopic {
  final String title;
  final String description;
  final List<_ParsedLO> learningOutcomes;
  final int? targetTopicId;

  _ParsedTopic({
    required this.title,
    required this.description,
    required this.learningOutcomes,
    this.targetTopicId,
  });
}

class _ParsedLO {
  final String title;
  final String description;
  final String performanceCriteria;
  final List<_ParsedContent> contents = [];
  final List<_ParsedQuestion> questions = [];

  _ParsedLO({
    required this.title,
    required this.description,
    required this.performanceCriteria,
  });
}

class _ParsedContent {
  final String contentType;
  final String title;
  final String contentData;

  _ParsedContent({
    required this.contentType,
    required this.title,
    required this.contentData,
  });
}

class _ParsedQuestion {
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption;

  _ParsedQuestion({
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
  });
}

class _QuestionSplitResult {
  final String questionsText;
  final String remainingText;

  _QuestionSplitResult({
    required this.questionsText,
    required this.remainingText,
  });
}
