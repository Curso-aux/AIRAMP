import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class QuizHistoryScreen extends StatelessWidget {
  const QuizHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Quiz History', style: TextStyle(color: AppTheme.text)),
        backgroundColor: AppTheme.background,
        iconTheme: const IconThemeData(color: AppTheme.text),
      ),
      body: const Center(
        child: Text('Quiz History Content', style: TextStyle(color: AppTheme.text)),
      ),
    );
  }
}
