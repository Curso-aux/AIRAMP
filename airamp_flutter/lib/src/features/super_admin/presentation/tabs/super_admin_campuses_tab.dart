import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/components/aira_action_toast.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../admin/data/admin_repository.dart';
import '../super_admin_theme.dart';

class SuperAdminCampusesTab extends ConsumerStatefulWidget {
  final VoidCallback onOpenAddCampusDialog;

  const SuperAdminCampusesTab({
    super.key,
    required this.onOpenAddCampusDialog,
  });

  @override
  ConsumerState<SuperAdminCampusesTab> createState() => _SuperAdminCampusesTabState();
}

class _SuperAdminCampusesTabState extends ConsumerState<SuperAdminCampusesTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';

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

  void _openEditSchoolDialog(BuildContext context, GovernanceTheme gTheme, Map<String, dynamic> school) {
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
                    child: Icon(Icons.business_rounded, color: gTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Edit Campus Details',
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
                        'Update multi-tenant institutional properties and assigned administrator scope.',
                        style: TextStyle(fontSize: 13, color: gTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        maxLength: 80,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'School / Campus Name *',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.school_outlined, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeCtrl,
                        maxLength: 15,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Identifier Code *',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.tag_rounded, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressCtrl,
                        maxLength: 150,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Campus Physical Address',
                          labelStyle: TextStyle(color: gTheme.textSecondary),
                          prefixIcon: Icon(Icons.location_on_outlined, size: 18, color: gTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final isNarrowForm = MediaQuery.sizeOf(context).width < 500;
                          final statusField = DropdownButtonFormField<String>(
                            initialValue: selectedStatus,
                            isExpanded: true,
                            dropdownColor: gTheme.surfaceElevated,
                            style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Operational Status',
                              labelStyle: TextStyle(color: gTheme.textSecondary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'active', child: Text('Active Campus', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'inactive', child: Text('Inactive / Onboarding', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (val) => setDialogState(() => selectedStatus = val ?? 'active'),
                          );

                          final adminField = DropdownButtonFormField<String?>(
                            initialValue: selectedAdminId,
                            isExpanded: true,
                            dropdownColor: gTheme.surfaceElevated,
                            style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Assigned Administrator',
                              labelStyle: TextStyle(color: gTheme.textSecondary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('None (Assign Later)', overflow: TextOverflow.ellipsis)),
                              ...admins.map((a) => DropdownMenuItem(
                                value: a['id'] as String,
                                child: Text(
                                  a['full_name'] as String? ?? 'Admin',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                            ],
                            onChanged: (val) => setDialogState(() => selectedAdminId = val),
                          );

                          if (isNarrowForm) {
                            return Column(
                              children: [
                                statusField,
                                const SizedBox(height: 12),
                                adminField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: statusField),
                              const SizedBox(width: 12),
                              Expanded(child: adminField),
                            ],
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
                    final code = codeCtrl.text.trim().toUpperCase();
                    if (name.isEmpty || code.isEmpty) {
                      AiraActionToast.showWarning(
                        context,
                        title: 'Validation Error',
                        message: 'School name and code are required.',
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
                        AiraActionToast.showSuccess(
                          context,
                          title: 'Campus Updated',
                          message: 'Updated campus "$name" successfully.',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AiraActionToast.showError(
                          context,
                          title: 'Update Failed',
                          message: 'Error updating campus: $e',
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

  void _confirmDeleteSchool(BuildContext context, GovernanceTheme gTheme, Map<String, dynamic> school) {
    final schoolId = school['id'] as String;
    if (schoolId == 'sch_main') {
      AiraActionToast.showWarning(
        context,
        title: 'Action Restricted',
        message: 'The default demonstration school cannot be deleted.',
      );
      return;
    }

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
                            color: gTheme.dangerBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: gTheme.dangerBorder, width: 1.5),
                          ),
                          child: Center(
                            child: Icon(Icons.domain_disabled_rounded, color: gTheme.dangerText, size: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete Campus',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: gTheme.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Irreversible tenant removal',
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

                    // 2. Campus Profile Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: gTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: gTheme.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: gTheme.primarySubtle,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.business_rounded, color: gTheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  school['name'] as String? ?? 'Campus',
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
                                  'Code: ${school['code'] ?? ""} • ID: $schoolId',
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. Impact Notice Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: gTheme.dangerBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: gTheme.dangerBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: gTheme.dangerText),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Permanently removing this campus purges its isolated tenant registry, curriculum scoping, and linked access scopes. This action cannot be reversed.',
                              style: TextStyle(
                                fontSize: 12,
                                color: gTheme.dangerText,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Action Button Stack
                    ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              setModalState(() => isProcessing = true);
                              try {
                                await ref.read(schoolsListProvider.notifier).deleteSchool(schoolId);
                                if (context.mounted) {
                                  Navigator.of(dialogCtx).pop();
                                  AiraActionToast.showDeleted(
                                    context,
                                    title: 'Campus Deleted',
                                    message: 'Campus "${school['name']}" was permanently deleted.',
                                    duration: const Duration(seconds: 8),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.of(dialogCtx).pop();
                                  AiraActionToast.showError(
                                    context,
                                    title: 'Deletion Failed',
                                    message: 'Error deleting campus: $e',
                                  );
                                }
                              }
                            },
                      icon: isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.delete_forever_rounded, size: 17),
                      label: const Text('Permanently Delete Campus'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gTheme.dangerText,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: isProcessing ? null : () => Navigator.of(dialogCtx).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 38),
                        foregroundColor: gTheme.textSecondary,
                        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                      child: const Text('Cancel, keep campus'),
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

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final gTheme = GovernanceTheme(themeState.isDark);
    final schools = ref.watch(schoolsListProvider);
    final admins = ref.watch(schoolAdminsProvider);

    final filteredSchools = schools.where((s) {
      final name = (s['name'] as String? ?? '').toLowerCase();
      final code = (s['code'] as String? ?? '').toLowerCase();
      final matchesSearch = name.contains(_searchQuery) || code.contains(_searchQuery);
      if (!matchesSearch) return false;
      if (_statusFilter == 'all') return true;
      return (s['status'] as String? ?? 'active') == _statusFilter;
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
                            child: Icon(Icons.account_balance_outlined, color: gTheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Institutional Campuses & Multi-Tenant Registry',
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
                        'Each campus operates with its own isolated school_id data scope, curriculum, and assigned Campus Administrator.',
                        style: TextStyle(fontSize: 13, color: gTheme.textSecondary),
                      ),
                    ],
                  );

                  final addBtn = ElevatedButton.icon(
                    onPressed: widget.onOpenAddCampusDialog,
                    icon: const Icon(Icons.add_business_outlined, size: 16),
                    label: const Text('Register Campus'),
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

              // ── Filter & Search Controls ──
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
                        hintText: 'Search campus by name or code (e.g. QCS-01)...',
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

                    final statusDropdown = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: gTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: gTheme.border),
                      ),
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        isExpanded: isSmallScreen,
                        underline: const SizedBox.shrink(),
                        dropdownColor: gTheme.surfaceElevated,
                        style: TextStyle(fontSize: 13, color: gTheme.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'active', child: Text('Active Only')),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive Only')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _statusFilter = val);
                        },
                      ),
                    );

                    if (isSmallScreen) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          searchInput,
                          const SizedBox(height: 10),
                          statusDropdown,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: searchInput),
                        const SizedBox(width: 12),
                        statusDropdown,
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // ── Campuses Grid ──
              if (filteredSchools.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: gTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: gTheme.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 40, color: gTheme.textMuted),
                        const SizedBox(height: 10),
                        Text('No matching campuses found', style: TextStyle(color: gTheme.textMuted)),
                      ],
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;
                    final itemWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: filteredSchools.map((school) {
                        final schoolId = school['id'] as String;
                        final name = school['name'] as String? ?? 'Campus';
                        final code = school['code'] as String? ?? 'N/A';
                        final address = school['address'] as String? ?? 'Address not specified';
                        final status = school['status'] as String? ?? 'active';
                        final adminId = school['admin_id'] as String?;
                        final isMain = schoolId == 'sch_main';

                        final assignedAdmin = admins.firstWhere(
                          (a) => a['id'] == adminId,
                          orElse: () => <String, dynamic>{},
                        );
                        final adminName = assignedAdmin['full_name'] as String? ?? (adminId != null ? 'Admin $adminId' : 'Unassigned');
                        final adminEmail = assignedAdmin['email'] as String? ?? '';

                        return SizedBox(
                          width: itemWidth,
                          child: Container(
                            padding: const EdgeInsets.all(20),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: gTheme.surfaceSubtle,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: gTheme.border),
                                      ),
                                      child: Text(
                                        code,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: gTheme.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: gTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Scope ID: $schoolId',
                                            style: TextStyle(fontSize: 11, color: gTheme.textMuted, fontFamily: 'monospace'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: status == 'active' ? gTheme.successBg : gTheme.surfaceSubtle,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: status == 'active' ? gTheme.successBorder : gTheme.border),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: status == 'active' ? gTheme.successText : gTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 14, color: gTheme.textMuted),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: TextStyle(fontSize: 12, color: gTheme.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: gTheme.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: gTheme.border),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: gTheme.primarySubtle,
                                        child: Icon(Icons.manage_accounts, color: gTheme.primary, size: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Campus Administrator',
                                              style: TextStyle(fontSize: 10, color: gTheme.textMuted, fontWeight: FontWeight.w600),
                                            ),
                                            Text(
                                              adminName,
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: gTheme.textPrimary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (adminEmail.isNotEmpty)
                                              Text(
                                                adminEmail,
                                                style: TextStyle(fontSize: 11, color: gTheme.textMuted),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Divider(height: 1, color: gTheme.border),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, actionConstraints) {
                                    final isNarrowCard = actionConstraints.maxWidth < 340;
                                    final iconActions = Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, size: 18, color: gTheme.textSecondary),
                                          tooltip: 'Edit Campus',
                                          onPressed: () => _openEditSchoolDialog(context, gTheme, school),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline, size: 18, color: isMain ? gTheme.textMuted : gTheme.dangerText),
                                          tooltip: isMain ? 'Default campus cannot be deleted' : 'Delete Campus',
                                          onPressed: isMain ? null : () => _confirmDeleteSchool(context, gTheme, school),
                                        ),
                                      ],
                                    );

                                    final enterBtn = ElevatedButton.icon(
                                      onPressed: () {
                                        ref.read(superAdminSelectedSchoolProvider.notifier).state = schoolId;
                                        context.go('/admin/dashboard');
                                      },
                                      icon: const Icon(Icons.open_in_new_rounded, size: 13),
                                      label: const Text('Enter Campus View'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: gTheme.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                                      ),
                                    );

                                    if (isNarrowCard) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [iconActions],
                                          ),
                                          const SizedBox(height: 8),
                                          enterBtn,
                                        ],
                                      );
                                    }

                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        iconActions,
                                        enterBtn,
                                      ],
                                    );
                                  },
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
          ),
        ),
      ),
    );
  }
}
