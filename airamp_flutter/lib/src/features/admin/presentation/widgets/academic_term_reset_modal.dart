import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/firestore_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/application/auth_provider.dart';
import '../../domain/semester_archive_models.dart';
import '../controllers/semester_renewal_controller.dart';

/// Multi-step confirmation dialog safeguarding the semester-end academic reset.
/// Step 1: Impact Warning & Scope Review (requires acknowledgement checkbox).
/// Step 2: Admin Password Re-Authentication (verifies salted SHA-256 password).
/// Step 3: Exact Confirmation Phrase ("CONFIRM SEMESTER RESET") & Purge Execution.
class AcademicTermResetModal extends ConsumerStatefulWidget {
  final String? adminId;
  final String? schoolId;
  final Future<bool> Function(String enteredPassword)? passwordVerifier;

  const AcademicTermResetModal({
    super.key,
    this.adminId,
    this.schoolId,
    this.passwordVerifier,
  });

  @override
  ConsumerState<AcademicTermResetModal> createState() =>
      _AcademicTermResetModalState();
}

class _AcademicTermResetModalState
    extends ConsumerState<AcademicTermResetModal> {
  int _currentStep = 1;

  // Step 1 State
  bool _isAcknowledged = false;

  // Step 1 Term Labels
  final TextEditingController _previousSemesterController =
      TextEditingController(text: '1st Semester AY 2025-2026');
  final TextEditingController _newSemesterController =
      TextEditingController(text: '2nd Semester AY 2025-2026');

  // Step 2 State
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordObscured = true;
  bool _isVerifyingPassword = false;
  String? _passwordError;

  // Step 3 State
  final TextEditingController _confirmationPhraseController =
      TextEditingController();
  static const String _requiredPhrase = 'CONFIRM SEMESTER RESET';

  @override
  void dispose() {
    _previousSemesterController.dispose();
    _newSemesterController.dispose();
    _passwordController.dispose();
    _confirmationPhraseController.dispose();
    super.dispose();
  }

  bool get _isPhraseValid =>
      _confirmationPhraseController.text.trim() == _requiredPhrase;

  Future<void> _verifyAdminPassword() async {
    final enteredPassword = _passwordController.text;
    if (enteredPassword.isEmpty) {
      setState(() {
        _passwordError = 'Please enter your administrator password.';
      });
      return;
    }

    setState(() {
      _isVerifyingPassword = true;
      _passwordError = null;
    });

    try {
      bool isMatch = false;

      // 1. If custom verifier injected (e.g. for mock tests), use it first
      if (widget.passwordVerifier != null) {
        isMatch = await widget.passwordVerifier!(enteredPassword);
      } else {
        // 2. Resolve admin ID from props or authProvider
        final currentUser = ref.read(authProvider);
        final effectiveAdminId = widget.adminId ?? currentUser?.id ?? '';

        String? storedHash;
        String? storedSalt;

        // Query local SQLite for admin credentials
        try {
          final db = await DatabaseHelper().database;
          final rows = await db.query(
            'users',
            where: 'id = ? OR email = ?',
            whereArgs: [effectiveAdminId, effectiveAdminId],
          );
          if (rows.isNotEmpty) {
            storedHash = rows.first['password'] as String?;
            storedSalt = (rows.first['password_salt'] ?? rows.first['salt']) as String?;
          }
        } catch (e) {
          debugPrint('[AcademicTermResetModal] SQLite credentials lookup note: $e');
        }

        // Fallback: Query Cloud Firestore if local hash missing
        if (storedHash == null && FirestoreService().isAvailable) {
          try {
            final cloudUser = await FirestoreService().findUserByIdentifier(effectiveAdminId);
            if (cloudUser != null) {
              storedHash = cloudUser['password'] as String?;
              storedSalt = (cloudUser['password_salt'] ?? cloudUser['salt']) as String?;
            }
          } catch (e) {
            debugPrint('[AcademicTermResetModal] Firestore credentials lookup note: $e');
          }
        }

        if (storedHash != null) {
          isMatch = DatabaseHelper.verifyPassword(enteredPassword, storedHash, storedSalt);
        } else {
          // If no stored hash found in DB, re-authentication cannot succeed
          isMatch = false;
        }
      }

      if (mounted) {
        if (isMatch) {
          setState(() {
            _isVerifyingPassword = false;
            _passwordError = null;
            _currentStep = 3;
          });
        } else {
          setState(() {
            _isVerifyingPassword = false;
            _passwordError =
                'Incorrect administrator password. Re-authentication failed.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingPassword = false;
          _passwordError = 'Authentication error: $e';
        });
      }
    }
  }

  Future<void> _executePurge() async {
    final currentUser = ref.read(authProvider);
    final effectiveAdminId = widget.adminId ?? currentUser?.id ?? 'admin';
    final effectiveSchoolId = widget.schoolId ?? currentUser?.schoolId ?? 'sch_main';

    try {
      await ref.read(semesterRenewalControllerProvider.notifier).executeReset(
            adminId: effectiveAdminId,
            schoolId: effectiveSchoolId,
            previousSemester: _previousSemesterController.text.trim(),
            newSemester: _newSemesterController.text.trim(),
          );
    } catch (e) {
      debugPrint('[AcademicTermResetModal] Purge error note: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final renewalState = ref.watch(semesterRenewalControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppTheme.darkSurfaceElevated : Colors.white;
    final primaryTextColor = isDark ? AppTheme.darkTextBright : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569);
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: renewalState.purgeSummary != null
                ? _buildSuccessView(renewalState.purgeSummary!, isDark, primaryTextColor, secondaryTextColor)
                : _buildStepContent(renewalState, isDark, primaryTextColor, secondaryTextColor, borderColor),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(
    SemesterRenewalState renewalState,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Modal Header & Step Indicator
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'End of Semester Reset',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Step $_currentStep of 3: ${_getStepTitle(_currentStep)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: secondaryTextColor, size: 20),
              onPressed: renewalState.isPurging ? null : () => Navigator.of(context).pop(),
              tooltip: 'Cancel and Close',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Step-Specific Body
        if (_currentStep == 1)
          _buildStep1WarningScope(isDark, primaryTextColor, secondaryTextColor, borderColor)
        else if (_currentStep == 2)
          _buildStep2PasswordReAuth(isDark, primaryTextColor, secondaryTextColor, borderColor)
        else
          _buildStep3PhraseExecution(renewalState, isDark, primaryTextColor, secondaryTextColor, borderColor),

        const SizedBox(height: 16),

        // Bottom Action Buttons
        _buildBottomActions(renewalState),
      ],
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 1:
        return 'Warning & Scope Review';
      case 2:
        return 'Admin Re-Authentication';
      case 3:
        return 'Confirmation Phrase & Execution';
      default:
        return '';
    }
  }

  // ── Step 1: Warning & Scope Review ─────────────────────────────────────────
  Widget _buildStep1WarningScope(
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    return Column(
      key: const Key('step_1_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Please review the scope of data affected by this reset operation. Ensure your institutional records have been archived into .xlsx and .zip before proceeding.',
          style: TextStyle(fontSize: 12.5, height: 1.3, color: secondaryTextColor),
        ),
        const SizedBox(height: 10),

        // Semester Transition Term Inputs
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('previous_semester_field'),
                controller: _previousSemesterController,
                style: TextStyle(fontSize: 12, color: primaryTextColor),
                decoration: InputDecoration(
                  labelText: 'Previous Semester',
                  labelStyle: TextStyle(fontSize: 11, color: secondaryTextColor),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.0),
              child: Icon(Icons.arrow_forward_rounded, size: 16),
            ),
            Expanded(
              child: TextFormField(
                key: const Key('new_semester_field'),
                controller: _newSemesterController,
                style: TextStyle(fontSize: 12, color: primaryTextColor),
                decoration: InputDecoration(
                  labelText: 'New Semester',
                  labelStyle: TextStyle(fontSize: 11, color: secondaryTextColor),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Scope Grid
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              _buildScopeRow(
                icon: Icons.folder_zip_outlined,
                iconColor: Colors.blue.shade700,
                title: 'Data to be Archived into .xlsx / .zip:',
                items: [
                  'Student Personal Info, Demographics & Section Assignments',
                  'Semester Grades, GPA & DepEd Honors Achievements',
                  'Subjects, Assignments & Quizzes with item scores and timestamps',
                ],
                isDark: isDark,
              ),
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 6),
              _buildScopeRow(
                icon: Icons.delete_outline_rounded,
                iconColor: Colors.red,
                title: 'Data to be Permanently Purged:',
                items: [
                  'Subjects and recursive module contents',
                  'Assignments, submissions, quizzes, and quiz attempts',
                  'Term-specific grade logs, student_progress, and learning outcomes',
                ],
                isDark: isDark,
              ),
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 6),
              _buildScopeRow(
                icon: Icons.shield_outlined,
                iconColor: Colors.green,
                title: 'Data Strictly Preserved Intact:',
                items: [
                  'Core user accounts (Students, Teachers, Admins)',
                  'Passwords, authentication credentials, security salts & permissions',
                  'Base profile records (student enrolled subjects reset to 0)',
                ],
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Mandatory Acknowledgement Checkbox
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isAcknowledged
                ? (isDark ? Colors.red.withValues(alpha: 0.12) : const Color(0xFFFEF2F2))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isAcknowledged ? Colors.red.shade400 : borderColor,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                key: const Key('acknowledgement_checkbox'),
                value: _isAcknowledged,
                activeColor: Colors.red.shade700,
                onChanged: (val) {
                  setState(() {
                    _isAcknowledged = val ?? false;
                  });
                },
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAcknowledged = !_isAcknowledged;
                    });
                  },
                  child: Text(
                    'I acknowledge and understand the impact of purging transient academic data.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScopeRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> items,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 3),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: iconColor, fontSize: 11)),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
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
      ],
    );
  }

  // ── Step 2: Admin Password Re-Authentication ───────────────────────────────
  Widget _buildStep2PasswordReAuth(
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    return Column(
      key: const Key('step_2_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_person_outlined, color: Colors.blue.shade600, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Institutional Safeguard: Enter your administrator password to re-authenticate and verify authorization before executing the reset.',
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: secondaryTextColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Administrator Password',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),

        TextFormField(
          key: const Key('admin_password_field'),
          controller: _passwordController,
          obscureText: _isPasswordObscured,
          autofocus: true,
          onFieldSubmitted: (_) => _verifyAdminPassword(),
          decoration: InputDecoration(
            hintText: 'Enter account password',
            prefixIcon: const Icon(Icons.password_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordObscured = !_isPasswordObscured;
                });
              },
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 1.5),
            ),
          ),
        ),

        if (_passwordError != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('password_error_banner'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.shade400),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _passwordError!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Step 3: Confirmation Phrase & Execution ────────────────────────────────
  Widget _buildStep3PhraseExecution(
    SemesterRenewalState renewalState,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    if (renewalState.isPurging) {
      return Padding(
        key: const Key('purge_in_progress_view'),
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Colors.red),
            const SizedBox(height: 20),
            Text(
              'Executing Selective Academic Purge...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deleting transient subjects, quizzes, and grade logs while preserving core user accounts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return Column(
      key: const Key('step_3_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.red, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Final Safeguard: Type the confirmation phrase below exactly as shown to authorize system renewal execution.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Text(
          'Confirmation Phrase',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Type "$_requiredPhrase" (all capital letters):',
          style: TextStyle(fontSize: 12.5, color: secondaryTextColor),
        ),
        const SizedBox(height: 8),

        TextFormField(
          key: const Key('confirmation_phrase_field'),
          controller: _confirmationPhraseController,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: _requiredPhrase,
            prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),

        if (renewalState.errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red),
            ),
            child: Text(
              renewalState.errorMessage!,
              style: const TextStyle(fontSize: 12.5, color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }

  // ── Success Summary View ───────────────────────────────────────────────────
  Widget _buildSuccessView(
    PurgeSummary summary,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Column(
      key: const Key('purge_success_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.green,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'Semester Reset Completed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'System is ready for next academic term enrollment.',
            style: TextStyle(fontSize: 13, color: secondaryTextColor),
          ),
        ),
        const SizedBox(height: 20),

        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildSummaryMetric('Preserved User Accounts', '${summary.preservedUsersCount} accounts intact', Colors.green),
              const Divider(height: 16),
              _buildSummaryMetric('Purged Subjects & Modules', '${summary.deletedSubjectsCount} subjects, ${summary.deletedModulesCount} modules', Colors.red.shade700),
              const Divider(height: 16),
              _buildSummaryMetric('Purged Quizzes & Attempts', '${summary.deletedQuizzesCount} quizzes, ${summary.deletedAttemptsCount} attempts', Colors.red.shade700),
              const Divider(height: 16),
              _buildSummaryMetric('Purged Assignments & Submissions', '${summary.deletedAssignmentsCount} assignments, ${summary.deletedSubmissionsCount} submissions', Colors.red.shade700),
            ],
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          key: const Key('purge_success_close_button'),
          onPressed: () {
            ref.read(semesterRenewalControllerProvider.notifier).resetState();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSummaryMetric(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  // ── Bottom Action Controls ─────────────────────────────────────────────────
  Widget _buildBottomActions(SemesterRenewalState renewalState) {
    if (renewalState.isPurging) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_currentStep > 1) ...[
          OutlinedButton(
            key: const Key('modal_back_button'),
            onPressed: () {
              setState(() {
                _currentStep--;
                _passwordError = null;
              });
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Back'),
          ),
          const SizedBox(width: 12),
        ],

        if (_currentStep == 1)
          ElevatedButton(
            key: const Key('step_1_proceed_button'),
            onPressed: _isAcknowledged
                ? () {
                    setState(() {
                      _currentStep = 2;
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Proceed to Re-Authentication'),
          ),

        if (_currentStep == 2)
          ElevatedButton(
            key: const Key('step_2_verify_button'),
            onPressed: _isVerifyingPassword ? null : _verifyAdminPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isVerifyingPassword
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Verify Password'),
          ),

        if (_currentStep == 3)
          ElevatedButton(
            key: const Key('execute_reset_button'),
            onPressed: _isPhraseValid ? _executePurge : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Execute Semester Reset',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
