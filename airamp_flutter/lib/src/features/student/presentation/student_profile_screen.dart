import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/components/auth/required_change_password_dialog.dart';
import '../../../core/components/app_toast.dart';
import '../../../core/components/otp_verification_dialog.dart';
import '../../../core/components/skeleton_loader.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../data/student_repository.dart';
import '../../teacher/data/teacher_schedule_repository.dart';
import 'components/student_schedule_widget.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen>
    with WidgetsBindingObserver {
  bool _isEditing = false;
  bool _showPasswordForm = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSavingPassword = false;
  bool _quizAlerts = true;
  bool _scheduleReminders = true;
  bool _hapticsEnabled = true;
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
    WidgetsBinding.instance.addObserver(this);
    final user = ref.read(authProvider);
    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');

    _newPasswordController.addListener(_onPasswordFieldsChanged);
    _confirmPasswordController.addListener(_onPasswordFieldsChanged);

    if (user?.mustChangePassword == true) {
      _showPasswordForm = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !RequiredChangePasswordDialog.hasSeenInThisSession) {
          RequiredChangePasswordDialog.show(context, isTeacher: false);
        }
      });
    }
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _quizAlerts = prefs.getBool('student_pref_quiz_alerts') ?? true;
          _scheduleReminders = prefs.getBool('student_pref_schedule_reminders') ?? true;
          _hapticsEnabled = prefs.getBool('student_pref_haptics') ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _savePreference(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final user = ref.read(authProvider);
      if (user?.mustChangePassword == true && mounted) {
        RequiredChangePasswordDialog.show(context, isTeacher: false);
      }
    }
  }

  void _onPasswordFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  // ── Image Picker / Profile Photo Info ──
  Future<void> _handlePickImage() async {
    if (!mounted) return;
    AppToast.showInfo(
      context,
      'Profile photo updates are managed by School Admin LIS.',
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

  // ── Change Password (Instant for Mandatory Setup, SMTP OTP for Regular Profile Update) ──
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
      _showAlert('Error', 'User account session not found.');
      return;
    }

    String targetEmail = user.email.trim();
    if (targetEmail.isEmpty) {
      final inputEmail = await _promptForEmailDialog(context);
      if (inputEmail == null || inputEmail.trim().isEmpty) return;
      targetEmail = inputEmail.trim();
      try {
        await ref.read(authProvider.notifier).updateProfile(email: targetEmail);
      } catch (_) {}
    }

    if (!mounted) return;

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
                  'Sending verification code via SMTP to ${OtpService.maskEmail(targetEmail)}...',
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
      email: targetEmail,
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
      email: targetEmail,
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
          email: targetEmail,
          fullName: user.fullName,
          role: user.role,
        );
        return res.success;
      },
    );

    if (verified == true) {
      final wasMustChange = user.mustChangePassword;
      setState(() => _isSavingPassword = true);
      try {
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
      } catch (e) {
        if (!mounted) return;
        _showAlert('Error', 'Failed to update password: $e');
      } finally {
        if (mounted) setState(() => _isSavingPassword = false);
      }
    }
  }

  Future<String?> _promptForEmailDialog(BuildContext context) async {
    final emailCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Email Required',
          style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please enter your email address to receive your 6-digit verification code via SMTP:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: AppTheme.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'example@gmail.com',
                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary, size: 20),
                filled: true,
                fillColor: AppTheme.inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = emailCtrl.text.trim();
              if (text.contains('@') && text.contains('.')) {
                Navigator.of(ctx).pop(text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email address.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Proceed', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.border.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.22),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 26,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to sign out? Your offline lessons and quiz progress will remain safely saved on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: AppTheme.border,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: AppTheme.background.withValues(alpha: 0.5),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await ref.read(authProvider.notifier).logout();
                        },
                        icon: const Icon(
                          Icons.logout_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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

  void _handleBackNavigation() {
    final user = ref.read(authProvider);
    if (user?.mustChangePassword == true) {
      _showMustChangePasswordBackAlert(isTeacher: false);
      return;
    }

    try {
      if (GoRouter.maybeOf(context)?.canPop() == true) {
        context.pop();
        return;
      }
    } catch (_) {}

    try {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
        return;
      }
    } catch (_) {}

    try {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
        return;
      }
    } catch (_) {}

    // Fallback: If stack cannot be popped, navigate directly to student home
    context.go('/student/home');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<User?>(authProvider, (prev, next) {
      if (next?.mustChangePassword == true && !RequiredChangePasswordDialog.hasSeenInThisSession) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            RequiredChangePasswordDialog.show(context, isTeacher: false);
          }
        });
      }
    });

    final currentUser = ref.watch(authProvider);
    final themeState = ref.watch(themeProvider);
    final courses = ref.watch(studentCoursesProvider);
    final quizAssignments = ref.watch(studentQuizAssignmentsProvider);
    final progress = ref.watch(studentProgressProvider);
    final sectionDetails = ref.watch(studentSectionDetailsProvider).value;
    final schedules = (currentUser?.section != null && currentUser!.section!.trim().isNotEmpty)
        ? (ref.watch(sectionSchedulesProvider(currentUser.section!.trim())).value ?? [])
        : <Map<String, dynamic>>[];

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
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: currentUser.mustChangePassword
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppTheme.text),
                tooltip: 'Back to Home',
                onPressed: _handleBackNavigation,
              ),
        title: Text(
          currentUser.mustChangePassword ? 'Security Requirement' : 'Student Profile',
          style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBackNavigation();
        },
        child: currentUser.mustChangePassword
            ? _buildMandatoryPasswordChangeView(currentUser)
            : SafeArea(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // 1. Hero Student Identity Card (Avatar, Badges & 4 Quick KPIs)
                      _buildHeroStudentCard(
                        context: context,
                        currentUser: currentUser,
                        initial: initial,
                        courses: courses,
                        quizAssignments: quizAssignments,
                        progress: progress,
                        schedules: schedules,
                      ),
                      const SizedBox(height: 16),

                      // 2. Academic Standing & Enrolled Courses Card
                      _buildAcademicStandingCard(
                        context: context,
                        courses: courses,
                        sectionDetails: sectionDetails,
                        schedules: schedules,
                        currentUser: currentUser,
                      ),
                      const SizedBox(height: 16),

                      // 3. Personal & Institutional Information Card
                      _buildPersonalInfoCard(currentUser, sectionDetails),
                      const SizedBox(height: 16),

                      // 4. Account Security & Password Management Card
                      _buildChangePasswordCard(currentUser),
                      const SizedBox(height: 16),

                      // 5. Classroom Experience & Preferences Card (Theme & Notifications)
                      _buildPreferencesCard(themeState),
                      const SizedBox(height: 16),

                      // 6. Institutional Support & App Information Card
                      _buildAboutAndSupportCard(context),
                      const SizedBox(height: 24),

                      // 7. Sign Out Button
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
                  'Welcome to AIRAMP, ${currentUser.fullName}!\nThis is a new account with a temporary password. You must set your personal password immediately to unlock your student dashboard and courses.',
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
                      // SMTP Verification Info Badge
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.mark_email_read_rounded,
                                size: 18,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SMTP Email Verification',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentUser.email.isNotEmpty
                                        ? 'A 6-digit code will be sent to ${OtpService.maskEmail(currentUser.email)} via SMTP to verify and unlock your account.'
                                        : 'A 6-digit verification code will be sent via SMTP to verify your account.',
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

  // ═══════════════════════════════════════════════════════════
  //  1. HERO STUDENT IDENTITY CARD (Avatar, Badges & 4 Quick KPIs)
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeroStudentCard({
    required BuildContext context,
    required User currentUser,
    required String initial,
    required List<Map<String, dynamic>> courses,
    required List<Map<String, dynamic>> quizAssignments,
    required Map<String, dynamic> progress,
    required List<Map<String, dynamic>> schedules,
  }) {
    final studentSection = currentUser.section;
    final hasSection = studentSection != null && studentSection.isNotEmpty && studentSection != 'null';
    final studentGrade = currentUser.grade;
    final hasGrade = studentGrade != null && studentGrade.isNotEmpty && studentGrade != 'null';
    final completedLessons = progress['completed'] ?? 0;

    String placementLabel = '';
    if (hasGrade && hasSection) {
      placementLabel = '$studentGrade • $studentSection';
    } else if (hasSection) {
      placementLabel = studentSection;
    } else if (hasGrade) {
      placementLabel = studentGrade;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              children: [
                // Formal Academic Avatar with Subtle Neutral Ring
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.border,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.inputBg,
                        backgroundImage: (currentUser.profileImage != null && currentUser.profileImage!.isNotEmpty)
                            ? NetworkImage(currentUser.profileImage!)
                            : null,
                        child: (currentUser.profileImage == null || currentUser.profileImage!.isEmpty)
                            ? Text(
                                initial,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.text,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: GestureDetector(
                        onTap: _handlePickImage,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.surface, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Full Name
                Text(
                  currentUser.fullName.isNotEmpty ? currentUser.fullName : 'Learner',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),

                // Username / Handle
                Text(
                  '@${currentUser.username}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 12),

                // Formal Institutional Badges (Quiet & Unified)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildBadge(
                      icon: Icons.verified_rounded,
                      label: 'DepEd Verified Learner',
                      iconColor: AppTheme.primary,
                    ),
                    if (placementLabel.isNotEmpty)
                      _buildBadge(
                        icon: Icons.school_outlined,
                        label: placementLabel,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Subtle Divider
          Divider(height: 1, color: AppTheme.border),

          // Clean Workload Metrics Bar (Quiet Icons & High-Contrast Typography)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricStat(
                    context: context,
                    icon: Icons.auto_stories_outlined,
                    count: '${courses.length}',
                    label: 'Subjects',
                    onTap: () => context.push('/student/courses'),
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.border),
                Expanded(
                  child: _buildMetricStat(
                    context: context,
                    icon: Icons.quiz_outlined,
                    count: '${quizAssignments.length}',
                    label: 'Quizzes',
                    onTap: () => context.push('/student/quiz-history'),
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.border),
                Expanded(
                  child: _buildMetricStat(
                    context: context,
                    icon: Icons.task_alt_rounded,
                    count: '$completedLessons',
                    label: 'Completed',
                    onTap: () => context.push('/student/progress'),
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.border),
                Expanded(
                  child: _buildMetricStat(
                    context: context,
                    icon: Icons.calendar_today_outlined,
                    count: '${schedules.length}',
                    label: 'Classes',
                    onTap: () => showStudentTimetableModal(context, sectionName: currentUser.section),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricStat({
    required BuildContext context,
    required IconData icon,
    required String count,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.inputBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor ?? AppTheme.textMuted),
          const SizedBox(width: 4.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  2. ACADEMIC STANDING & ENROLLED SUBJECTS CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildAcademicStandingCard({
    required BuildContext context,
    required List<Map<String, dynamic>> courses,
    required Map<String, dynamic>? sectionDetails,
    required List<Map<String, dynamic>> schedules,
    required User currentUser,
  }) {
    final advisory = (sectionDetails?['adviser_name'] as String?) ??
        (sectionDetails?['adviser'] as String?) ??
        'Designated Faculty';
    final room = (sectionDetails?['room'] as String?) ?? 'Campus Main';
    final track = (sectionDetails?['track'] as String?) ??
        (sectionDetails?['strand'] as String?) ??
        'Junior High School';

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elegant Header without Loud Colored Box
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_stories_outlined, size: 17, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Academic Standing & Subjects',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.push('/student/courses'),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 1),
                      Icon(Icons.chevron_right_rounded, size: 15, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Enrolled Subjects Sub-section
          Text(
            'ENROLLED SUBJECTS (${courses.length})',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          if (courses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                'No subjects currently enrolled. Section allocation is managed by your Class Adviser.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            )
          else
            ...courses.take(3).map((sub) {
              final title = (sub['title'] ?? sub['subject_name'] ?? sub['name'] ?? 'Subject') as String;
              final teacher = (sub['teacher'] ?? sub['teacher_name'] ?? 'Assigned Faculty') as String;

              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 15,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1.5),
                          Text(
                            teacher,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        'Enrolled',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 8),

          // Section & Class Adviser Detail Card (Clean Neutral Spec Table)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _buildSystemSpecRow(label: 'Academic Section', value: currentUser.section ?? 'Grade 10 - Emerald'),
                const SizedBox(height: 6),
                _buildSystemSpecRow(label: 'Class Adviser', value: advisory),
                const SizedBox(height: 6),
                _buildSystemSpecRow(label: 'Home Room / Building', value: room),
                const SizedBox(height: 6),
                _buildSystemSpecRow(label: 'Curricular Track / Strand', value: track),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Open Timetable Action Tile (Subtle & Institutional)
          InkWell(
            onTap: () => showStudentTimetableModal(context, sectionName: currentUser.section),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Class Timetable Schedule',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                          ),
                        ),
                        Text(
                          '${schedules.length} active periods in timetable matrix',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  3. PERSONAL & INSTITUTIONAL INFORMATION CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildPersonalInfoCard(User currentUser, Map<String, dynamic>? sectionDetails) {
    final advisory = (sectionDetails?['adviser_name'] as String?) ??
        (sectionDetails?['adviser'] as String?) ??
        'Designated Faculty';
    final schoolId = (currentUser.schoolId != null && currentUser.schoolId!.isNotEmpty)
        ? currentUser.schoolId!
        : 'sch_main (DepEd Central)';
    final sectionGrade = '${currentUser.grade ?? 'Grade 10'} - ${currentUser.section ?? 'Unassigned'}';

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.badge_outlined, size: 17, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
                  ),
                ],
              ),
              if (!_isEditing)
                GestureDetector(
                  onTap: () => setState(() => _isEditing = true),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: _handleSaveProfile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.text,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check, size: 13, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFieldRow(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: currentUser.fullName,
            controller: _fullNameController,
            isEditing: _isEditing,
            showBorder: true,
          ),
          _buildFieldRow(
            icon: Icons.alternate_email_rounded,
            label: 'Username',
            value: currentUser.username,
            controller: _usernameController,
            isEditing: _isEditing,
            showBorder: true,
          ),
          _buildFieldRow(
            icon: Icons.email_outlined,
            label: 'Email Address (DepEd LIS)',
            value: currentUser.email,
            controller: _emailController,
            isEditing: _isEditing,
            showBorder: true,
            keyboardType: TextInputType.emailAddress,
          ),
          // Institutional non-editable fields
          _buildStaticInfoRow(
            icon: Icons.fingerprint_rounded,
            label: 'Student LRN / Reference ID',
            value: currentUser.id,
            showBorder: true,
          ),
          _buildStaticInfoRow(
            icon: Icons.group_work_outlined,
            label: 'Assigned Section & Grade Level',
            value: sectionGrade,
            showBorder: true,
          ),
          _buildStaticInfoRow(
            icon: Icons.person_pin_rounded,
            label: 'Official Class Adviser',
            value: advisory,
            showBorder: true,
          ),
          _buildStaticInfoRow(
            icon: Icons.apartment_rounded,
            label: 'Institutional Campus / Division ID',
            value: schoolId,
            showBorder: true,
          ),
          _buildStaticInfoRow(
            icon: Icons.security_rounded,
            label: 'System Access Tier',
            value: 'Student / Learner (Level 1 Access)',
            showBorder: false,
          ),
          if (_isEditing) ...[
            const SizedBox(height: 10),
            Text(
              '* Note: Section allocation, grade level, and institutional records are managed by the School LIS Administrator.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStaticInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool showBorder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: showBorder
            ? Border(bottom: BorderSide(color: AppTheme.border, width: 1))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 10),
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
                const SizedBox(height: 1.5),
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 9),
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
            child: Icon(icon, size: 15, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 10),
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
                const SizedBox(height: 1.5),
                if (isEditing)
                  TextField(
                    controller: controller,
                    maxLength: effectiveLimit,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    keyboardType: keyboardType,
                    style: TextStyle(
                        color: AppTheme.text, fontSize: 14),
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      filled: true,
                      fillColor: AppTheme.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide:
                            BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide:
                            BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide:
                            BorderSide(color: AppTheme.text),
                      ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(
                        color: AppTheme.text, fontSize: 13.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  4. ACCOUNT SECURITY & PASSWORD MANAGEMENT CARD
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
                  size: 17,
                  color: isRequired ? Colors.amberAccent : AppTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 14.5,
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
              padding: const EdgeInsets.only(left: 27),
              child: Column(
                children: [
                  // New Password
                  TextField(
                    controller: _newPasswordController,
                    maxLength: 16,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    obscureText: _obscureNewPassword,
                    style: TextStyle(color: AppTheme.text, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'New Password',
                      counterText: '',
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.textMuted,
                          size: 17,
                        ),
                        onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                      ),
                      filled: true,
                      fillColor: AppTheme.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent.withValues(alpha: 0.5) : AppTheme.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent.withValues(alpha: 0.5) : AppTheme.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent : AppTheme.text,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Confirm Password
                  TextField(
                    controller: _confirmPasswordController,
                    maxLength: 16,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    obscureText: _obscureConfirmPassword,
                    style: TextStyle(color: AppTheme.text, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Confirm Password',
                      counterText: '',
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.textMuted,
                          size: 17,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      filled: true,
                      fillColor: AppTheme.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent.withValues(alpha: 0.5) : AppTheme.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent.withValues(alpha: 0.5) : AppTheme.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isRequired ? Colors.amberAccent : AppTheme.text,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Update Password button
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _isSavingPassword ? null : _handleChangePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRequired ? Colors.amber.shade400 : AppTheme.text,
                        foregroundColor: isRequired ? Colors.black : AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: _isSavingPassword
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isRequired ? Icons.lock_open_rounded : Icons.check_circle_outline,
                                  size: 16,
                                  color: isRequired ? Colors.black : AppTheme.surface,
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
  //  5. CLASSROOM EXPERIENCE & PREFERENCES CARD (Appearance)
  // ═══════════════════════════════════════════════════════════
  Widget _buildPreferencesCard(ThemeState themeState) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 17, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choose your preferred theme between Light and Dark mode.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Theme toggle pills (Neutral Segmented Control)
          Row(
            children: [
              _buildThemePill(
                icon: Icons.wb_sunny_outlined,
                label: 'Light',
                mode: AppThemeMode.light,
                isActive: themeState.preference == AppThemeMode.light,
              ),
              const SizedBox(width: 10),
              _buildThemePill(
                icon: Icons.dark_mode_outlined,
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
                fontSize: 11.5,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.border),

          // Preference Toggles (Subtle Neutral)
          _buildToggleRow(
            title: 'Quiz & Assignment Alerts',
            subtitle: 'Get notified when new quizzes and activities are published',
            value: _quizAlerts,
            onChanged: (val) {
              setState(() => _quizAlerts = val);
              _savePreference('student_pref_quiz_alerts', val);
            },
          ),
          Divider(height: 1, color: AppTheme.border),

          _buildToggleRow(
            title: 'Class Schedule Reminders',
            subtitle: 'Receive timely notifications before scheduled class periods start',
            value: _scheduleReminders,
            onChanged: (val) {
              setState(() => _scheduleReminders = val);
              _savePreference('student_pref_schedule_reminders', val);
            },
          ),
          Divider(height: 1, color: AppTheme.border),

          _buildToggleRow(
            title: 'Haptic Touch Feedback',
            subtitle: 'Provide tactile vibration feedback during quiz interactions',
            value: _hapticsEnabled,
            onChanged: (val) {
              setState(() => _hapticsEnabled = val);
              _savePreference('student_pref_haptics', val);
              if (val) HapticFeedback.selectionClick();
            },
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
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.surfaceLight : AppTheme.inputBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppTheme.textSecondary : AppTheme.border,
              width: isActive ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive ? AppTheme.text : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppTheme.text : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppTheme.text,
            activeTrackColor: AppTheme.text.withValues(alpha: 0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  6. INSTITUTIONAL SUPPORT & APP INFORMATION CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildAboutAndSupportCard(BuildContext context) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 17, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Institutional Support & Info',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppTheme.inputBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  'v${AppUpdateService.currentVersion}',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _buildSystemSpecRow(
                  label: 'Software Platform',
                  value: 'AIRAMP DepEd Classroom Suite',
                ),
                const SizedBox(height: 6),
                _buildSystemSpecRow(
                  label: 'App Version',
                  value: 'v${AppUpdateService.currentVersion} (Build 2026.10)',
                ),
                const SizedBox(height: 6),
                _buildSystemSpecRow(
                  label: 'Offline Engine',
                  value: 'SQLite 3.45 + Local Mesh Client',
                ),
                const SizedBox(height: 6),
                _buildSystemSpecRow(
                  label: 'License',
                  value: 'DepEd ICT Educational Program',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Check for Updates Button (Clean Neutral Outline)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.text,
              side: BorderSide(color: AppTheme.border),
              padding: const EdgeInsets.symmetric(vertical: 9),
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => AppUpdateService().promptUpdateIfAvailable(context, showNoUpdateMessage: true),
            icon: Icon(Icons.sync_rounded, size: 15, color: AppTheme.textSecondary),
            label: const Text('Check for Updates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 6),

          InkWell(
            onTap: _showStudentHelpDialog,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Student Quick Help & Offline Guide',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 15, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: AppTheme.border),

          InkWell(
            onTap: _showPrivacyDialog,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.policy_outlined, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data Privacy & DepEd Compliance',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 15, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSpecRow({
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.text,
            ),
          ),
        ),
      ],
    );
  }

  void _showStudentHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Student Guide & Offline Help',
                style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem(
                title: 'Offline Lesson Access',
                desc: 'All course lessons and reading materials are stored locally on your device or streamed from the classroom ESP32 hub without internet.',
              ),
              const SizedBox(height: 10),
              _buildHelpItem(
                title: 'Taking & Submitting Quizzes',
                desc: 'When connected to the classroom AIRAMP-HUB Wi-Fi, your quiz answers submit directly to the teacher. Your scores and attempts appear instantly in Quiz History.',
              ),
              const SizedBox(height: 10),
              _buildHelpItem(
                title: 'Class Timetable',
                desc: 'View your weekly class schedule, subject teachers, and classroom assignments anytime using the Schedule tab on your home screen.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.policy_outlined, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Data Privacy & Compliance',
                style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'AIRAMP complies with Republic Act 10173 (Data Privacy Act of 2012) and DepEd institutional student data protection policies.\n\nAll your grades, quiz responses, and learning progress remain encrypted and private on local classroom hardware.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Understood', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem({required String title, required String desc}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  7. SIGN OUT BUTTON (Clean Neutral Outline)
  // ═══════════════════════════════════════════════════════════
  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _handleLogout,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 16, color: AppTheme.error),
              const SizedBox(width: 8),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 14.5,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
