/// Psychometric Item Analysis Domain Models for Teacher Quiz Assessments.
/// Aligned with standard educational assessment guidelines (DepEd/CHED/Ebel & Frisbie).
library;

enum ItemAction {
  retain,
  reviseDistractor,
  reviseStem,
  checkKey,
  discard,
}

class ItemAnalysisReport {
  final int quizId;
  final String quizTitle;
  final String subjectName;
  final String subjectCode;
  final int totalQuestions;
  final int totalAttempts;
  final double passingScore;
  final double meanScore;
  final double medianScore;
  final double passRate;
  final double? kr20Reliability;
  final String reliabilityRating;
  final double meanDifficulty;
  final double meanDiscrimination;
  final int retainCount;
  final int reviseCount;
  final int discardCount;
  final int checkKeyCount;
  final List<QuestionItemAnalysis> questions;

  const ItemAnalysisReport({
    required this.quizId,
    required this.quizTitle,
    required this.subjectName,
    required this.subjectCode,
    required this.totalQuestions,
    required this.totalAttempts,
    required this.passingScore,
    required this.meanScore,
    required this.medianScore,
    required this.passRate,
    this.kr20Reliability,
    required this.reliabilityRating,
    required this.meanDifficulty,
    required this.meanDiscrimination,
    required this.retainCount,
    required this.reviseCount,
    required this.discardCount,
    required this.checkKeyCount,
    required this.questions,
  });

  bool get hasAttempts => totalAttempts > 0;
  bool get isSmallSample => totalAttempts > 0 && totalAttempts < 5;

  factory ItemAnalysisReport.empty({
    required int quizId,
    required String quizTitle,
    String subjectName = '',
    String subjectCode = '',
    int totalQuestions = 0,
    double passingScore = 70.0,
  }) {
    return ItemAnalysisReport(
      quizId: quizId,
      quizTitle: quizTitle,
      subjectName: subjectName,
      subjectCode: subjectCode,
      totalQuestions: totalQuestions,
      totalAttempts: 0,
      passingScore: passingScore,
      meanScore: 0.0,
      medianScore: 0.0,
      passRate: 0.0,
      kr20Reliability: null,
      reliabilityRating: 'No Data',
      meanDifficulty: 0.0,
      meanDiscrimination: 0.0,
      retainCount: 0,
      reviseCount: 0,
      discardCount: 0,
      checkKeyCount: 0,
      questions: const [],
    );
  }
}

class QuestionItemAnalysis {
  final int index; // 1-indexed display order
  final int questionId;
  final String questionText;
  final String correctOption; // 'A', 'B', 'C', 'D'
  final Map<String, String> optionTexts;
  final Map<String, int> totalSelections; // 'A': 12, 'B': 2, etc.
  final Map<String, double> selectionPercentages; // 'A': 60.0, 'B': 10.0, etc.
  final Map<String, int> upperGroupSelections;
  final Map<String, int> lowerGroupSelections;
  final int skippedCount;
  final int totalRespondents;
  final double difficultyIndex; // p value (0.0 to 1.0)
  final String difficultyLabel; // Very Difficult, Difficult, Moderate, Easy, Very Easy
  final double discriminationIndex; // D value (-1.0 to 1.0)
  final String discriminationLabel; // Very Good, Reasonably Good, Marginal, Poor, Defective
  final ItemAction recommendation;
  final String recommendationLabel;
  final List<String> distractorWarnings;
  final String pedagogicalAdvice;

  const QuestionItemAnalysis({
    required this.index,
    required this.questionId,
    required this.questionText,
    required this.correctOption,
    required this.optionTexts,
    required this.totalSelections,
    required this.selectionPercentages,
    required this.upperGroupSelections,
    required this.lowerGroupSelections,
    required this.skippedCount,
    required this.totalRespondents,
    required this.difficultyIndex,
    required this.difficultyLabel,
    required this.discriminationIndex,
    required this.discriminationLabel,
    required this.recommendation,
    required this.recommendationLabel,
    required this.distractorWarnings,
    required this.pedagogicalAdvice,
  });

  bool get isNeedsAttention =>
      recommendation != ItemAction.retain;
}
