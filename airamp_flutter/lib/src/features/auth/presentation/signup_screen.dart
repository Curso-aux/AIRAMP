import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _step = 1;

  void _nextStep() {
    if (_step < 4) {
      setState(() {
        _step++;
      });
    } else {
      context.go('/student/home');
    }
  }

  void _prevStep() {
    if (_step > 1) {
      setState(() {
        _step--;
      });
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.text),
          onPressed: _prevStep,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _step == 1 ? 'Create Account' 
                : _step == 2 ? 'Select Section & Subjects' 
                : _step == 3 ? 'Invitation Code' : 'Verify Email',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _step == 1 ? 'Join AIRA and start your learning journey'
                : _step == 2 ? 'Choose your section and subjects to enroll in'
                : _step == 3 ? 'Enter the invitation code provided by your instructor'
                : 'Enter the verification code sent to your email',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              
              // Progress indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _step ? AppTheme.primary : AppTheme.border,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              if (_step == 1) ...[
                _buildTextField('Full Name', Icons.person_outline),
                const SizedBox(height: 14),
                _buildTextField('Username', Icons.person_outline),
                const SizedBox(height: 14),
                _buildTextField('Email', Icons.mail_outline),
                const SizedBox(height: 14),
                _buildTextField('Password', Icons.lock_outline, isPassword: true),
                const SizedBox(height: 14),
                _buildTextField('Confirm Password', Icons.lock_outline, isPassword: true),
              ] else if (_step == 2) ...[
                const Text('Mock: Sections and Subjects selection', style: TextStyle(color: AppTheme.text)),
              ] else if (_step == 3) ...[
                _buildTextField('Invitation Code', Icons.tag),
              ] else if (_step == 4) ...[
                _buildTextField('OTP Code', Icons.key),
              ],

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _nextStep,
                child: Text(_step < 4 ? 'Next' : 'Verify & Complete'),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ', style: TextStyle(color: AppTheme.textSecondary)),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Text('Sign In', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, IconData icon, {bool isPassword = false}) {
    return TextField(
      obscureText: isPassword,
      style: const TextStyle(color: AppTheme.text),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.textMuted),
      ),
    );
  }
}
