import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class QuizScreen extends StatefulWidget {
  final String quizId;

  const QuizScreen({super.key, required this.quizId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _state = 0; // 0: intro, 1: active, 2: results
  int _score = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Assessment', style: TextStyle(color: AppTheme.text)),
        backgroundColor: AppTheme.background,
        iconTheme: const IconThemeData(color: AppTheme.text),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case 0:
        return _buildIntro();
      case 1:
        return _buildActive();
      case 2:
        return _buildResults();
      default:
        return const SizedBox();
    }
  }

  Widget _buildIntro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment, size: 80, color: AppTheme.primary),
            const SizedBox(height: 24),
            const Text(
              'Module 1 Assessment',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
            const SizedBox(height: 16),
            const Text(
              'This quiz consists of 10 questions. You must score at least 70% to pass.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => setState(() => _state = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Start Quiz', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActive() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Question 1 of 10',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            const Text(
              'What is the primary language used in Flutter?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            _buildAnswerOption('A. Kotlin'),
            const SizedBox(height: 12),
            _buildAnswerOption('B. Swift'),
            const SizedBox(height: 12),
            _buildAnswerOption('C. Dart', isCorrect: true),
            const SizedBox(height: 12),
            _buildAnswerOption('D. JavaScript'),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerOption(String text, {bool isCorrect = false}) {
    return InkWell(
      onTap: () {
        if (isCorrect) _score++;
        setState(() => _state = 2);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(text, style: const TextStyle(color: AppTheme.text)),
      ),
    );
  }

  Widget _buildResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: AppTheme.success),
            const SizedBox(height: 24),
            const Text(
              'Assessment Completed',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
            const SizedBox(height: 16),
            Text(
              'You scored $_score / 1',
              style: const TextStyle(fontSize: 18, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Return to Course', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
