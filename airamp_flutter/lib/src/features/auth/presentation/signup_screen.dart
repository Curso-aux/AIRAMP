import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../application/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  int _step = 1;
  String _error = '';

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _sectionKeyController = TextEditingController();

  Map<String, dynamic>? _verifiedSectionData;
  bool _isVerifyingKey = false;

  @override
  void initState() {
    super.initState();
    _sectionKeyController.addListener(_onKeyChanged);
  }

  void _onKeyChanged() async {
    final key = _sectionKeyController.text.trim();
    if (key.isEmpty) {
      if (_verifiedSectionData != null && mounted) {
        setState(() => _verifiedSectionData = null);
      }
      return;
    }

    setState(() => _isVerifyingKey = true);
    final verified = await DatabaseHelper().verifySectionKey(key);
    if (!mounted) return;
    setState(() {
      _verifiedSectionData = verified;
      _isVerifyingKey = false;
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _sectionKeyController.removeListener(_onKeyChanged);
    _sectionKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister({bool skipKey = false}) async {
    setState(() => _error = '');

    if (_fullNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'Please fill in all required fields.');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    final key = skipKey ? null : _sectionKeyController.text.trim();

    try {
      await ref.read(authProvider.notifier).register(
            fullName: _fullNameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: 'student',
            username: _usernameController.text.trim().isNotEmpty
                ? _usernameController.text.trim()
                : null,
            sectionCode: (key != null && key.isNotEmpty) ? key : null,
          );
      final user = ref.read(authProvider);
      if (user != null && mounted) {
        context.go('/student/home');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _nextStep() {
    if (_step == 1) {
      // Validate step 1 fields
      if (_fullNameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty ||
          _passwordController.text.isEmpty ||
          _confirmPasswordController.text.isEmpty) {
        setState(() => _error = 'Please fill in all required fields.');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _error = 'Passwords do not match.');
        return;
      }
      setState(() {
        _error = '';
        _step = 2;
      });
    } else {
      _handleRegister();
    }
  }

  void _prevStep() {
    if (_step > 1) {
      setState(() => _step = 1);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: _prevStep,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _step == 1 ? 'Create Account' : 'Classroom Section',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _step == 1
                    ? 'Join AIRA and start your curriculum journey'
                    : 'Enter your Section Enrollment Key provided by your school administrator to automatically assign your classroom room and fixed subjects.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),

              // Progress indicator (2 steps)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(2, (index) {
                  final isActive = index < _step;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 10,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive ? AppTheme.primary : AppTheme.border,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              if (_error.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.errorSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error,
                          style: TextStyle(color: AppTheme.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_step == 1) ...[
                _buildTextField('Full Name', Icons.person_outline, controller: _fullNameController),
                const SizedBox(height: 14),
                _buildTextField('Username (Optional)', Icons.alternate_email, controller: _usernameController),
                const SizedBox(height: 14),
                _buildTextField('Email', Icons.mail_outline, controller: _emailController),
                const SizedBox(height: 14),
                _buildTextField('Password', Icons.lock_outline, isPassword: true, controller: _passwordController),
                const SizedBox(height: 14),
                _buildTextField('Confirm Password', Icons.lock_outline, isPassword: true, controller: _confirmPasswordController),
              ] else ...[
                // Step 2: Classroom Section Enrollment Key
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.vpn_key_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Section Enrollment Key',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _sectionKeyController,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, letterSpacing: 1),
                        decoration: InputDecoration(
                          hintText: 'e.g., SEC-EMR10',
                          prefixIcon: Icon(Icons.key, color: Theme.of(context).colorScheme.primary, size: 20),
                          suffixIcon: _sectionKeyController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => _sectionKeyController.clear(),
                                )
                              : null,
                          isDense: true,
                        ),
                      ),
                      if (_isVerifyingKey) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 8),
                            Text('Verifying key...', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ] else if (_verifiedSectionData != null) ...[
                        const SizedBox(height: 12),
                        Builder(builder: (ctx) {
                          final sec = _verifiedSectionData!['section'] as Map<String, dynamic>;
                          final subjects = (_verifiedSectionData!['subjects'] as List?) ?? [];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Verified: ${sec['name']}',
                                        style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${sec['grade']} • Room: ${sec['room'] ?? 'Main Bldg'} • ${subjects.length} Subjects',
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Quick Sample Keys for Testing:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildQuickKeyChip('SEC-EMR10', 'Grade 10 Emerald'),
                          _buildQuickKeyChip('SEC-STEM11', 'Grade 11 STEM'),
                          _buildQuickKeyChip('SEC-GOLD12', 'Grade 12 Gold'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                child: Text(_step == 1 ? 'Continue to Section Selection' : 'Complete Registration'),
              ),

              if (_step == 2) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _handleRegister(skipKey: true),
                  child: Text(
                    'Skip for now & Enroll Later',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ', style: TextStyle(color: AppTheme.textSecondary)),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text('Sign In', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.pushReplacement('/admin-signup'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_outlined, size: 16, color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text(
                      'Are you a teacher? Register as Teacher',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickKeyChip(String key, String label) {
    return ActionChip(
      avatar: Icon(Icons.key, size: 12, color: Theme.of(context).colorScheme.primary),
      label: Text('$key ($label)'),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
      onPressed: () {
        _sectionKeyController.text = key;
      },
    );
  }

  Widget _buildTextField(String hint, IconData icon, {bool isPassword = false, TextEditingController? controller}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: AppTheme.text),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
      ),
    );
  }
}
