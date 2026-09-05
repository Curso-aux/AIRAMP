import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class RegLinksScreen extends StatelessWidget {
  const RegLinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Registration Links', style: TextStyle(color: AppTheme.text)),
        backgroundColor: AppTheme.background,
        iconTheme: const IconThemeData(color: AppTheme.text),
      ),
      body: const Center(
        child: Text('Registration Links Content', style: TextStyle(color: AppTheme.text)),
      ),
    );
  }
}
