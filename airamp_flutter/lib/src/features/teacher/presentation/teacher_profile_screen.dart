import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/otp_verification_dialog.dart';
import '../../../core/components/skeleton_loader.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../data/teacher_repository.dart';

class TeacherProfileScreen extends ConsumerStatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  ConsumerState<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen> {
  bool _isEditing = false;
  bool _showPasswordForm = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSavingPassword = false;
  final GlobalKey _passwordSectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');

    _newPasswordController.addListener(_onPasswordFieldsChanged);
    _confirmPasswordController.addListener(_onPasswordFieldsChanged);

    if (user?.mustChangePassword == true) {
      _showPasswordForm = true;
    }
  }

  void _onPasswordFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onPasswordFieldsChanged);
    _confirmPasswordController.removeListener(_onPasswordFieldsChanged);
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
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
      body: PopScope(
        canPop: !currentUser.mustChangePassword,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _showMustChangePasswordBackAlert(isTeacher: true);
        },
        child: currentUser.mustChangePassword
            ? _buildMandatoryPasswordChangeView(currentUser)
            : SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            child: Column(
              children: [
                if (!currentUser.mustChangePassword && context.canPop()) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: AppTheme.text),
                        tooltip: 'Back',
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Profile & Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _buildAvatarSection(currentUser, initial),
                const SizedBox(height: 20),
                _buildAppearanceCard(themeState),
                const SizedBox(height: 16),
                _buildPersonalInfoCard(currentUser),
                const SizedBox(height: 16),
                _buildChangePasswordCard(currentUser),
                const SizedBox(height: 16),
                _buildTeachingInfoCard(ref.watch(teacherSubjectsProvider)),
                const SizedBox(height: 24),
                _buildSignOutButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(User currentUser, String initial) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Image picker will be integrated with image_picker package'), backgroundColor: AppTheme.accent),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              currentUser.profileImage != null
                  ? CircleAvatar(radius: 45, backgroundImage: NetworkImage(currentUser.profileImage!))
                  : CircleAvatar(radius: 45, backgroundColor: AppTheme.primary, child: Text(initial, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.black))),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle, border: Border.all(color: AppTheme.background, width: 2)),
                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(currentUser.fullName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.text)),
        const SizedBox(height: 2),
        Text('Teacher', style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildAppearanceCard(ThemeState themeState) {
    return _sectionCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Appearance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.text)),
        const SizedBox(height: 8),
        Text('Choose your preferred theme between Light and Dark mode.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4)),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildThemePill(icon: Icons.wb_sunny_outlined, label: 'Light', mode: AppThemeMode.light, isActive: themeState.preference == AppThemeMode.light),
            const SizedBox(width: 12),
            _buildThemePill(icon: Icons.dark_mode, label: 'Dark', mode: AppThemeMode.dark, isActive: themeState.preference == AppThemeMode.dark),
          ],
        ),
        const SizedBox(height: 10),
        Center(child: Text('Current: ${ref.read(themeProvider.notifier).currentModeLabel}', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))),
      ],
    ));
  }

  Widget _buildThemePill({required IconData icon, required String label, required AppThemeMode mode, required bool isActive}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(themeProvider.notifier).setTheme(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : AppTheme.inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? AppTheme.primary : AppTheme.border, width: 1.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: isActive ? Colors.black : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.black : AppTheme.textSecondary)),
          ]),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard(User currentUser) {
    return _sectionCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Personal Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.text)),
            if (!_isEditing)
              GestureDetector(
                onTap: () => setState(() => _isEditing = true),
                child: Row(children: [Icon(Icons.edit, size: 14, color: AppTheme.primary), const SizedBox(width: 4), Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.primary))]),
              )
            else
              GestureDetector(
                onTap: _handleSaveProfile,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.save, size: 14, color: Colors.black), SizedBox(width: 4), Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black))])),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildFieldRow(icon: Icons.person_outline, label: 'Full Name', value: currentUser.fullName, controller: _fullNameController, isEditing: _isEditing, showBorder: true),
        _buildFieldRow(icon: Icons.person_outline, label: 'Username', value: currentUser.username, controller: _usernameController, isEditing: _isEditing, showBorder: true),
        _buildFieldRow(icon: Icons.email_outlined, label: 'Email', value: currentUser.email, controller: _emailController, isEditing: _isEditing, showBorder: false, keyboardType: TextInputType.emailAddress),
      ],
    ));
  }

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
                          'For your security, set a new password before accessing classes and faculty tools.',
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

  Widget _buildTeachingInfoCard(List<Map<String, dynamic>> subjects) {
    return _sectionCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Teaching Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.text)),
        const SizedBox(height: 12),
        if (subjects.isEmpty)
          Text('No subjects assigned yet.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted))
        else
          ...subjects.take(3).map((sub) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [Icon(Icons.menu_book, size: 16, color: AppTheme.primary), const SizedBox(width: 8), Text('${sub['name'] ?? 'Subject'} (${sub['subject_code'] ?? ''})', style: TextStyle(fontSize: 13, color: AppTheme.text))]),
              )),
        if (subjects.length > 3)
          Text('+${subjects.length - 3} more', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      ],
    ));
  }

  Widget _buildFieldRow({required IconData icon, required String label, required String value, required TextEditingController controller, required bool isEditing, required bool showBorder, TextInputType keyboardType = TextInputType.text, int? maxLength}) {
    final int effectiveLimit = maxLength ?? (
      label.toLowerCase().contains('phone') ? 15 :
      label.toLowerCase().contains('user') ? 30 :
      label.toLowerCase().contains('email') ? 50 : 50
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showBorder ? Border(bottom: BorderSide(color: AppTheme.border, width: 1)) : null,
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
                Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 2),
                if (isEditing)
                  TextField(
                    controller: controller,
                    maxLength: effectiveLimit,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    keyboardType: keyboardType,
                    style: TextStyle(color: AppTheme.text, fontSize: 15),
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      filled: true,
                      fillColor: AppTheme.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  )
                else
                  Text(value, style: TextStyle(color: AppTheme.text, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(width: double.infinity, child: GestureDetector(onTap: _handleLogout, child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: AppTheme.errorSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.error.withValues(alpha: 0.19), width: 1)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout, size: 18, color: AppTheme.error), const SizedBox(width: 8), Text('Sign Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.error))]))));
  }

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
        purpose: 'Faculty Email Update',
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
            purpose: 'Faculty Email Update',
          );
          return res.success;
        },
      );

      if (verified != true) {
        _emailController.text = user.email;
        return;
      }
    }

    await ref.read(authProvider.notifier).updateProfile(fullName: fullName, username: username, email: email);
    setState(() => _isEditing = false);
    if (!mounted) return;
    _showAlert(
      'Success',
      isEmailChanged ? 'Email verified and profile updated successfully!' : 'Profile updated successfully!',
    );
  }

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
    if (user == null) {
      _showAlert('Error', 'Teacher account session not found.');
      return;
    }

    // MANDATORY FIRST-TIME PASSWORD CHANGE: INSTANT UPDATE WITHOUT OTP!
    if (user.mustChangePassword) {
      setState(() => _isSavingPassword = true);
      try {
        await ref.read(authProvider.notifier).updateProfile(password: newPass);
        if (!mounted) return;
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _showSuccessUnlockedDialog(isTeacher: true);
      } catch (e) {
        if (!mounted) return;
        _showAlert('Error', 'Failed to update password: $e');
      } finally {
        if (mounted) setState(() => _isSavingPassword = false);
      }
      return;
    }

    if (user.email.isEmpty) {
      _showAlert('Error', 'Teacher account or email could not be determined.');
      return;
    }

    // Show sending progress indicator for voluntary password change
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

    // Prompt teacher for OTP verification
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
        _showSuccessUnlockedDialog(isTeacher: true);
      } else {
        _showAlert('Success', 'Password changed successfully!');
      }
    }
  }

  void _showMustChangePasswordBackAlert({required bool isTeacher}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Password Required',
                style: TextStyle(
                  color: AppTheme.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'For your account security, you must set a new password before you can use AIRAMP. You cannot go back or access courses until this step is completed.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleLogout();
            },
            child: Text(
              'Sign Out',
              style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Set Password Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  MANDATORY PASSWORD CHANGE VIEW (Unskippable First-Login)
  // ═══════════════════════════════════════════════════════════
  Widget _buildMandatoryPasswordChangeView(User currentUser) {
    final isDark = AppTheme.isDark;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;
    final hasMinLength = newPass.length >= 6;
    final doPasswordsMatch = newPass.isNotEmpty && newPass == confirmPass;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Glowing Security Shield
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.amber.shade400,
                        const Color(0xFFFF8F00),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.35),
                        blurRadius: 22,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_reset_rounded,
                      size: 42,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Password Change Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),

                // Personalized welcome & security notice
                Text(
                  'Welcome to AIRAMP, ${currentUser.fullName}!\nThis is a new account with a temporary password. You must set your personal password immediately to unlock your teaching dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.amberAccent.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // New Password Field
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        style: TextStyle(color: AppTheme.text, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter new password',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.accent, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                          ),
                          filled: true,
                          fillColor: AppTheme.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Confirm New Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Confirm Password Field
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: TextStyle(color: AppTheme.text, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Re-enter new password',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          prefixIcon: Icon(Icons.lock_clock_outlined, color: AppTheme.accent, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                          filled: true,
                          fillColor: AppTheme.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Criteria checklist
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildRequirementRow(
                              text: 'At least 6 characters',
                              isMet: hasMinLength,
                            ),
                            const SizedBox(height: 6),
                            _buildRequirementRow(
                              text: 'Passwords match',
                              isMet: doPasswordsMatch,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit Button (Instant save)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSavingPassword ? null : _handleChangePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade400,
                            foregroundColor: Colors.black,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSavingPassword
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.black),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Save Password & Unlock Account',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sign Out Option
                TextButton.icon(
                  onPressed: _handleLogout,
                  icon: Icon(Icons.logout_rounded, size: 18, color: AppTheme.error),
                  label: Text(
                    'Sign out to switch account',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
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

  Widget _buildRequirementRow({required String text, required bool isMet}) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: isMet ? Colors.greenAccent : AppTheme.textMuted,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            color: isMet ? AppTheme.text : AppTheme.textMuted,
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
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
                  'Your faculty password has been set successfully. All teacher dashboards, classes, and tools are now fully unlocked.',
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

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(backgroundColor: AppTheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), title: Text('Sign Out', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)), content: Text('Are you sure you want to sign out?', style: TextStyle(color: AppTheme.textSecondary)), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))), TextButton(onPressed: () async { Navigator.of(ctx).pop(); await ref.read(authProvider.notifier).logout(); }, child: Text('Sign Out', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)))]),
    );
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(backgroundColor: AppTheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), title: Text(title, style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)), content: Text(message, style: TextStyle(color: AppTheme.textSecondary)), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK', style: TextStyle(color: AppTheme.primary)))]),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border, width: 1)), child: child);
  }
}
