import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Admin Dashboard', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                      Text(
                        currentUser?.fullName ?? 'Admin',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: AppTheme.error),
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                    },
                  )
                ],
              ),
              const SizedBox(height: 32),
              
              // Placeholder Dashboard Cards
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildDashboardCard('Subjects', Icons.book, '12 Active'),
                    _buildDashboardCard('Sections', Icons.group, '5 Sections'),
                    _buildDashboardCard('Students', Icons.person, '124 Enrolled'),
                    _buildDashboardCard('Quizzes', Icons.quiz, '30 Completed'),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(String title, IconData icon, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: AppTheme.primary),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
