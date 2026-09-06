import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class StudentChatScreen extends StatelessWidget {
  const StudentChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Chats',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        itemBuilder: (context, index) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: AppColors.surfaceLight,
              child: Icon(Icons.person, color: AppColors.textMuted),
            ),
            title: Text(
              'Instructor ${index + 1}',
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Do not forget your assignment.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Text(
              '10:42 AM',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}
