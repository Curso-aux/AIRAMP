import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/components/aira_action_toast.dart';
import '../../../../core/components/user_avatar_widget.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../admin/data/admin_repository.dart';
import '../super_admin_theme.dart';

class SuperAdminAdminsTab extends ConsumerStatefulWidget {
  final VoidCallback onOpenAddAdminDialog;

  const SuperAdminAdminsTab({
    super.key,
    required this.onOpenAddAdminDialog,
  });

  @override
  ConsumerState<SuperAdminAdminsTab> createState() => _SuperAdminAdminsTabState();
}

class _SuperAdminAdminsTabState extends ConsumerState<SuperAdminAdminsTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all';
  bool _isArchiveView = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(schoolAdminsProvider.notifier).loadAdmins();
      ref.read(archivedSchoolAdminsProvider.notifier).loadArchivedAdmins();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEditAdminDialog(BuildContext context, GovernanceTheme gTheme, Map<String, dynamic> admin) {
    final nameCtrl = TextEditingController(text: admin['full_name'] as String? ?? '');
    final emailCtrl = TextEditingController(text: admin['email'] as String? ?? '');
    final userCtrl = TextEditingController(text: admin['username'] as String? ?? '');
    final passCtrl = TextEditingController();
    String selectedRole = admin['role'] as String? ?? 'admin';
    String selectedSchool = admin['school_id'] as String? ?? 'sch_main';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final schools = ref.watch(schoolsListProvider);
            return AlertDialog(
              backgroundColor: gTheme.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: gTheme.primarySubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.manage_accounts_outlined, color: gTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Edit Administrator Account',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: gTheme.textPrimary),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update identity, assigned role credentials, and campus institutional scope.',
                        style: TextStyle(fontSize: 13, color: gTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        maxLength: 50,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.badge_outlined, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        maxLength: 50,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Official Email *',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.email_outlined, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: userCtrl,
                        maxLength: 30,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.alternate_email, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passCtrl,
                        maxLength: 16,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        obscureText: true,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Reset Password (Leave blank to keep current)',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.lock_outline, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        isExpanded: true,
                        dropdownColor: gTheme.surfaceElevated,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Administrative Authority',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.security, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Campus Administrator (Single Campus)', overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: 'super_admin',
                            child: Text('Super Administrator (Global Master)', overflow: TextOverflow.ellipsis),
                          ),
                        ],
                        onChanged: (admin['id'] == 'super_admin_christian' ||
                                admin['id'] == 'SA-000-0001' ||
                                (admin['email'] as String? ?? '').toLowerCase() == 'evangelistachristian88@gmail.com')
                            ? null
                            : (val) {
                                if (val != null) setDialogState(() => selectedRole = val);
                              },
                      ),
                      const SizedBox(height: 14),
                      if (selectedRole == 'admin' && schools.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: schools.any((s) => s['id'] == selectedSchool)
                              ? selectedSchool
                              : (schools.first['id'] as String?),
                          isExpanded: true,
                          dropdownColor: gTheme.surfaceElevated,
                          style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Assigned Campus Scope',
                            labelStyle: TextStyle(color: gTheme.textSecondary),
                            prefixIcon: Icon(Icons.account_balance_outlined, size: 18, color: gTheme.textSecondary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: schools.map((s) {
                            return DropdownMenuItem(
                              value: s['id'] as String,
                              child: Text('${s['name']} (${s['code']})', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedSchool = val);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: gTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final email = emailCtrl.text.trim();
                    final pass = passCtrl.text;
                    if (name.isEmpty || email.isEmpty) {
                      AiraActionToast.showWarning(
                        context,
                        title: 'Validation Error',
                        message: 'Name and email are required.',
                      );
                      return;
                    }
                    Navigator.of(dialogCtx).pop();
                    try {
                      final updateData = <String, dynamic>{
                        'full_name': name,
                        'email': email,
                        'username': userCtrl.text.trim().isNotEmpty ? userCtrl.text.trim() : null,
                        'role': selectedRole,
                        'school_id': selectedRole == 'super_admin' ? 'sch_main' : selectedSchool,
                      };
                      if (pass.isNotEmpty) {
                        updateData['password'] = pass;
                      }
                      await ref.read(schoolAdminsProvider.notifier).updateAdmin(
                        admin['id'] as String,
                        updateData,
                      );
                      if (context.mounted) {
                        AiraActionToast.showSuccess(
                          context,
                          title: 'Administrator Updated',
                          message: 'Updated administrator "$name" successfully.',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AiraActionToast.showError(
                          context,
                          title: 'Update Failed',
                          message: 'Error updating administrator: $e',
                        );
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmResendCredentials(BuildContext context, GovernanceTheme gTheme, Map<String, dynamic> admin) {
    final TextEditingController customPassCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: gTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Icon(Icons.forward_to_inbox_rounded, color: gTheme.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dispatch Credentials Email',
                  style: TextStyle(
                    color: gTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Regenerate temporary credentials and dispatch an onboarding email to ${admin['email']} for their campus scope.',
                  style: TextStyle(color: gTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: customPassCtrl,
                  style: TextStyle(fontSize: 13, color: gTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'New Password (leave blank to auto-generate)',
                    labelStyle: TextStyle(fontSize: 12, color: gTheme.textSecondary),
                    prefixIcon: Icon(Icons.lock_reset, size: 18, color: gTheme.textSecondary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: gTheme.textSecondary)),
            ),
            ElevatedButton.icon(
              icon: isSubmitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text('Send Credentials'),
              style: ElevatedButton.styleFrom(
                backgroundColor: gTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        final enteredPass = customPassCtrl.text.trim();
                        final res = await ref.read(schoolAdminsProvider.notifier).resendCredentials(
                              admin['id'] as String,
                              newPassword: enteredPass.isNotEmpty ? enteredPass : null,
                            );
                        if (context.mounted) {
                          Navigator.of(dialogCtx).pop();
                          if (res.success) {
                            AiraActionToast.showSuccess(
                              context,
                              title: 'Credentials Dispatched',
                              message: 'Credentials dispatched successfully to ${admin['email']} via ${res.channel.toUpperCase()}.',
                            );
                          } else {
                            AiraActionToast.showError(
                              context,
                              title: 'Dispatch Failed',
                              message: 'Failed to dispatch: ${res.message}',
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.of(dialogCtx).pop();
                          AiraActionToast.showError(
                            context,
                            title: 'Dispatch Error',
                            message: 'Error sending credentials: $e',
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showGovernanceActionModal(
    BuildContext context, {
    required GovernanceTheme gTheme,
    required IconData heroIcon,
    required Color accentColor,
    required Color accentBg,
    required Color accentBorder,
    required String title,
    required String subtitle,
    required Map<String, dynamic> admin,
    required String noticeText,
    required Color noticeBg,
    required Color noticeBorder,
    required Color noticeColor,
    required String confirmLabel,
    required IconData confirmIcon,
    required Color confirmColor,
    required Future<void> Function() onConfirm,
    String? secondaryLabel,
    IconData? secondaryIcon,
    Color? secondaryColor,
    VoidCallback? onSecondary,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
            backgroundColor: gTheme.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header with Circular Hero Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accentBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: accentBorder, width: 1.5),
                          ),
                          child: Center(
                            child: Icon(heroIcon, color: accentColor, size: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: gTheme.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: gTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 2. Account Profile Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: gTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: gTheme.border),
                      ),
                      child: Row(
                        children: [
                          UserAvatarWidget(
                            imageSource: admin['profile_image'] as String?,
                            fallbackInitial: (admin['full_name'] as String? ?? 'A').isNotEmpty
                                ? (admin['full_name'] as String)[0].toUpperCase()
                                : 'A',
                            size: 38,
                            backgroundColor: gTheme.primarySubtle,
                            textColor: gTheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  admin['full_name'] as String? ?? 'Administrator',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: gTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  admin['email'] as String? ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: gTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: gTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: gTheme.border),
                            ),
                            child: Text(
                              (admin['role'] == 'super_admin') ? 'SUPER ADMIN' : 'CAMPUS ADMIN',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: (admin['role'] == 'super_admin')
                                    ? gTheme.primary
                                    : gTheme.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. Impact Notice Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: noticeBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: noticeBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: noticeColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              noticeText,
                              style: TextStyle(
                                fontSize: 12,
                                color: noticeColor,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Action Button Stack (Full Width & Clean Hierarchy)
                    ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              setModalState(() => isProcessing = true);
                              await onConfirm();
                            },
                      icon: isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(confirmIcon, size: 17),
                      label: Text(confirmLabel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                    ),
                    if (secondaryLabel != null && onSecondary != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: isProcessing ? null : onSecondary,
                        icon: Icon(secondaryIcon ?? Icons.swap_horiz, size: 16, color: secondaryColor),
                        label: Text(secondaryLabel, style: TextStyle(color: secondaryColor)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          side: BorderSide(color: (secondaryColor ?? gTheme.border).withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: isProcessing ? null : () => Navigator.of(dialogCtx).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 38),
                        foregroundColor: gTheme.textSecondary,
                        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                      child: const Text('Cancel, keep active'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  void _confirmDeactivateAdmin(BuildContext context, GovernanceTheme gTheme, Map<String, dynamic> admin) {
    final isRoot = admin['id'] == 'super_admin_christian' ||
        admin['id'] == 'SA-000-0001' ||
        (admin['email'] as String? ?? '').toLowerCase() == 'evangelistachristian88@gmail.com';
    if (isRoot) {
      AiraActionToast.showWarning(
        context,
        title: 'Action Restricted',
        message: 'Primary Root Super Administrator cannot be deactivated.',
      );
      return;
    }

    _showGovernanceActionModal(
      context,
      gTheme: gTheme,
      heroIcon: Icons.person_off_outlined,
      accentColor: const Color(0xFFD97706),
      accentBg: const Color(0xFFFEF3C7).withValues(alpha: gTheme.isDark ? 0.2 : 0.8),
      accentBorder: const Color(0xFFF59E0B).withValues(alpha: 0.4),
      title: 'Deactivate Administrator',
      subtitle: 'Temporary access suspension',
      admin: admin,
      noticeText:
          'Login credentials will be revoked immediately and moved to Deactivated Accounts. You can restore access at any time.',
      noticeBg: const Color(0xFFD97706).withValues(alpha: 0.08),
      noticeBorder: const Color(0xFFD97706).withValues(alpha: 0.25),
      noticeColor: gTheme.isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      confirmLabel: 'Deactivate Account',
      confirmIcon: Icons.person_off_outlined,
      confirmColor: const Color(0xFFD97706),
      onConfirm: () async {
        try {
          await ref.read(schoolAdminsProvider.notifier).archiveAdmin(admin['id'] as String);
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            AiraActionToast.showDeactivated(
              context,
              title: 'Administrator Deactivated',
              message: 'Administrative access for "${admin['full_name']}" has been deactivated.',
              duration: const Duration(seconds: 8),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            AiraActionToast.showError(
              context,
              title: 'Deactivation Failed',
              message: 'Error deactivating administrator: $e',
            );
          }
        }
      },
    );
  }

  void _confirmRestoreAdmin(BuildContext context, GovernanceTheme gTheme, Map<String, dynamic> admin) {
    _showGovernanceActionModal(
      context,
      gTheme: gTheme,
      heroIcon: Icons.restore_rounded,
      accentColor: const Color(0xFF10B981),
      accentBg: const Color(0xFFD1FAE5).withValues(alpha: gTheme.isDark ? 0.2 : 0.8),
      accentBorder: const Color(0xFF10B981).withValues(alpha: 0.4),
      title: 'Restore Administrator',
      subtitle: 'Re-establish portal access',
      admin: admin,
      noticeText:
          'Access credentials will be reinstated immediately. The administrator will be able to sign in to the AIRAMP console again.',
      noticeBg: const Color(0xFF10B981).withValues(alpha: 0.08),
      noticeBorder: const Color(0xFF10B981).withValues(alpha: 0.25),
      noticeColor: gTheme.isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
      confirmLabel: 'Restore Access',
      confirmIcon: Icons.restore_rounded,
      confirmColor: const Color(0xFF10B981),
      onConfirm: () async {
        try {
          await ref.read(archivedSchoolAdminsProvider.notifier).restoreAdmin(admin['id'] as String);
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            AiraActionToast.showRestored(
              context,
              title: 'Administrator Restored',
              message: 'Administrative access for "${admin['full_name']}" has been restored.',
              duration: const Duration(seconds: 8),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            AiraActionToast.showError(
              context,
              title: 'Restore Failed',
              message: 'Error restoring administrator: $e',
            );
          }
        }
      },
    );
  }

  void _confirmPermanentDeleteAdmin(BuildContext context, GovernanceTheme gTheme, Map<String, dynamic> admin) {
    final isRoot = admin['id'] == 'super_admin_christian' ||
        admin['id'] == 'SA-000-0001' ||
        (admin['email'] as String? ?? '').toLowerCase() == 'evangelistachristian88@gmail.com';
    if (isRoot) {
      AiraActionToast.showWarning(
        context,
        title: 'Action Restricted',
        message: 'Primary Root Super Administrator cannot be deleted.',
      );
      return;
    }

    _showGovernanceActionModal(
      context,
      gTheme: gTheme,
      heroIcon: Icons.delete_forever_rounded,
      accentColor: gTheme.dangerText,
      accentBg: gTheme.dangerBg,
      accentBorder: gTheme.dangerBorder,
      title: 'Permanently Purge Record',
      subtitle: 'Database & Firestore record deletion',
      admin: admin,
      noticeText:
          'All audit references and database documents for this administrator will be permanently deleted. This action cannot be reversed.',
      noticeBg: gTheme.dangerBg,
      noticeBorder: gTheme.dangerBorder,
      noticeColor: gTheme.dangerText,
      confirmLabel: 'Purge Permanently',
      confirmIcon: Icons.delete_forever_rounded,
      confirmColor: gTheme.dangerText,
      onConfirm: () async {
        try {
          await ref.read(archivedSchoolAdminsProvider.notifier).permanentDeleteAdmin(admin['id'] as String);
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            AiraActionToast.showDeleted(
              context,
              title: 'Administrator Permanently Purged',
              message: 'Administrator "${admin['full_name']}" was permanently deleted from all systems.',
              duration: const Duration(seconds: 8),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            AiraActionToast.showError(
              context,
              title: 'Purge Failed',
              message: 'Error purging administrator: $e',
            );
          }
        }
      },
    );
  }

  void _confirmDeleteAdmin(BuildContext context, GovernanceTheme gTheme, Map<String, dynamic> admin) {
    final isRoot = admin['id'] == 'super_admin_christian' ||
        admin['id'] == 'SA-000-0001' ||
        (admin['email'] as String? ?? '').toLowerCase() == 'evangelistachristian88@gmail.com';
    if (isRoot) {
      AiraActionToast.showWarning(
        context,
        title: 'Action Restricted',
        message: 'Primary Root Super Administrator cannot be deleted.',
      );
      return;
    }

    _showGovernanceActionModal(
      context,
      gTheme: gTheme,
      heroIcon: Icons.warning_amber_rounded,
      accentColor: gTheme.dangerText,
      accentBg: gTheme.dangerBg,
      accentBorder: gTheme.dangerBorder,
      title: 'Permanently Delete Account',
      subtitle: 'Irreversible administrative action',
      admin: admin,
      noticeText:
          'This will permanently purge this account from both local storage and Cloud Firestore. If you only want to temporarily suspend access, consider Deactivating instead.',
      noticeBg: gTheme.dangerBg,
      noticeBorder: gTheme.dangerBorder,
      noticeColor: gTheme.dangerText,
      confirmLabel: 'Permanently Delete',
      confirmIcon: Icons.delete_forever_rounded,
      confirmColor: gTheme.dangerText,
      secondaryLabel: 'Deactivate Account Instead',
      secondaryIcon: Icons.person_off_outlined,
      secondaryColor: const Color(0xFFD97706),
      onSecondary: () {
        Navigator.of(context, rootNavigator: true).pop();
        _confirmDeactivateAdmin(context, gTheme, admin);
      },
      onConfirm: () async {
        try {
          await ref.read(schoolAdminsProvider.notifier).deleteAdmin(admin['id'] as String);
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            AiraActionToast.showDeleted(
              context,
              title: 'Administrator Permanently Deleted',
              message: 'Administrative access for "${admin['full_name']}" was permanently purged from all databases.',
              duration: const Duration(seconds: 8),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            AiraActionToast.showError(
              context,
              title: 'Deletion Failed',
              message: 'Error deleting administrator access: $e',
            );
          }
        }
      },
    );
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'N/A';
    final str = dateVal.toString();
    try {
      final dt = DateTime.parse(str).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return str.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final gTheme = GovernanceTheme(themeState.isDark);
    final admins = ref.watch(schoolAdminsProvider);
    final archivedAdmins = ref.watch(archivedSchoolAdminsProvider);
    final schools = ref.watch(schoolsListProvider);

    final currentAdmins = _isArchiveView ? archivedAdmins : admins;

    final filteredAdmins = currentAdmins.where((a) {
      final name = (a['full_name'] as String? ?? '').toLowerCase();
      final email = (a['email'] as String? ?? '').toLowerCase();
      final user = (a['username'] as String? ?? '').toLowerCase();
      final matchesQuery = name.contains(_searchQuery) || email.contains(_searchQuery) || user.contains(_searchQuery);
      if (!matchesQuery) return false;

      if (_roleFilter == 'all') return true;
      if (_roleFilter == 'super_admin') return a['role'] == 'super_admin';
      if (_roleFilter == 'admin') return a['role'] == 'admin';
      return true;
    }).toList();

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
              // ── Header Row ──
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 650;

                  final titleSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: gTheme.primarySubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: gTheme.primaryBorder),
                            ),
                            child: Icon(Icons.admin_panel_settings_outlined, color: gTheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Administrator Directory & Access Governance',
                              style: TextStyle(
                                fontSize: isNarrow ? 17 : 20,
                                fontWeight: FontWeight.bold,
                                color: gTheme.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Super Admin provisions and oversees Campus Administrators. Campus Admins manage faculty and students for their designated campus.',
                        style: TextStyle(fontSize: 13, color: gTheme.textSecondary),
                      ),
                    ],
                  );

                  final addBtn = ElevatedButton.icon(
                    onPressed: widget.onOpenAddAdminDialog,
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('Provision Administrator'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleSection,
                        const SizedBox(height: 14),
                        SizedBox(width: double.infinity, child: addBtn),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 16),
                      addBtn,
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // ── Active / Deactivated Directory Switcher Pills ──
              LayoutBuilder(
                builder: (context, switcherConstraints) {
                  final isCompact = switcherConstraints.maxWidth < 480;
                  final activeLabel = isCompact
                      ? 'Active (${admins.length})'
                      : 'Active Administrators (${admins.length})';
                  final archivedLabel = isCompact
                      ? 'Deactivated (${archivedAdmins.length})'
                      : 'Deactivated Accounts (${archivedAdmins.length})';

                  final activeTab = InkWell(
                    onTap: () => setState(() => _isArchiveView = false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 8 : 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: !_isArchiveView ? gTheme.surfaceElevated : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !_isArchiveView
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: isCompact ? MainAxisSize.max : MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 16,
                            color: !_isArchiveView ? gTheme.primary : gTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              activeLabel,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: !_isArchiveView ? FontWeight.bold : FontWeight.w500,
                                color: !_isArchiveView ? gTheme.primary : gTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  final archivedTab = InkWell(
                    onTap: () => setState(() => _isArchiveView = true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 8 : 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isArchiveView ? gTheme.surfaceElevated : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isArchiveView
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: isCompact ? MainAxisSize.max : MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            size: 16,
                            color: _isArchiveView ? const Color(0xFFD97706) : gTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              archivedLabel,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _isArchiveView ? FontWeight.bold : FontWeight.w500,
                                color: _isArchiveView ? const Color(0xFFD97706) : gTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: gTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: gTheme.border),
                    ),
                    child: isCompact
                        ? Row(
                            children: [
                              Expanded(child: activeTab),
                              const SizedBox(width: 4),
                              Expanded(child: archivedTab),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              activeTab,
                              const SizedBox(width: 4),
                              archivedTab,
                            ],
                          ),
                  );
                },
              ),
              const SizedBox(height: 16),

              if (_isArchiveView) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Deactivated Accounts Archive: These administrators cannot sign in to the AIRAMP console. You can restore their permissions or permanently delete them.',
                          style: TextStyle(
                            fontSize: 13,
                            color: gTheme.isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Filter Controls ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: gTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gTheme.border),
                ),
                child: LayoutBuilder(
                  builder: (context, filterConstraints) {
                    final isSmallScreen = filterConstraints.maxWidth < 560;

                    final searchInput = TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 13, color: gTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: _isArchiveView
                            ? 'Search deactivated administrator by name, email, or username...'
                            : 'Search administrator by name, email, or username...',
                        hintStyle: TextStyle(color: gTheme.textMuted, fontSize: 13),
                        prefixIcon: Icon(Icons.search, size: 18, color: gTheme.textMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: gTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: gTheme.border),
                        ),
                        isDense: true,
                      ),
                    );

                    final roleDropdown = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: gTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: gTheme.border),
                      ),
                      child: DropdownButton<String>(
                        value: _roleFilter,
                        isExpanded: isSmallScreen,
                        underline: const SizedBox.shrink(),
                        dropdownColor: gTheme.surfaceElevated,
                        style: TextStyle(fontSize: 13, color: gTheme.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Administrative Roles')),
                          DropdownMenuItem(value: 'super_admin', child: Text('Super Admins Only')),
                          DropdownMenuItem(value: 'admin', child: Text('Campus Admins Only')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _roleFilter = val);
                        },
                      ),
                    );

                    if (isSmallScreen) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          searchInput,
                          const SizedBox(height: 10),
                          roleDropdown,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: searchInput),
                        const SizedBox(width: 12),
                        roleDropdown,
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // ── Admins Table Card ──
              Container(
                decoration: BoxDecoration(
                  color: gTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: gTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: gTheme.isDark ? 0.15 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: filteredAdmins.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                _isArchiveView ? Icons.check_circle_outline : Icons.person_off_outlined,
                                size: 40,
                                color: gTheme.textMuted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _isArchiveView
                                    ? 'No deactivated administrator accounts in archive'
                                    : 'No matching administrator accounts found',
                                style: TextStyle(color: gTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredAdmins.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: gTheme.border),
                        itemBuilder: (context, index) {
                          final admin = filteredAdmins[index];
                          final isSuper = admin['role'] == 'super_admin';
                          final schoolId = admin['school_id'] as String? ?? 'sch_main';

                          final matchedSchool = schools.firstWhere(
                            (s) => s['id'] == schoolId,
                            orElse: () => {'name': 'Default Campus', 'code': schoolId},
                          );
                          final schoolDisplay = isSuper
                              ? 'Global Master Jurisdiction (All Campuses)'
                              : '${matchedSchool['name']} (${matchedSchool['code']})';

                          final isRoot = admin['id'] == 'super_admin_christian' ||
                              admin['id'] == 'SA-000-0001' ||
                              (admin['email'] as String? ?? '').toLowerCase() == 'evangelistachristian88@gmail.com';

                          final avatarWidget = CircleAvatar(
                            radius: 20,
                            backgroundColor: _isArchiveView
                                ? const Color(0xFFD97706).withValues(alpha: 0.12)
                                : gTheme.surfaceSubtle,
                            child: Icon(
                              _isArchiveView
                                  ? Icons.person_off_outlined
                                  : (isSuper ? Icons.admin_panel_settings : Icons.shield_outlined),
                              color: _isArchiveView
                                  ? const Color(0xFFD97706)
                                  : (isSuper ? gTheme.primary : gTheme.textSecondary),
                              size: 20,
                            ),
                          );

                          final rootTag = Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: gTheme.primarySubtle,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: gTheme.primaryBorder),
                            ),
                            child: Text(
                              'ROOT',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: gTheme.primary),
                            ),
                          );

                          final roleBadge = Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isArchiveView
                                  ? const Color(0xFFD97706).withValues(alpha: 0.12)
                                  : (isSuper ? gTheme.primarySubtle : gTheme.surfaceSubtle),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _isArchiveView
                                    ? const Color(0xFFD97706).withValues(alpha: 0.3)
                                    : (isSuper ? gTheme.primaryBorder : gTheme.border),
                              ),
                            ),
                            child: Text(
                              _isArchiveView
                                  ? 'DEACTIVATED'
                                  : (isSuper ? 'SUPER ADMIN' : 'CAMPUS ADMIN'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _isArchiveView
                                    ? const Color(0xFFD97706)
                                    : (isSuper ? gTheme.primary : gTheme.textSecondary),
                                letterSpacing: 0.5,
                              ),
                            ),
                          );

                          final actionButtons = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isArchiveView) ...[
                                IconButton(
                                  icon: const Icon(Icons.restore_rounded, size: 20, color: Color(0xFF10B981)),
                                  tooltip: 'Restore Administrator Access',
                                  onPressed: () => _confirmRestoreAdmin(context, gTheme, admin),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_forever_rounded, size: 20, color: gTheme.dangerText),
                                  tooltip: 'Permanently Purge Administrator',
                                  onPressed: () => _confirmPermanentDeleteAdmin(context, gTheme, admin),
                                ),
                              ] else ...[
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, size: 18, color: gTheme.textSecondary),
                                  tooltip: 'Edit Administrator',
                                  onPressed: () => _openEditAdminDialog(context, gTheme, admin),
                                ),
                                IconButton(
                                  icon: Icon(Icons.forward_to_inbox_outlined, size: 18, color: gTheme.primary),
                                  tooltip: 'Resend Credentials Email',
                                  onPressed: () => _confirmResendCredentials(context, gTheme, admin),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.person_off_outlined,
                                    size: 18,
                                    color: isRoot ? gTheme.textMuted : const Color(0xFFD97706),
                                  ),
                                  tooltip: isRoot
                                      ? 'Root super admin cannot be deactivated'
                                      : 'Deactivate Administrator Account',
                                  onPressed: isRoot
                                      ? null
                                      : () => _confirmDeactivateAdmin(context, gTheme, admin),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: isRoot ? gTheme.textMuted : gTheme.dangerText,
                                  ),
                                  tooltip: isRoot
                                      ? 'Root super admin cannot be deleted'
                                      : 'Permanently Delete Administrator',
                                  onPressed: isRoot
                                      ? null
                                      : () => _confirmDeleteAdmin(context, gTheme, admin),
                                ),
                              ],
                            ],
                          );

                          return LayoutBuilder(
                            builder: (context, cardConstraints) {
                              final isCompact = cardConstraints.maxWidth < 720;

                              if (isCompact) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          avatarWidget,
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        admin['full_name'] as String? ?? 'Admin',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                          color: _isArchiveView ? gTheme.textSecondary : gTheme.textPrimary,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (isRoot) ...[
                                                      const SizedBox(width: 6),
                                                      rootTag,
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _isArchiveView
                                                      ? '${admin['email'] ?? ""} • Deactivated on ${_formatDate(admin['archived_at'])}'
                                                      : '${admin['email'] ?? ""} • @${admin['username'] ?? "N/A"}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: _isArchiveView ? const Color(0xFFD97706) : gTheme.textSecondary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          roleBadge,
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: gTheme.surfaceSubtle,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: gTheme.border),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isSuper ? Icons.public : Icons.school_outlined,
                                              size: 13,
                                              color: gTheme.textSecondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                schoolDisplay,
                                                style: TextStyle(fontSize: 11, color: gTheme.textSecondary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [actionButtons],
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // ── Wide Desktop Table Row ──
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                child: Row(
                                  children: [
                                    avatarWidget,
                                    const SizedBox(width: 14),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                admin['full_name'] as String? ?? 'Admin',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: _isArchiveView ? gTheme.textSecondary : gTheme.textPrimary,
                                                ),
                                              ),
                                              if (isRoot) ...[
                                                const SizedBox(width: 6),
                                                rootTag,
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _isArchiveView
                                                ? '${admin['email'] ?? ""} • Deactivated on ${_formatDate(admin['archived_at'])}'
                                                : '${admin['email'] ?? ""} • Username: ${admin['username'] ?? "N/A"}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _isArchiveView ? const Color(0xFFD97706) : gTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: roleBadge,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        schoolDisplay,
                                        style: TextStyle(fontSize: 12, color: gTheme.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    actionButtons,
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
