import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  bool _isEditing = false;
  bool _showPasswordForm = false;

  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _getRoleLabel(String role) {
    if (role == 'super_admin') return 'Super Administrator';
    if (role == 'admin') return 'Administrator';
    return 'Student';
  }

  // ── Image Picker ──
  Future<void> _handlePickImage() async {
    // TODO: Integrate image_picker package when ready
    // For now show a snackbar
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image picker will be integrated with image_picker package'),
        backgroundColor: AppTheme.accent,
      ),
    );
  }

  // ── Save Profile ──
  Future<void> _handleSaveProfile() async {
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    if (fullName.isEmpty || username.isEmpty || email.isEmpty) {
      _showAlert('Error', 'All fields are required.');
      return;
    }

    await ref.read(authProvider.notifier).updateProfile(
          fullName: fullName,
          username: username,
          email: email,
        );

    setState(() => _isEditing = false);
    if (!mounted) return;
    _showAlert('Success', 'Profile updated successfully!');
  }

  // ── Change Password ──
  Future<void> _handleChangePassword() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.isEmpty || newPass.length < 6) {
      _showAlert('Error', 'Password must be at least 6 characters.');
      return;
    }
    if (newPass != confirmPass) {
      _showAlert('Error', 'Passwords do not match.');
      return;
    }

    await ref.read(authProvider.notifier).updateProfile(password: newPass);

    setState(() => _showPasswordForm = false);
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    if (!mounted) return;
    _showAlert('Success', 'Password changed successfully!');
  }

  // ── Logout ──
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sign Out',
                style: TextStyle(
                    color: AppTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title,
            style: const TextStyle(
                color: AppTheme.text, fontWeight: FontWeight.bold)),
        content:
            Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('OK', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final themeState = ref.watch(themeProvider);

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final initial = currentUser.fullName.isNotEmpty
        ? currentUser.fullName[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Avatar Section ──
              _buildAvatarSection(currentUser, initial),
              const SizedBox(height: 20),

              // ── Appearance / Theme Card ──
              _buildAppearanceCard(themeState),
              const SizedBox(height: 16),

              // ── Personal Information Card ──
              _buildPersonalInfoCard(currentUser),
              const SizedBox(height: 16),

              // ── Change Password Card ──
              _buildChangePasswordCard(),
              const SizedBox(height: 16),

              // ── Sign Out Button ──
              _buildSignOutButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  AVATAR SECTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildAvatarSection(User currentUser, String initial) {
    return Column(
      children: [
        GestureDetector(
          onTap: _handlePickImage,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Avatar circle
              currentUser.profileImage != null
                  ? CircleAvatar(
                      radius: 45,
                      backgroundImage:
                          NetworkImage(currentUser.profileImage!),
                    )
                  : CircleAvatar(
                      radius: 45,
                      backgroundColor: AppTheme.primary,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
              // Camera icon overlay
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppTheme.background, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Activity Timeline
        const Text(
          'Student Activity',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
        ),
        const SizedBox(height: 12),
        Text(
          currentUser.fullName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _getRoleLabel(currentUser.role),
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  APPEARANCE CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildAppearanceCard(ThemeState themeState) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appearance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose your preferred theme. Auto follows your system setting.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Theme toggle pills
          Row(
            children: [
              _buildThemePill(
                icon: Icons.wb_sunny_outlined,
                label: 'Light',
                mode: AppThemeMode.light,
                isActive: themeState.preference == AppThemeMode.light,
              ),
              const SizedBox(width: 8),
              _buildThemePill(
                icon: Icons.dark_mode,
                label: 'Dark',
                mode: AppThemeMode.dark,
                isActive: themeState.preference == AppThemeMode.dark,
              ),
              const SizedBox(width: 8),
              _buildThemePill(
                icon: Icons.computer,
                label: 'Auto',
                mode: AppThemeMode.auto,
                isActive: themeState.preference == AppThemeMode.auto,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Current: ${ref.read(themeProvider.notifier).currentModeLabel}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePill({
    required IconData icon,
    required String label,
    required AppThemeMode mode,
    required bool isActive,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(themeProvider.notifier).setTheme(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : AppTheme.inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? AppTheme.primary : AppTheme.border,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color:
                      isActive ? Colors.black : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      isActive ? Colors.black : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PERSONAL INFORMATION CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildPersonalInfoCard(User currentUser) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Edit/Save button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                ),
              ),
              if (!_isEditing)
                GestureDetector(
                  onTap: () => setState(() => _isEditing = true),
                  child: const Row(
                    children: [
                      Icon(Icons.edit, size: 14, color: AppTheme.primary),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: _handleSaveProfile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.save, size: 14, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Full Name field
          _buildFieldRow(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: currentUser.fullName,
            controller: _fullNameController,
            isEditing: _isEditing,
            showBorder: true,
          ),

          // Username field
          _buildFieldRow(
            icon: Icons.person_outline,
            label: 'Username',
            value: currentUser.username,
            controller: _usernameController,
            isEditing: _isEditing,
            showBorder: true,
          ),

          // Email field
          _buildFieldRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: currentUser.email,
            controller: _emailController,
            isEditing: _isEditing,
            showBorder: false,
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow({
    required IconData icon,
    required String label,
    required String value,
    required TextEditingController controller,
    required bool isEditing,
    required bool showBorder,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(
                bottom: BorderSide(color: AppTheme.border, width: 1))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                if (isEditing)
                  TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: const TextStyle(
                        color: AppTheme.text, fontSize: 15),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      filled: true,
                      fillColor: AppTheme.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: const TextStyle(
                        color: AppTheme.text, fontSize: 15),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CHANGE PASSWORD CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildChangePasswordCard() {
    return _sectionCard(
      child: Column(
        children: [
          // Toggle row
          GestureDetector(
            onTap: () =>
                setState(() => _showPasswordForm = !_showPasswordForm),
            child: Row(
              children: [
                const Icon(Icons.lock_outline,
                    size: 18, color: AppTheme.accent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                ),
                Icon(
                  _showPasswordForm
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),

          // Expandable password form
          if (_showPasswordForm) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Column(
                children: [
                  // New Password
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    style:
                        const TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'New Password',
                      hintStyle:
                          const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Confirm Password
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    style:
                        const TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Confirm Password',
                      hintStyle:
                          const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Update Password button
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _handleChangePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SIGN OUT BUTTON
  // ═══════════════════════════════════════════════════════════
  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _handleLogout,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.errorSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.error.withValues(alpha: 0.19),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 18, color: AppTheme.error),
              SizedBox(width: 8),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SHARED SECTION CARD
  // ═══════════════════════════════════════════════════════════
  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: child,
    );
  }
}
