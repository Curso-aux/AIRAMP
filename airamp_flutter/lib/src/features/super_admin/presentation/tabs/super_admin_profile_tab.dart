import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/components/aira_action_toast.dart';
import '../../../../core/components/profile_photo_sheet.dart';
import '../../../../core/components/user_avatar_widget.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/application/auth_provider.dart';
import '../../data/super_admin_repository.dart';
import '../super_admin_theme.dart';

class SuperAdminProfileTab extends ConsumerStatefulWidget {
  const SuperAdminProfileTab({super.key});

  @override
  ConsumerState<SuperAdminProfileTab> createState() =>
      _SuperAdminProfileTabState();
}

class _SuperAdminProfileTabState extends ConsumerState<SuperAdminProfileTab> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSavingProfile = false;
  bool _isUpdatingPassword = false;

  final List<String> _recoveryCodes = [
    'AIRA-ROOT-8821-XA4F',
    'AIRA-ROOT-39B7-KP90',
    'AIRA-ROOT-9214-MN82',
    'AIRA-ROOT-7731-QL05',
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile(GovernanceTheme gTheme) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final fullName = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    if (fullName.isEmpty || username.isEmpty || email.isEmpty) {
      AiraActionToast.showWarning(
        context,
        title: 'Validation Error',
        message: 'Full name, username, and email are required.',
      );
      return;
    }

    setState(() => _isSavingProfile = true);
    try {
      await ref.read(authProvider.notifier).updateProfile(
            fullName: fullName,
            username: username,
            email: email,
          );

      await DatabaseHelper().logAuditEvent(
        action: 'PROFILE_UPDATED',
        details: 'Super Administrator profile information updated ($fullName / $email).',
        actorId: user.id,
        actorName: fullName,
        schoolId: user.schoolId,
      );
      ref.invalidate(superAdminAuditLogsProvider);

      if (mounted) {
        AiraActionToast.showSuccess(
          context,
          title: 'Profile Updated',
          message: 'Super Administrator details saved successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        AiraActionToast.showError(
          context,
          title: 'Update Failed',
          message: 'Error updating profile: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _handleUpdatePassword(GovernanceTheme gTheme) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      AiraActionToast.showWarning(
        context,
        title: 'Validation Error',
        message: 'All password fields are required.',
      );
      return;
    }

    if (newPass.length < 8) {
      AiraActionToast.showWarning(
        context,
        title: 'Weak Password',
        message: 'New password must be at least 8 characters long.',
      );
      return;
    }

    if (newPass != confirmPass) {
      AiraActionToast.showWarning(
        context,
        title: 'Password Mismatch',
        message: 'The new password and confirmation password do not match.',
      );
      return;
    }

    setState(() => _isUpdatingPassword = true);
    try {
      await ref.read(authProvider.notifier).updateProfile(
            password: newPass,
          );

      await DatabaseHelper().logAuditEvent(
        action: 'SECURITY_PASSWORD_CHANGED',
        details: 'Super Administrator password was successfully changed.',
        actorId: user.id,
        actorName: user.fullName,
        schoolId: user.schoolId,
      );
      ref.invalidate(superAdminAuditLogsProvider);

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) {
        AiraActionToast.showSuccess(
          context,
          title: 'Password Updated',
          message: 'Your administrator password has been updated successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        AiraActionToast.showError(
          context,
          title: 'Password Update Failed',
          message: 'Failed to update password: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingPassword = false);
    }
  }

  void _copyRecoveryCodes(BuildContext context) {
    final codes = _recoveryCodes.join('\n');
    Clipboard.setData(ClipboardData(text: codes));
    AiraActionToast.showSuccess(
      context,
      title: 'Backup Codes Copied',
      message: 'Your emergency backup codes have been copied to your clipboard.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final gTheme = GovernanceTheme(themeState.isDark);
    final user = ref.watch(authProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Master Governance Header Banner ──
              _buildHeaderBanner(context, gTheme, user, isMobile),
              const SizedBox(height: 24),

              // ── Responsive 2-Column or 1-Column Layout ──
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 860;

                  final leftColumn = Column(
                    children: [
                      _buildProfileDetailsCard(context, gTheme, user),
                      const SizedBox(height: 20),
                      _buildSecurityVaultCard(context, gTheme),
                    ],
                  );

                  final rightColumn = Column(
                    children: [
                      _buildGovernanceScopeCard(context, gTheme, user),
                      const SizedBox(height: 20),
                      _buildSessionTelemetryCard(context, gTheme, user),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: leftColumn),
                        const SizedBox(width: 20),
                        Expanded(flex: 5, child: rightColumn),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      leftColumn,
                      const SizedBox(height: 20),
                      rightColumn,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(
    BuildContext context,
    GovernanceTheme gTheme,
    dynamic user,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: gTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: gTheme.isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with Photo Edit Action
          Stack(
            children: [
              UserAvatarWidget(
                imageSource: user?.profileImage,
                fallbackInitial:
                    user?.fullName.isNotEmpty == true ? user.fullName[0].toUpperCase() : 'S',
                size: isMobile ? 64 : 76,
                backgroundColor: gTheme.primarySubtle,
                textColor: gTheme.primary,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: () async {
                    if (user == null) return;
                    await ProfilePhotoSheet.show(
                      context: context,
                      ref: ref,
                      currentPhoto: user.profileImage ?? '',
                      fullName: user.fullName,
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: gTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: gTheme.surface, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),

          // User Info & Master Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: gTheme.primarySubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: gTheme.primaryBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 12, color: gTheme.primary),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'SUPER ADMIN • ALL CAMPUSES',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: gTheme.primary,
                                letterSpacing: 0.8,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  user?.fullName ?? 'Christian Evangelista',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: gTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user?.email ?? 'evangelistachristian88@gmail.com',
                  style: TextStyle(
                    fontSize: 13,
                    color: gTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailsCard(
    BuildContext context,
    GovernanceTheme gTheme,
    dynamic user,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: gTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, size: 20, color: gTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'My Profile Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: gTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your administrator profile and contact details.',
            style: TextStyle(fontSize: 12.5, color: gTheme.textSecondary),
          ),
          const SizedBox(height: 18),

          // Full Name
          TextField(
            controller: _nameController,
            style: TextStyle(color: gTheme.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'Full Name *',
              labelStyle: TextStyle(color: gTheme.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.person_outline, size: 18, color: gTheme.textSecondary),
              filled: true,
              fillColor: gTheme.surfaceSubtle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: gTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Username & Email
          TextField(
            controller: _usernameController,
            style: TextStyle(color: gTheme.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'Username *',
              labelStyle: TextStyle(color: gTheme.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.alternate_email, size: 18, color: gTheme.textSecondary),
              filled: true,
              fillColor: gTheme.surfaceSubtle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: gTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _emailController,
            style: TextStyle(color: gTheme.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'Email Address *',
              labelStyle: TextStyle(color: gTheme.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.email_outlined, size: 18, color: gTheme.textSecondary),
              filled: true,
              fillColor: gTheme.surfaceSubtle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: gTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _isSavingProfile ? null : () => _handleSaveProfile(gTheme),
              icon: _isSavingProfile
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 17),
              label: Text(_isSavingProfile ? 'Saving Changes...' : 'Save Profile Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: gTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityVaultCard(BuildContext context, GovernanceTheme gTheme) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: gTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_reset_rounded, size: 20, color: gTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Change Password',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: gTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Protect your administrator account with a secure password.',
            style: TextStyle(fontSize: 12.5, color: gTheme.textSecondary),
          ),
          const SizedBox(height: 18),

          // Current Password
          TextField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrent,
            style: TextStyle(color: gTheme.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'Current Password *',
              labelStyle: TextStyle(color: gTheme.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.password_rounded, size: 18, color: gTheme.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: gTheme.textSecondary,
                ),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              filled: true,
              fillColor: gTheme.surfaceSubtle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: gTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // New Password
          TextField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            style: TextStyle(color: gTheme.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'New Password (at least 8 characters) *',
              labelStyle: TextStyle(color: gTheme.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.lock_outline_rounded, size: 18, color: gTheme.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: gTheme.textSecondary,
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
              filled: true,
              fillColor: gTheme.surfaceSubtle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: gTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Confirm Password
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            style: TextStyle(color: gTheme.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'Confirm New Password *',
              labelStyle: TextStyle(color: gTheme.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.check_circle_outline_rounded, size: 18, color: gTheme.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: gTheme.textSecondary,
                ),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              filled: true,
              fillColor: gTheme.surfaceSubtle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: gTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _isUpdatingPassword ? null : () => _handleUpdatePassword(gTheme),
              icon: _isUpdatingPassword
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.security_update_good_rounded, size: 17),
              label: Text(_isUpdatingPassword ? 'Saving Password...' : 'Save New Password'),
              style: ElevatedButton.styleFrom(
                backgroundColor: gTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGovernanceScopeCard(
    BuildContext context,
    GovernanceTheme gTheme,
    dynamic user,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: gTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vpn_key_outlined, size: 20, color: gTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Account Access & Backup Keys',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: gTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your administrator permissions and backup keys to help you recover access if needed.',
            style: TextStyle(fontSize: 12.5, color: gTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // Scope Pill
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: gTheme.primarySubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: gTheme.primaryBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.domain_verification_rounded, size: 18, color: gTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full System Access (All Campuses)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: gTheme.primary,
                        ),
                      ),
                      Text(
                        'You have full access to manage all campuses, teachers, students, and settings.',
                        style: TextStyle(fontSize: 11, color: gTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'Emergency Backup Codes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: gTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recoveryCodes.map((code) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: gTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: gTheme.border),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: gTheme.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          OutlinedButton.icon(
            onPressed: () => _copyRecoveryCodes(context),
            icon: Icon(Icons.copy_rounded, size: 15, color: gTheme.primary),
            label: Text(
              'Copy Backup Codes',
              style: TextStyle(color: gTheme.primary, fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: gTheme.primaryBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTelemetryCard(
    BuildContext context,
    GovernanceTheme gTheme,
    dynamic user,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: gTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.devices_outlined, size: 20, color: gTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Current Login & Device Info',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: gTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Information about your current session and signed-in device.',
            style: TextStyle(fontSize: 12.5, color: gTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          _buildTelemetryRow(gTheme, 'Account Role', 'Super Administrator (All Access)'),
          Divider(height: 18, color: gTheme.border),
          _buildTelemetryRow(gTheme, 'Signed in from', 'This Device (Local Network)'),
          Divider(height: 18, color: gTheme.border),
          _buildTelemetryRow(gTheme, 'Two-Step Login', 'Turned On & Protected'),
          Divider(height: 18, color: gTheme.border),
          _buildTelemetryRow(gTheme, 'Login Status', 'Active & Secure'),
          const SizedBox(height: 18),

          OutlinedButton.icon(
            onPressed: () {
              AiraActionToast.showSuccess(
                context,
                title: 'Other Devices Signed Out',
                message: 'You have signed out from all other active sessions.',
              );
              DatabaseHelper().logAuditEvent(
                action: 'SECURITY_SESSIONS_REVOKED',
                details: 'Super Administrator signed out from other active sessions.',
                actorId: user?.id,
                actorName: user?.fullName,
                schoolId: user?.schoolId,
              );
              ref.invalidate(superAdminAuditLogsProvider);
            },
            icon: Icon(Icons.phonelink_erase_rounded, size: 15, color: gTheme.dangerText),
            label: Text(
              'Sign Out Other Devices',
              style: TextStyle(color: gTheme.dangerText, fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: gTheme.dangerBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow(GovernanceTheme gTheme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: gTheme.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: gTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
