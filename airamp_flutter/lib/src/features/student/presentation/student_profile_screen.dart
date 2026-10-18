import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../../core/components/auth/required_change_password_dialog.dart';
import '../../../core/components/otp_verification_dialog.dart';
import '../../../core/components/skeleton_loader.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/services/app_update_service.dart';
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
  final GlobalKey _passwordSectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

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

    if (user?.mustChangePassword == true) {
      _showPasswordForm = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // If app was reopened / launched directly to profile without passing through login screen
        if (!RequiredChangePasswordDialog.hasSeenInThisSession && mounted) {
          RequiredChangePasswordDialog.show(context, isTeacher: false);
        }
        // Auto-scroll to the change password section with guide highlight
        Future.delayed(const Duration(milliseconds: 350), () {
          if (_passwordSectionKey.currentContext != null) {
            Scrollable.ensureVisible(
              _passwordSectionKey.currentContext!,
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeInOutCubic,
            );
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getRoleLabel(String role) {
    if (role == 'super_admin') return 'Super Administrator';
    if (role == 'admin') return 'Administrator';
    if (role == 'teacher') return 'Teacher';
    return 'Student';
  }

  // ── Image Picker ──
  Future<void> _handlePickImage() async {
    // TODO: Integrate image_picker package when ready
    // For now show a snackbar
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Image picker will be integrated with image_picker package'),
        backgroundColor: AppTheme.accent,
      ),
    );
  }

  // ── Save Profile with OTP verification on Email Change ──
  Future<void> _handleSaveProfile() async {
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    if (fullName.isEmpty || username.isEmpty || email.isEmpty) {
      _showAlert('Error', 'All fields are required.');
      return;
    }

    final user = ref.read(authProvider);
    if (user == null) return;

    final isEmailChanged = email.toLowerCase() != user.email.toLowerCase();

    if (isEmailChanged) {
      // Require OTP verification for new email address
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Sending verification code to $email...',
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final otpResult = await OtpService().requestEmailVerificationOtp(
        targetEmail: email,
        fullName: fullName,
        userId: user.id,
        role: user.role,
        purpose: 'Email Address Update',
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (!otpResult.success) {
        _showAlert('Verification Failed', otpResult.message);
        return;
      }

      final verified = await OtpVerificationDialog.show(
        context: context,
        email: email,
        userId: user.id,
        fullName: fullName,
        role: user.role,
        onVerify: (code) async {
          return await OtpService().verifyOtp(
            identifier: email,
            enteredCode: code,
          );
        },
        onResend: () async {
          final res = await OtpService().requestEmailVerificationOtp(
            targetEmail: email,
            fullName: fullName,
            userId: user.id,
            role: user.role,
            purpose: 'Email Address Update',
          );
          return res.success;
        },
      );

      if (verified != true) {
        _emailController.text = user.email;
        return;
      }
    }

    await ref.read(authProvider.notifier).updateProfile(
          fullName: fullName,
          username: username,
          email: email,
        );

    setState(() => _isEditing = false);
    if (!mounted) return;
    _showAlert(
      'Success',
      isEmailChanged ? 'Email verified and profile updated successfully!' : 'Profile updated successfully!',
    );
  }

  // ── Change Password with SMTP OTP Verification ──
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

    final user = ref.read(authProvider);
    if (user == null || user.email.isEmpty) {
      _showAlert('Error', 'User account or email could not be determined.');
      return;
    }

    // Show sending progress indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Sending verification code to your email...',
                  style: TextStyle(color: AppTheme.text, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final otpResult = await OtpService().requestOtpDirect(
      userId: user.id,
      email: user.email,
      fullName: user.fullName,
      role: user.role,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog

    if (!otpResult.success) {
      _showAlert('Failed to Send Code', otpResult.message);
      return;
    }

    // Prompt user for OTP verification
    final verified = await OtpVerificationDialog.show(
      context: context,
      email: user.email,
      userId: user.id,
      fullName: user.fullName,
      role: user.role,
      onVerify: (otpCode) async {
        return await OtpService().verifyOtp(
          identifier: user.id,
          enteredCode: otpCode,
        );
      },
      onResend: () async {
        final res = await OtpService().requestOtpDirect(
          userId: user.id,
          email: user.email,
          fullName: user.fullName,
          role: user.role,
        );
        return res.success;
      },
    );

    if (verified == true) {
      final wasMustChange = user.mustChangePassword;
      await ref.read(authProvider.notifier).updateProfile(password: newPass);
      if (!mounted) return;
      setState(() => _showPasswordForm = false);
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (wasMustChange) {
        _showSuccessUnlockedDialog(isTeacher: false);
      } else {
        _showAlert('Success', 'Password changed successfully!');
      }
    }
  }

  void _showSuccessUnlockedDialog({required bool isTeacher}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.greenAccent, width: 2),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 38),
                ),
                const SizedBox(height: 16),
                Text(
                  'Account Secured! 🎉',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your personal password has been set successfully. All AIRAMP courses, scanner, and features are now fully unlocked.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.go(isTeacher ? '/teacher/dashboard' : '/student/home');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      isTeacher ? 'Proceed to Dashboard' : 'Proceed to Home',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logout ──
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Sign Out',
          style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
            },
            child: Text('Sign Out',
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
            style: TextStyle(
                color: AppTheme.text, fontWeight: FontWeight.bold)),
        content:
            Text(message, style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                Text('OK', style: TextStyle(color: AppTheme.primary)),
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
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                SkeletonLoader.circle(size: 80),
                SizedBox(height: 16),
                SkeletonLoader(width: 160, height: 20),
                SizedBox(height: 8),
                SkeletonLoader(width: 100, height: 14),
                SizedBox(height: 24),
                SkeletonCard(),
                SkeletonCard(),
              ],
            ),
          ),
        ),
      );
    }

    final initial = currentUser.fullName.isNotEmpty
        ? currentUser.fullName[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        automaticallyImplyLeading: !currentUser.mustChangePassword,
        leading: currentUser.mustChangePassword
            ? null
            : (Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text, size: 20),
                    onPressed: () => context.pop(),
                  )
                : IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text, size: 20),
                    onPressed: () => context.go('/student/home'),
                  )),
        title: Text(
          currentUser.mustChangePassword ? 'Security Setup' : 'Student Profile',
          style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: PopScope(
        canPop: !currentUser.mustChangePassword,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          RequiredChangePasswordDialog.show(context, isTeacher: false);
        },
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
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
                _buildChangePasswordCard(currentUser),
                const SizedBox(height: 16),

                // ── App Updates & Version Card ──
                _buildAppUpdatesCard(),
                const SizedBox(height: 16),

                // ── Sign Out Button ──
                _buildSignOutButton(),
                const SizedBox(height: 40),
              ],
            ),
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
        Text(
          '${currentUser.role == 'teacher' ? 'Teacher' : 'Student'} Activity',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
        ),
        const SizedBox(height: 12),
        Text(
          currentUser.fullName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _getRoleLabel(currentUser.role),
          style: TextStyle(
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
          Text(
            'Appearance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your preferred theme between Light and Dark mode.',
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
              const SizedBox(width: 12),
              _buildThemePill(
                icon: Icons.dark_mode,
                label: 'Dark',
                mode: AppThemeMode.dark,
                isActive: themeState.preference == AppThemeMode.dark,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Current: ${ref.read(themeProvider.notifier).currentModeLabel}',
              style: TextStyle(
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
              Text(
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
                  child: Row(
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
    int? maxLength,
  }) {
    final int effectiveLimit = maxLength ?? (
      label.toLowerCase().contains('phone') ? 15 :
      label.toLowerCase().contains('user') ? 30 :
      label.toLowerCase().contains('email') ? 50 : 50
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showBorder
            ? Border(
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
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                if (isEditing)
                  TextField(
                    controller: controller,
                    maxLength: effectiveLimit,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    keyboardType: keyboardType,
                    style: TextStyle(
                        color: AppTheme.text, fontSize: 15),
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      filled: true,
                      fillColor: AppTheme.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(
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
  // ═══════════════════════════════════════════════════════════
  //  CHANGE PASSWORD CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildChangePasswordCard(User currentUser) {
    final isRequired = currentUser.mustChangePassword;

    return Container(
      key: _passwordSectionKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRequired ? Colors.amberAccent : AppTheme.border,
          width: isRequired ? 2 : 1,
        ),
        boxShadow: isRequired
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.28),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Guide Highlight Banner if password change is required
          if (isRequired) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amberAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber.withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amberAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MANDATORY: CHANGE DEFAULT PASSWORD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'For your security, set a new password before accessing AIRAMP courses and tools.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Toggle row
          GestureDetector(
            onTap: () {
              if (isRequired) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password change is required to unlock your account.'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              setState(() => _showPasswordForm = !_showPasswordForm);
            },
            child: Row(
              children: [
                Icon(
                  isRequired ? Icons.lock_reset_rounded : Icons.lock_outline,
                  size: 18,
                  color: isRequired ? Colors.amberAccent : AppTheme.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.text,
                        ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'Required',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isRequired)
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
          if (_showPasswordForm || isRequired) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Column(
                children: [
                  // New Password
                  TextField(
                    controller: _newPasswordController,
                    maxLength: 16,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    obscureText: true,
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'New Password',
                      counterText: '',
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent.withValues(alpha: 0.5) : AppTheme.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent.withValues(alpha: 0.5) : AppTheme.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent : AppTheme.primary,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Confirm Password
                  TextField(
                    controller: _confirmPasswordController,
                    maxLength: 16,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    obscureText: true,
                    style: TextStyle(color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Confirm Password',
                      counterText: '',
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent.withValues(alpha: 0.5) : AppTheme.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent.withValues(alpha: 0.5) : AppTheme.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent : AppTheme.primary,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Update Password button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _handleChangePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRequired ? Colors.amber.shade400 : AppTheme.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isRequired ? Icons.lock_open_rounded : Icons.check_circle_outline,
                            size: 18,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isRequired
                                ? 'Save Password & Unlock Account'
                                : 'Update Password',
                          ),
                        ],
                      ),
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
  //  APP UPDATES & VERSION CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildAppUpdatesCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.system_update_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Version & Updates',
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'v${AppUpdateService.currentVersion}',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            kIsWeb
                ? 'Hosted on Firebase with automatic PWA synchronization across web, iOS, and Android.'
                : 'Native Android application synchronized with Firebase Cloud infrastructure.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => AppUpdateService().promptUpdateIfAvailable(context, showNoUpdateMessage: true),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Check for Updates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => AppUpdateService.showInstallPwaInstructions(context),
                    icon: const Icon(Icons.phone_iphone_rounded, size: 16),
                    label: const Text('Install App', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
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
          child: Row(
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
