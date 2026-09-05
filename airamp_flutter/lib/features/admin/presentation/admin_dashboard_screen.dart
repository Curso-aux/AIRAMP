import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Admin Dashboard', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)), elevation: 0),
      body: GridView.count(
        crossAxisCount: 2, padding: const EdgeInsets.all(20), mainAxisSpacing: 16, crossAxisSpacing: 16,
        children: [
          _buildStatCard('Total Students', '124', Icons.people, Colors.blue),
          _buildStatCard('Active Subjects', '8', Icons.class_, Colors.green),
          _buildStatCard('Pending Approvals', '12', Icons.pending_actions, Colors.orange),
          _buildStatCard('Total Quizzes', '45', Icons.quiz, Colors.purple),
        ],
      ),
    );
  }
  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 40), const SizedBox(height: 12),
          Text(count, style: const TextStyle(color: AppColors.text, fontSize: 32, fontWeight: FontWeight.bold)),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
