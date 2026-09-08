import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../data/admin_repository.dart';

class AdminWebKeysScreen extends ConsumerStatefulWidget {
  const AdminWebKeysScreen({super.key});

  @override
  ConsumerState<AdminWebKeysScreen> createState() => _AdminWebKeysScreenState();
}

class _AdminWebKeysScreenState extends ConsumerState<AdminWebKeysScreen> {
  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final keys = ref.watch(adminKeysProvider);
    final availableSectionsAsync = ref.watch(availableSectionsProvider);
    final availableSections = availableSectionsAsync.value ?? ['STEM A', 'STEM B', 'STEM C', 'Emerald', 'Ruby'];

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
              // Header & Generate Action
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
                          'Generate and distribute perspective section enrollment keys to students for registration and course onboarding',
                          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showGenerateKeyDialog(availableSections),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Generate Section Key'),
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
                            'When students sign up or enroll in the app, providing a valid Section Key automatically arranges them into their designated section and unlocks associated curriculum.',
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
              const SizedBox(height: 24),

              // Keys Table or Empty State
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
                        'No Enrollment Keys Created',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Click "Generate Section Key" above to create an access key for your students.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 800;

                    if (isWide) {
                      return _buildDesktopKeysTable(keys);
                    } else {
                      return _buildMobileKeysList(keys);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopKeysTable(List<Map<String, dynamic>> keys) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
            final used = k['used_count'] as int? ?? 0;
            final max = k['max_uses'] as int? ?? 50;
            final expiration = k['expiration'] as String? ?? 'Never';

            return DataRow(
              cells: [
                // Code Cell
                DataCell(
                  Row(
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
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy Key',
                        icon: const Icon(Icons.copy, size: 16),
                        color: AppTheme.textMuted,
                        onPressed: () => _copyKey(code),
                      ),
                    ],
                  ),
                ),

                // Section Cell
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      section,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                ),

                // Usage Cell
                DataCell(
                  Text('$used / $max', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ),

                // Expiration Cell
                DataCell(
                  Text(expiration, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ),

                // Status Pill
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
                    children: [
                      TextButton.icon(
                        onPressed: () => _showShareModal(code, section),
                        icon: const Icon(Icons.share, size: 14),
                        label: const Text('Give to Student'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      ),
    );
  }

  Widget _buildMobileKeysList(List<Map<String, dynamic>> keys) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final k = keys[index];
        final code = k['code'] as String? ?? '';
        final section = k['section'] as String? ?? 'General';
        final used = k['used_count'] as int? ?? 0;
        final max = k['max_uses'] as int? ?? 50;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(code, style: TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
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
              const SizedBox(height: 14),
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
                style: TextStyle(fontSize: 13, color: AppTheme.text, height: 1.4),
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
                      content: const Text('Invitation copied to clipboard!'),
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

  void _showGenerateKeyDialog(List<String> availableSections) {
    String selectedSection = availableSections.isNotEmpty ? availableSections.first : 'STEM A';
    final randomSuffix = (DateTime.now().millisecondsSinceEpoch % 10000).toString();
    final codeController = TextEditingController(text: '${selectedSection.replaceAll(' ', '-')}-2026-$randomSuffix');
    final usesController = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(Icons.key, color: AppTheme.primary, size: 24),
                const SizedBox(width: 10),
                Text('Generate Section Key', style: TextStyle(fontSize: 18, color: AppTheme.text)),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Target Enrollment Section', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSection,
                    dropdownColor: AppTheme.surface,
                    style: TextStyle(color: AppTheme.text, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.background,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                    ),
                    items: availableSections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedSection = val;
                          codeController.text = '${val.replaceAll(' ', '-')}-2026-$randomSuffix';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  Text('Access Key Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: codeController,
                    style: TextStyle(color: AppTheme.text, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.background,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('Maximum Uses (Capacity)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: usesController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.text),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.background,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final code = codeController.text.trim();
                  final uses = int.tryParse(usesController.text) ?? 50;
                  if (code.isEmpty) return;

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogCtx);
                  await ref.read(adminKeysProvider.notifier).createKey(
                        code: code,
                        section: selectedSection,
                        maxUses: uses,
                      );
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Generated key "$code" for section $selectedSection'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  minimumSize: const Size(0, 40),
                ),
                child: const Text('Create Key', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
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
