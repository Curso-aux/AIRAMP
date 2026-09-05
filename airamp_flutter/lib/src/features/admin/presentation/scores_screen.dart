import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ScoresScreen extends StatelessWidget {
  const ScoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Scores & Progress', style: TextStyle(color: AppTheme.text)),
        backgroundColor: AppTheme.background,
        iconTheme: const IconThemeData(color: AppTheme.text),
      ),
      body: const Center(
        child: Text('Scores Content', style: TextStyle(color: AppTheme.text)),
      ),
    );
  }
}
