import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AdminChatScreen extends StatelessWidget {
  const AdminChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Student Inquiries',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 6,
        itemBuilder: (context, index) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: AppColors.surfaceLight,
              child: Icon(Icons.person, color: AppColors.textMuted),
            ),
            title: Text(
              'Student ${index + 1}',
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Sir, I have a question regarding topic 2.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Text(
              'Yesterday',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}
