import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_provider.dart';

class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);
    final initial = currentUser?.fullName.isNotEmpty == true
        ? currentUser!.fullName[0].toUpperCase()
        : 'T';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Avatar
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      initial,
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.border, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: AppTheme.primary, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name & Role
              Text(
                currentUser?.fullName ?? 'Teacher John Reyes',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              const SizedBox(height: 4),
              const Text(
                'Administrator',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Appearance Section
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Appearance',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text)),
                    const SizedBox(height: 4),
                    const Text('Choose your preferred theme. Auto follows your system setting.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildThemeChip('Light', Icons.wb_sunny_outlined, false),
                        const SizedBox(width: 8),
                        _buildThemeChip('Dark', Icons.dark_mode, true),
                        const SizedBox(width: 8),
                        _buildThemeChip('Auto', Icons.computer, false),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text('Current: Dark Mode',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Personal Information Section
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Personal Information',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text)),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.edit, size: 16, color: AppTheme.primary),
                          label: const Text('Edit', style: TextStyle(color: AppTheme.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.person_outline, 'Full Name', currentUser?.fullName ?? 'Teacher John Reyes'),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.person_outline, 'Username', currentUser?.fullName ?? 'Teacher John Reyes'),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.email_outlined, 'Email', currentUser?.email ?? 'john.reyes@deped.gov.ph'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Change Password
              _buildCard(
                child: Row(
                  children: const [
                    Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Text('Change Password',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.text)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(authProvider.notifier).logout();
                  },
                  icon: const Icon(Icons.logout, color: AppTheme.error),
                  label: const Text('Sign Out', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }

  static Widget _buildThemeChip(String label, IconData icon, bool isSelected) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.black : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: AppTheme.text, fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }
}
