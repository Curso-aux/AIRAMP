import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
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
                  Text(
                    'Edit Administrator Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: gTheme.textPrimary),
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
                            child: Text('Campus Administrator (Single Campus)'),
                          ),
                          DropdownMenuItem(
                            value: 'super_admin',
                            child: Text('Super Administrator (Global Master)'),
                          ),
                        ],
                        onChanged: admin['id'] == 'admin_1'
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
                              child: Text('${s['name']} (${s['code']})'),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name and email are required.')),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Updated administrator "$name" successfully.'),
                            backgroundColor: gTheme.successText,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: gTheme.dangerText),
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

  void _confirmDeleteAdmin(BuildContext context, GovernanceTheme gTheme, Map<String, dynamic> admin) {
    if (admin['id'] == 'admin_1') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Primary Root Super Administrator (admin_1) cannot be deleted.'),
          backgroundColor: gTheme.warningText,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: gTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: gTheme.dangerText, size: 24),
            const SizedBox(width: 10),
            Text('Confirm Revocation', style: TextStyle(color: gTheme.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently revoke administrative access for ${admin['full_name']} (${admin['email']})? This action cannot be undone.',
          style: TextStyle(color: gTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: Text('Cancel', style: TextStyle(color: gTheme.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(schoolAdminsProvider.notifier).deleteAdmin(admin['id'] as String);
                if (context.mounted) {
                  Navigator.of(dialogCtx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Administrator access revoked.'), backgroundColor: gTheme.successText),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: gTheme.dangerText),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: gTheme.dangerText, foregroundColor: Colors.white),
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final gTheme = GovernanceTheme(themeState.isDark);
    final admins = ref.watch(schoolAdminsProvider);
    final schools = ref.watch(schoolsListProvider);

    final filteredAdmins = admins.where((a) {
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                          Text(
                            'Administrator Directory & Access Governance',
                            style: TextStyle(
                              fontSize: isNarrow ? 17 : 20,
                              fontWeight: FontWeight.bold,
                              color: gTheme.textPrimary,
                              letterSpacing: -0.2,
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

              // ── Filter Controls ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: gTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: 13, color: gTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search administrator by name, email, or username...',
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
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: gTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: gTheme.border),
                      ),
                      child: DropdownButton<String>(
                        value: _roleFilter,
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
                    ),
                  ],
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
                              Icon(Icons.person_off_outlined, size: 40, color: gTheme.textMuted),
                              const SizedBox(height: 10),
                              Text('No matching administrator accounts found', style: TextStyle(color: gTheme.textMuted)),
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

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: gTheme.surfaceSubtle,
                                  child: Icon(
                                    isSuper ? Icons.admin_panel_settings : Icons.shield_outlined,
                                    color: isSuper ? gTheme.primary : gTheme.textSecondary,
                                    size: 20,
                                  ),
                                ),
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
                                              color: gTheme.textPrimary,
                                            ),
                                          ),
                                          if (admin['id'] == 'admin_1') ...[
                                            const SizedBox(width: 6),
                                            Container(
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
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${admin['email'] ?? ""} • Username: ${admin['username'] ?? "N/A"}',
                                        style: TextStyle(fontSize: 12, color: gTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isSuper ? gTheme.primarySubtle : gTheme.surfaceSubtle,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSuper ? gTheme.primaryBorder : gTheme.border,
                                        ),
                                      ),
                                      child: Text(
                                        isSuper ? 'SUPER ADMIN' : 'CAMPUS ADMIN',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isSuper ? gTheme.primary : gTheme.textSecondary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined, size: 18, color: gTheme.textSecondary),
                                      tooltip: 'Edit Administrator',
                                      onPressed: () => _openEditAdminDialog(context, gTheme, admin),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: admin['id'] == 'admin_1' ? gTheme.textMuted : gTheme.dangerText,
                                      ),
                                      tooltip: admin['id'] == 'admin_1'
                                          ? 'Root super admin cannot be deleted'
                                          : 'Revoke Administrator Access',
                                      onPressed: admin['id'] == 'admin_1'
                                          ? null
                                          : () => _confirmDeleteAdmin(context, gTheme, admin),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
