import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AdminStudentsScreen extends StatelessWidget {
  const AdminStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background, 
        title: const Text('Manage Students', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)), 
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: AppColors.surfaceLight, child: Icon(Icons.person, color: AppColors.textMuted)),
              title: Text('Student ' + (index + 1).toString(), style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
              subtitle: const Text('Grade 10 - Section A', style: TextStyle(color: AppColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ),
          );
        },
      ),
    );
  }
}
