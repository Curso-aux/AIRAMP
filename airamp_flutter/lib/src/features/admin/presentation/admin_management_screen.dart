import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AdminManagementScreen extends StatelessWidget {
  const AdminManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Management', style: TextStyle(color: AppTheme.text)),
        iconTheme: const IconThemeData(color: AppTheme.text),
      ),
      body: const Center(
        child: Text('Super Admin Tools Content', style: TextStyle(color: AppTheme.text)),
      ),
    );
  }
}
