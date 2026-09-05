import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MyProgressScreen extends StatelessWidget {
  const MyProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Progress', style: TextStyle(color: AppTheme.text)),
        backgroundColor: AppTheme.background,
        iconTheme: const IconThemeData(color: AppTheme.text),
      ),
      body: const Center(
        child: Text('My Progress Content', style: TextStyle(color: AppTheme.text)),
      ),
    );
  }
}
