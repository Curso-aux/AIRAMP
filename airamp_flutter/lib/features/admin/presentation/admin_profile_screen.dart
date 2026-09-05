import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background, 
        title: const Text('Admin Profile', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(50), border: Border.all(color: AppColors.border, width: 2)),
                  child: const Center(child: Text('T', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black))),
                ),
                const SizedBox(height: 16),
                const Text('Teacher Admin', style: TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('teacher@airamp.edu', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Account Settings'),
          _buildListTile(Icons.person_outline, 'Edit Profile'),
          _buildListTile(Icons.lock_outline, 'Change Password'),
          _buildListTile(Icons.notifications_none, 'Notification Preferences'),
          const SizedBox(height: 24),
          _buildSectionTitle('Teacher Information'),
          _buildListTile(Icons.assignment_ind_outlined, 'Department: Sciences', showArrow: false),
          _buildListTile(Icons.card_membership, 'Invitation Code: AIRA2026', showArrow: false),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildListTile(IconData icon, String title, {bool showArrow = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textMuted),
        title: Text(title, style: const TextStyle(color: AppColors.text)),
        trailing: showArrow ? const Icon(Icons.chevron_right, color: AppColors.textMuted) : null,
      ),
    );
  }
}
