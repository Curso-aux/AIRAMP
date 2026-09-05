import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  int _step = 1;
  String _error = '';
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;

  String _selectedGradeLevel = '';
  String _selectedSectionId = '';
  List<String> _selectedSubjectIds = [];

  final _regCodeCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  void _nextStep() {
    setState(() => _error = '');
    if (_step == 1) {
      if (_fullNameCtrl.text.isEmpty || _usernameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty || _confirmCtrl.text.isEmpty) {
        setState(() => _error = 'Please fill all fields');
        return;
      }
      if (_passwordCtrl.text != _confirmCtrl.text) {
        setState(() => _error = 'Passwords do not match');
        return;
      }
      setState(() => _step = 2);
    } else if (_step == 2) {
      setState(() => _step = 3);
    } else if (_step == 3) {
      setState(() => _step = 4);
    }
  }

  void _prevStep() {
    if (_step > 1) {
      setState(() { _step -= 1; _error = ''; });
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.text),
                onPressed: _prevStep,
              ),
              const SizedBox(height: 16),
              Text(_step == 1 ? 'Create Account' : _step == 2 ? 'Select Section' : _step == 3 ? 'Invitation Code' : 'Verify Email', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text)),
              const SizedBox(height: 8),
              Text('Step  of 4', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              if (_error.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.errorSoft, borderRadius: BorderRadius.circular(8)),
                  child: Text(_error, style: const TextStyle(color: AppColors.error)),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: _buildStepContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    if (_step == 1) {
      return Column(
        children: [
          _buildTextField('Full Name', _fullNameCtrl, Icons.person),
          _buildTextField('Username', _usernameCtrl, Icons.person_outline),
          _buildTextField('Email', _emailCtrl, Icons.email),
          _buildTextField('Password', _passwordCtrl, Icons.lock, obscureText: !_showPassword, toggle: () => setState(() => _showPassword = !_showPassword), isPassword: true),
          _buildTextField('Confirm Password', _confirmCtrl, Icons.lock_outline, obscureText: !_showConfirm, toggle: () => setState(() => _showConfirm = !_showConfirm), isPassword: true),
          const SizedBox(height: 16),
          _buildButton('Next', _nextStep),
        ],
      );
    } else if (_step == 2) {
      return Column(
        children: [
          const Text('Select Grade Level, Section, and Subjects here (UI to be implemented)', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          _buildButton('Next', _nextStep),
        ],
      );
    } else if (_step == 3) {
      return Column(
        children: [
          _buildTextField('Invitation Code', _regCodeCtrl, Icons.numbers),
          const SizedBox(height: 32),
          _buildButton('Verify & Continue', _nextStep),
        ],
      );
    } else {
      return Column(
        children: [
          _buildTextField('6-digit Code', _otpCtrl, Icons.key),
          const SizedBox(height: 32),
          _buildButton('Complete Registration', () {
            context.go('/student');
          }),
        ],
      );
    }
  }

  Widget _buildTextField(String hint, TextEditingController controller, IconData icon, {bool obscureText = false, VoidCallback? toggle, bool isPassword = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: const TextStyle(color: AppColors.textMuted)),
            ),
          ),
          if (isPassword) GestureDetector(onTap: toggle, child: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
