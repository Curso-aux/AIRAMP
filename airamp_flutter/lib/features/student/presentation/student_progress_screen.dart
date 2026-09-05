import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class StudentProgressScreen extends StatelessWidget {
  const StudentProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Progress', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)), elevation: 0),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subject ' + (index + 1).toString(), style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const LinearProgressIndicator(value: 0.6, backgroundColor: AppColors.surfaceLight, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
                const SizedBox(height: 8),
                const Text('60% Completed', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }
}
