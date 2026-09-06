import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class StudentHistoryScreen extends StatelessWidget {
  const StudentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Quiz History',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 5,
        itemBuilder: (context, index) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: const Icon(Icons.check_circle, color: AppColors.primary),
            ),
            title: Text(
              'Quiz ${index + 1}',
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Passed - Score: 85%',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Text(
              '2 days ago',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}
