import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../data/admin_repository.dart';

class AdminManagementScreen extends ConsumerStatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  ConsumerState<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends ConsumerState<AdminManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

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
      ref.read(schoolsListProvider.notifier).loadSchools();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddAdminDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'admin';
    String selectedSchool = 'sch_main';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final schoolsAsync = ref.watch(schoolsProvider);
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.admin_panel_settings, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Administrator Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.text),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Provision access credentials for a school-level administrator or system super-admin.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'e.g. Dr. Maria Santos',
                          prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Official Email *',
                          hintText: 'e.g. maria.santos@aira.edu',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: userCtrl,
                        decoration: InputDecoration(
                          labelText: 'Username (Optional)',
                          hintText: 'Leave blank to use email prefix',
                          prefixIcon: const Icon(Icons.alternate_email, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Temporary Password *',
                          hintText: 'Minimum 6 characters',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Administrative Authority',
                          prefixIcon: const Icon(Icons.security, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('School Administrator (Single School Scoped)'),
                          ),
                          DropdownMenuItem(
                            value: 'super_admin',
                            child: Text('Super Administrator (Global / Multi-School)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      schoolsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (schools) {
                          if (schools.isEmpty) return const SizedBox.shrink();
                          return DropdownButtonFormField<String>(
                            initialValue: selectedSchool,
                            decoration: InputDecoration(
                              labelText: 'Assigned School',
                              prefixIcon: const Icon(Icons.account_balance, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: schools.map((s) {
                              return DropdownMenuItem(
                                value: s['id'] as String,
                                child: Text(s['name'] as String? ?? 'School'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedSchool = val);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final email = emailCtrl.text.trim();
                    final pass = passCtrl.text;
                    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in all required fields.')),
                      );
                      return;
                    }
                    try {
                      await ref.read(schoolAdminsProvider.notifier).addAdmin(
                        fullName: name,
                        email: email,
                        password: pass,
                        username: userCtrl.text.trim().isEmpty ? null : userCtrl.text.trim(),
                        role: selectedRole,
                        schoolId: selectedSchool,
                      );
                      if (context.mounted) {
                        Navigator.of(dialogCtx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Administrator $name successfully created.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Create Admin Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openEditAdminDialog(BuildContext context, Map<String, dynamic> admin) {
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
            final schoolsAsync = ref.watch(schoolsProvider);
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Edit Administrator',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.text),
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: userCtrl,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          prefixIcon: const Icon(Icons.alternate_email, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'New Password (Optional)',
                          hintText: 'Leave blank to preserve current password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          prefixIcon: const Icon(Icons.security, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('School Administrator')),
                          DropdownMenuItem(value: 'super_admin', child: Text('Super Administrator')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      schoolsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (schools) {
                          if (schools.isEmpty) return const SizedBox.shrink();
                          return DropdownButtonFormField<String>(
                            initialValue: schools.any((s) => s['id'] == selectedSchool) ? selectedSchool : schools.first['id'] as String,
                            decoration: InputDecoration(
                              labelText: 'Assigned School',
                              prefixIcon: const Icon(Icons.account_balance, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: schools.map((s) {
                              return DropdownMenuItem(
                                value: s['id'] as String,
                                child: Text(s['name'] as String? ?? 'School'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedSchool = val);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final updates = <String, dynamic>{
                      'full_name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'username': userCtrl.text.trim(),
                      'role': selectedRole,
                      'school_id': selectedSchool,
                    };
                    if (passCtrl.text.isNotEmpty) {
                      updates['password'] = passCtrl.text;
                    }
                    try {
                      await ref.read(schoolAdminsProvider.notifier).updateAdmin(
                        admin['id'] as String,
                        updates,
                      );
                      if (context.mounted) {
                        Navigator.of(dialogCtx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Administrator updated.'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteAdmin(BuildContext context, Map<String, dynamic> admin) {
    if (admin['id'] == 'admin_1') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primary System Super Administrator (admin_1) cannot be deleted.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 10),
            Text('Confirm Deletion', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently revoke administrative access for ${admin['full_name']} (${admin['email']})? This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(schoolAdminsProvider.notifier).deleteAdmin(admin['id'] as String);
                if (context.mounted) {
                  Navigator.of(dialogCtx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Administrator removed successfully.'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Admin'),
          ),
        ],
      ),
    );
  }

  void _openAddSchoolDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String selectedStatus = 'active';
    String? selectedAdminId;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final admins = ref.watch(schoolAdminsProvider);
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_business_rounded, color: Colors.teal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Register New Campus / School',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.text),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Provision a multi-tenant institutional school campus with dedicated school_id scoping.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'School / Campus Name *',
                          hintText: 'e.g. Quezon City Science High School',
                          prefixIcon: const Icon(Icons.school_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'School Identifier Code *',
                          hintText: 'e.g. QCS-01',
                          prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressCtrl,
                        decoration: InputDecoration(
                          labelText: 'Campus Physical Address',
                          hintText: 'e.g. Agham Road, Diliman, Quezon City',
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedStatus,
                              decoration: InputDecoration(
                                labelText: 'Operational Status',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'active', child: Text('Active Campus')),
                                DropdownMenuItem(value: 'inactive', child: Text('Inactive / Onboarding')),
                              ],
                              onChanged: (val) => setDialogState(() => selectedStatus = val ?? 'active'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: selectedAdminId,
                              decoration: InputDecoration(
                                labelText: 'Assigned Administrator',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('None (Assign Later)')),
                                ...admins.map((a) => DropdownMenuItem(
                                  value: a['id'] as String,
                                  child: Text(
                                    a['full_name'] as String? ?? 'Admin',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                              ],
                              onChanged: (val) => setDialogState(() => selectedAdminId = val),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final code = codeCtrl.text.trim().toUpperCase();
                    if (name.isEmpty || code.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('School name and code are required.')),
                      );
                      return;
                    }
                    Navigator.of(dialogCtx).pop();
                    try {
                      await ref.read(schoolsListProvider.notifier).addSchool(
                        name: name,
                        code: code,
                        address: addressCtrl.text.trim(),
                        adminId: selectedAdminId,
                        status: selectedStatus,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Registered campus "$name" successfully.'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Register Campus'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openEditSchoolDialog(BuildContext context, Map<String, dynamic> school) {
    final nameCtrl = TextEditingController(text: school['name'] as String? ?? '');
    final codeCtrl = TextEditingController(text: school['code'] as String? ?? '');
    final addressCtrl = TextEditingController(text: school['address'] as String? ?? '');
    String selectedStatus = school['status'] as String? ?? 'active';
    String? selectedAdminId = school['admin_id'] as String?;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final admins = ref.watch(schoolAdminsProvider);
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_location_alt_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Campus Information',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.text),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update institutional credentials, code identifier, or assigned school-level administrator.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'School / Campus Name *',
                          prefixIcon: const Icon(Icons.school_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'School Identifier Code *',
                          prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressCtrl,
                        decoration: InputDecoration(
                          labelText: 'Campus Physical Address',
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedStatus,
                              decoration: InputDecoration(
                                labelText: 'Operational Status',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'active', child: Text('Active Campus')),
                                DropdownMenuItem(value: 'inactive', child: Text('Inactive / Onboarding')),
                              ],
                              onChanged: (val) => setDialogState(() => selectedStatus = val ?? 'active'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: selectedAdminId,
                              decoration: InputDecoration(
                                labelText: 'Assigned Administrator',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('None (Unassigned)')),
                                ...admins.map((a) => DropdownMenuItem(
                                  value: a['id'] as String,
                                  child: Text(
                                    a['full_name'] as String? ?? 'Admin',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                              ],
                              onChanged: (val) => setDialogState(() => selectedAdminId = val),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final code = codeCtrl.text.trim().toUpperCase();
                    if (name.isEmpty || code.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('School name and code are required.')),
                      );
                      return;
                    }
                    Navigator.of(dialogCtx).pop();
                    try {
                      await ref.read(schoolsListProvider.notifier).updateSchool(
                        id: school['id'] as String,
                        name: name,
                        code: code,
                        address: addressCtrl.text.trim(),
                        adminId: selectedAdminId,
                        status: selectedStatus,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Updated campus "$name" successfully.'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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

  void _confirmDeleteSchool(BuildContext context, Map<String, dynamic> school) {
    final schoolId = school['id'] as String;
    if (schoolId == 'sch_main') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The default demonstration school cannot be deleted.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text('Delete Campus', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${school['name']}"? This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                await ref.read(schoolsListProvider.notifier).deleteSchool(schoolId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Campus "${school['name']}" deleted successfully.'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolsManagementSection(BuildContext context, List<Map<String, dynamic>> schools) {
    final admins = ref.watch(schoolAdminsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Institutional Campuses & Schools (Multi-Tenant Scoping)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 2),
                Text(
                  'Super Admin provisions independent schools, campus codes, and assigned School Administrators',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _openAddSchoolDialog(context),
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: const Text('Register Campus'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Schools List / Grid
        if (schools.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: Text('No schools registered yet', style: TextStyle(color: AppTheme.textMuted)),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final itemWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: schools.map((school) {
                  final schoolId = school['id'] as String;
                  final name = school['name'] as String? ?? 'School';
                  final code = school['code'] as String? ?? 'N/A';
                  final address = school['address'] as String? ?? 'Address not specified';
                  final status = school['status'] as String? ?? 'active';
                  final adminId = school['admin_id'] as String?;
                  final isMain = schoolId == 'sch_main';

                  // Find assigned admin name
                  final assignedAdmin = admins.firstWhere(
                    (a) => a['id'] == adminId,
                    orElse: () => <String, dynamic>{},
                  );
                  final adminName = assignedAdmin['full_name'] as String? ?? (adminId != null ? 'Admin $adminId' : 'Unassigned');

                  return SizedBox(
                    width: itemWidth,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isMain ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.border,
                          width: isMain ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isMain
                                      ? AppTheme.primary.withValues(alpha: 0.12)
                                      : Colors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.account_balance_rounded,
                                  color: isMain ? AppTheme.primary : Colors.teal,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.text,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                                          ),
                                          child: Text(
                                            code,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            address,
                                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(height: 1, color: AppTheme.border),
                          const SizedBox(height: 12),

                          // Campus Stats Chips (Students, Teachers, Sections, Subjects)
                          FutureBuilder<Map<String, int>>(
                            future: DatabaseHelper().getSchoolStats(schoolId),
                            builder: (context, snapshot) {
                              final stats = snapshot.data ?? {'students': 0, 'teachers': 0, 'sections': 0, 'subjects': 0};
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSchoolMetricChip(Icons.school, '${stats['students']}', 'Students', Colors.indigo),
                                  _buildSchoolMetricChip(Icons.badge, '${stats['teachers']}', 'Faculty', Colors.teal),
                                  _buildSchoolMetricChip(Icons.groups, '${stats['sections']}', 'Sections', Colors.amber.shade800),
                                  _buildSchoolMetricChip(Icons.menu_book, '${stats['subjects']}', 'Subjects', Colors.purple),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          Divider(height: 1, color: AppTheme.border),
                          const SizedBox(height: 12),

                          // Footer: Assigned Admin & Actions
                          Row(
                            children: [
                              Icon(Icons.manage_accounts_outlined, size: 16, color: AppTheme.textMuted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Admin: $adminName',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: adminId != null ? AppTheme.text : AppTheme.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: status == 'active'
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: status == 'active' ? Colors.green : Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit Campus',
                                onPressed: () => _openEditSchoolDialog(context, school),
                              ),
                              if (!isMain)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  tooltip: 'Delete Campus',
                                  onPressed: () => _confirmDeleteSchool(context, school),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSchoolMetricChip(IconData icon, String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            count,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final admins = ref.watch(schoolAdminsProvider);
    final teachers = ref.watch(adminTeachersProvider);
    final subjects = ref.watch(subjectsProvider);
    final sections = ref.watch(sectionsProvider);
    final currentUser = ref.watch(authProvider);
    final schools = ref.watch(schoolsListProvider);

    final filteredAdmins = admins.where((a) {
      if (_searchQuery.isEmpty) return true;
      final name = (a['full_name'] as String? ?? '').toLowerCase();
      final email = (a['email'] as String? ?? '').toLowerCase();
      final user = (a['username'] as String? ?? '').toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery) || user.contains(_searchQuery);
    }).toList();

    final superAdminCount = admins.where((a) => a['role'] == 'super_admin').length;
    final schoolAdminCount = admins.where((a) => a['role'] == 'admin').length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Super Administrator Governance Console',
          style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.text),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Console',
            onPressed: () {
              ref.read(schoolAdminsProvider.notifier).loadAdmins();
              ref.read(adminTeachersProvider.notifier).loadTeachers();
              ref.read(schoolsListProvider.notifier).loadSchools();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, const Color(0xFF4A148C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 36),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Institutional Governance & Administration',
                              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Authenticated as ${currentUser?.fullName ?? "Super Administrator"} • Full System Jurisdiction',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openAddAdminDialog(context),
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('Add Administrator'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Metrics Overview
                Row(
                  children: [
                    Expanded(
                      child: _buildStatTile(
                        'Total Admins',
                        admins.length.toString(),
                        Icons.shield,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildStatTile(
                        'Campuses / Schools',
                        schools.length.toString(),
                        Icons.account_balance_rounded,
                        Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildStatTile(
                        'School Admins',
                        schoolAdminCount.toString(),
                        Icons.manage_accounts,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildStatTile(
                        'Super Admins',
                        superAdminCount.toString(),
                        Icons.vpn_key,
                        Colors.amber.shade800,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildStatTile(
                        'Faculty Staff',
                        teachers.length.toString(),
                        Icons.badge,
                        Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Section 1: Administrator Management (Item 5: Super Admin manages Admins)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Administrator Accounts & Roles',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Super Admin manages Admins; Admins manage Teachers and Students',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 260,
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: 13, color: AppTheme.text),
                        decoration: InputDecoration(
                          hintText: 'Search administrator...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Administrators Table / List Card
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: filteredAdmins.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.person_off_outlined, size: 48, color: AppTheme.textMuted),
                                const SizedBox(height: 12),
                                Text('No administrator accounts found', style: TextStyle(color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredAdmins.length,
                          separatorBuilder: (_, _) => Divider(height: 1, color: AppTheme.border),
                          itemBuilder: (context, index) {
                            final admin = filteredAdmins[index];
                            final isSuper = admin['role'] == 'super_admin';
                            final schoolId = admin['school_id'] as String? ?? 'sch_main';

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isSuper
                                        ? Colors.purple.withValues(alpha: 0.15)
                                        : Colors.blue.withValues(alpha: 0.15),
                                    child: Icon(
                                      isSuper ? Icons.admin_panel_settings : Icons.shield_outlined,
                                      color: isSuper ? Colors.purple : Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          admin['full_name'] as String? ?? 'Admin',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppTheme.text,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          admin['email'] as String? ?? '',
                                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isSuper
                                              ? Colors.purple.withValues(alpha: 0.1)
                                              : Colors.blue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isSuper
                                                ? Colors.purple.withValues(alpha: 0.3)
                                                : Colors.blue.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          isSuper ? 'SUPER ADMIN' : 'SCHOOL ADMIN',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isSuper ? Colors.purple : Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      isSuper ? 'Global (All Schools)' : schoolId,
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        tooltip: 'Edit Administrator',
                                        onPressed: () => _openEditAdminDialog(context, admin),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        tooltip: 'Delete Administrator',
                                        onPressed: admin['id'] == 'admin_1'
                                            ? null
                                            : () => _confirmDeleteAdmin(context, admin),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 32),

                // Section 2: Multi-School & Campus Management (Item 8: Super Admin manages schools)
                _buildSchoolsManagementSection(context, schools),
                const SizedBox(height: 32),

                // Section 3: Core Academic Operations Modules
                Text(
                  'Institutional Operations & Curriculum Control',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 4),
                Text(
                  'Direct navigation to school-level resources managed by administrators',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;
                    final cardWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildModuleCard(
                          context,
                          title: 'Faculty & Teachers Directory',
                          subtitle: '${teachers.length} Active instructors and department staff',
                          icon: Icons.badge_outlined,
                          color: AppTheme.primary,
                          width: cardWidth,
                          route: '/admin/teachers',
                        ),
                        _buildModuleCard(
                          context,
                          title: 'Subjects & Curriculum Modules',
                          subtitle: '${subjects.length} Subjects with modules, LOs, and reading materials',
                          icon: Icons.menu_book_outlined,
                          color: Colors.teal,
                          width: cardWidth,
                          route: '/admin/subjects',
                        ),
                        _buildModuleCard(
                          context,
                          title: 'Class Sections & Cohorts',
                          subtitle: '${sections.length} Academic sections across Grade 10-12',
                          icon: Icons.groups_outlined,
                          color: Colors.amber.shade700,
                          width: cardWidth,
                          route: '/admin/sections',
                        ),
                        _buildModuleCard(
                          context,
                          title: 'Registration & Access Keys',
                          subtitle: 'Generate single-use and multi-use self-enrollment keys',
                          icon: Icons.key_outlined,
                          color: Colors.indigo,
                          width: cardWidth,
                          route: '/admin/keys',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Section 3: Architecture & Security Integrity
                Text(
                  'Multi-Role & Security Architecture Integrity',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      _buildSecurityItem(
                        icon: Icons.security,
                        color: Colors.purple,
                        title: 'Hierarchical RBAC Governance',
                        description: 'Super Admin manages Admins; Admins manage Faculty and Students; Teachers manage Class Curriculum and Schedules',
                        status: 'ACTIVE',
                      ),
                      Divider(height: 24, color: AppTheme.border),
                      _buildSecurityItem(
                        icon: Icons.lock_outline,
                        color: Colors.green,
                        title: 'Cryptographic Salted Password Security',
                        description: 'Salted SHA-256 with unique 16-byte user-specific salts generated via Random.secure()',
                        status: 'SECURE',
                      ),
                      Divider(height: 24, color: AppTheme.border),
                      _buildSecurityItem(
                        icon: Icons.account_balance,
                        color: Colors.blue,
                        title: 'Multi-Tenant Database Scoping',
                        description: 'Tables automatically scoped by school_id (v21 database schema)',
                        status: 'ENABLED',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text)),
              Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
    required String route,
  }) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required String status,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.text)),
              const SizedBox(height: 2),
              Text(description, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
          ),
          child: Text(
            status,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ),
      ],
    );
  }
}
