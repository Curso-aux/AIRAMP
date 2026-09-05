import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SubjectsMgmtScreen extends StatelessWidget {
  const SubjectsMgmtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Subjects Management', style: TextStyle(color: AppTheme.text)),
        backgroundColor: AppTheme.background,
        iconTheme: const IconThemeData(color: AppTheme.text),
      ),
      body: const Center(
        child: Text('Subjects Management Content', style: TextStyle(color: AppTheme.text)),
      ),
    );
  }
}
