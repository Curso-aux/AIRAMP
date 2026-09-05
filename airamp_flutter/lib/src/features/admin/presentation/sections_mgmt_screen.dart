import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SectionsMgmtScreen extends StatelessWidget {
  const SectionsMgmtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Sections Management', style: TextStyle(color: AppTheme.text)),
        backgroundColor: AppTheme.background,
        iconTheme: const IconThemeData(color: AppTheme.text),
      ),
      body: const Center(
        child: Text('Sections Management Content', style: TextStyle(color: AppTheme.text)),
      ),
    );
  }
}
