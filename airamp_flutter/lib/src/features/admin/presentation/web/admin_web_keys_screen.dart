import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/section_key_helper.dart';
import '../../data/admin_repository.dart';

class AdminWebKeysScreen extends ConsumerStatefulWidget {
  const AdminWebKeysScreen({super.key});

  @override
  ConsumerState<AdminWebKeysScreen> createState() => _AdminWebKeysScreenState();
}

class _AdminWebKeysScreenState extends ConsumerState<AdminWebKeysScreen> {
  String _selectedGradeFilter = 'All';

  final List<String> _gradeLevels = [
    'All',
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final keys = ref.watch(adminKeysProvider);

    // Group keys by year level
    final Map<String, List<Map<String, dynamic>>> groupedKeys = {
      for (final g in _gradeLevels.where((g) => g != 'All')) g: [],
    };
    final List<Map<String, dynamic>> otherKeys = [];

    for (final k in keys) {
      final rawSec = k['section']?.toString() ?? '';
      final grade = (k['grade'] as String?) ?? SectionKeyHelper.extractGradeFromSection(rawSec);
      if (groupedKeys.containsKey(grade)) {
        groupedKeys[grade]!.add(k);
      } else {
        otherKeys.add(k);
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(adminKeysProvider.notifier).loadKeys();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Section Management Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enrollment Keys & Access Codes',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Active enrollment keys organized by year level. Keys are automatically generated when creating class sections.',
                          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      try {
                        GoRouter.maybeOf(context)?.go('/admin/sections');
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('Manage Class Sections'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Overview Banner
              Container(
                padding: const EdgeInsets.all(18),
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
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.vpn_key_outlined, color: AppTheme.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How Enrollment Keys Work',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Keys are automatically created when you add a class section. Distribute these codes so students can self-enroll into their classrooms and subjects.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        '${keys.length} Active Keys',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Year Level Filter Bar
              _buildGradeFilterBar(keys, groupedKeys),
              const SizedBox(height: 20),

              // Keys Display Separated by Year Level
              if (keys.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.key_off_outlined, size: 54, color: AppTheme.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        'No Enrollment Keys Created Yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Class sections you create will automatically generate active keys and appear here categorized by year level.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          try {
                            GoRouter.maybeOf(context)?.go('/admin/sections');
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Class Section'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 800;

                    if (_selectedGradeFilter == 'All') {
                      // Render separated sections for each year level with active keys
                      final activeYearLevels = _gradeLevels
                          .where((g) => g != 'All' && (groupedKeys[g]?.isNotEmpty ?? false))
                          .toList();

                      if (activeYearLevels.isEmpty && otherKeys.isEmpty) {
                        return _buildEmptyGradeCard('All Year Levels');
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...activeYearLevels.map((grade) {
                            final gradeKeys = groupedKeys[grade] ?? [];
                            return _buildYearLevelGroup(grade, gradeKeys, isWide);
                          }),
                          if (otherKeys.isNotEmpty)
                            _buildYearLevelGroup('General / Other Sections', otherKeys, isWide),
                        ],
                      );
                    } else {
                      // Filtered to a specific year level
                      final gradeKeys = groupedKeys[_selectedGradeFilter] ?? [];
                      if (gradeKeys.isEmpty) {
                        return _buildEmptyGradeCard(_selectedGradeFilter);
                      }
                      return _buildYearLevelGroup(_selectedGradeFilter, gradeKeys, isWide);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeFilterBar(
    List<Map<String, dynamic>> allKeys,
    Map<String, List<Map<String, dynamic>>> groupedKeys,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _gradeLevels.map((grade) {
          final isSelected = _selectedGradeFilter == grade;
          final count = grade == 'All'
              ? allKeys.length
              : (groupedKeys[grade]?.length ?? 0);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(grade),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedGradeFilter = grade);
                }
              },
              selectedColor: AppTheme.primary,
              backgroundColor: AppTheme.surface,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildYearLevelGroup(String grade, List<Map<String, dynamic>> gradeKeys, bool isWide) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year Level Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        grade,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${gradeKeys.length} ${gradeKeys.length == 1 ? 'Active Section Key' : 'Active Section Keys'}',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    try {
                      GoRouter.maybeOf(context)?.go('/admin/sections');
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.add, size: 15),
                  label: Text(
                    grade.startsWith('Grade') ? 'Add $grade Section' : 'Add Section',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Year Level Keys Table / Cards
          if (isWide)
            _buildDesktopKeysTable(gradeKeys)
          else
            _buildMobileKeysList(gradeKeys),
        ],
      ),
    );
  }

  Widget _buildEmptyGradeCard(String grade) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(Icons.key_off_outlined, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 14),
          Text(
            'No Active Keys for $grade',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.text),
          ),
          const SizedBox(height: 6),
          Text(
            'Creating a class section in $grade will automatically generate and activate its key here.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () {
              try {
                GoRouter.maybeOf(context)?.go('/admin/sections');
              } catch (_) {}
            },
            icon: const Icon(Icons.add, size: 16),
            label: Text('Create $grade Section'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopKeysTable(List<Map<String, dynamic>> keys) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.background),
        dataRowMinHeight: 64,
        dataRowMaxHeight: 68,
        horizontalMargin: 20,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('ACCESS KEY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('TARGET SECTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('USAGE / LIMIT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('EXPIRATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        ],
        rows: keys.map((k) {
          final code = k['code'] as String? ?? '';
          final section = k['section'] as String? ?? 'General';
          final maxUses = k['max_uses'] as int? ?? 50;
          final timesUsed = k['used_count'] as int? ?? 0;
          final expiration = k['expiration'] as String? ?? 'Never (Standard)';

          return DataRow(
            cells: [
              // Key Code Cell
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Copy Access Key',
                      icon: const Icon(Icons.copy, size: 16),
                      color: AppTheme.textSecondary,
                      onPressed: () => _copyKey(code),
                    ),
                  ],
                ),
              ),

              // Target Section Cell
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.class_outlined, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      section,
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.text),
                    ),
                  ],
                ),
              ),

              // Usage Limits Cell
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$timesUsed / $maxUses uses',
                      style: TextStyle(fontSize: 12, color: AppTheme.text),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        value: maxUses > 0 ? (timesUsed / maxUses).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: AppTheme.border,
                        valueColor: AlwaysStoppedAnimation(
                          timesUsed >= maxUses ? AppTheme.error : AppTheme.primary,
                        ),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),

              // Expiration Cell
              DataCell(
                Text(
                  expiration,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),

              // Status Cell
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success),
                  ),
                ),
              ),

              // Actions Cell
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showShareModal(code, section),
                      icon: const Icon(Icons.share, size: 14),
                      label: const Text('Share'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete Key',
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppTheme.error,
                      onPressed: () => _confirmDeleteKey(code),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileKeysList(List<Map<String, dynamic>> keys) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: keys.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final k = keys[index];
        final code = k['code'] as String? ?? '';
        final section = k['section'] as String? ?? 'General';
        final used = k['used_count'] as int? ?? 0;
        final max = k['max_uses'] as int? ?? 50;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    code,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(section, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Usage: $used / $max uses', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showShareModal(code, section),
                      icon: const Icon(Icons.send, size: 14),
                      label: const Text('Give to Student'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    color: AppTheme.textSecondary,
                    onPressed: () => _copyKey(code),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppTheme.error,
                    onPressed: () => _confirmDeleteKey(code),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyKey(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied enrollment key "$code" to clipboard!'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showShareModal(String code, String section) {
    final invitationText = 'Welcome to AIRAMP! Join section $section using this enrollment key: $code';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.send, color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                Text('Give Key to Students', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Copy this pre-formatted invitation message to send directly to your students via email, SMS, or group chat:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: SelectableText(
                invitationText,
                style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppTheme.text),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: invitationText));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Invitation message copied to clipboard!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Invitation Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteKey(String code) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete Key', style: TextStyle(color: AppTheme.text)),
        content: Text('Revoke enrollment key "$code"? Students will no longer be able to use it.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(adminKeysProvider.notifier).deleteKey(code);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted key "$code"'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
