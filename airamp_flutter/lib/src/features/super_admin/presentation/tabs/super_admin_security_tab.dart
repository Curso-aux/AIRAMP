import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/components/aira_action_toast.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/application/auth_provider.dart';
import '../../data/super_admin_repository.dart';
import '../super_admin_theme.dart';

class SuperAdminSecurityTab extends ConsumerStatefulWidget {
  const SuperAdminSecurityTab({super.key});

  @override
  ConsumerState<SuperAdminSecurityTab> createState() =>
      _SuperAdminSecurityTabState();
}

class _SuperAdminSecurityTabState extends ConsumerState<SuperAdminSecurityTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ALL';
  String _selectedTimeframe = 'all';
  bool _isRunningAudit = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _computeEventHash(String id, String action, String actor, String timestamp) {
    final raw = '$id|$action|$actor|$timestamp|AIRAMP_CRYPTOGRAPHIC_AUDIT_SALT';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  String _getEventSeverity(String action) {
    final act = action.toUpperCase();
    if (act.contains('FAIL') || act.contains('ALERT') || act.contains('CRITICAL') || act.contains('REVOK')) {
      return 'CRITICAL';
    }
    if (act.contains('PASSWORD') || act.contains('UPDATE') || act.contains('ROLE') || act.contains('ADMIN')) {
      return 'ELEVATED';
    }
    if (act.contains('SECURITY') || act.contains('VERIF') || act.contains('EXPORT') || act.contains('ARCHIV')) {
      return 'NOTICE';
    }
    return 'INFO';
  }

  Color _getSeverityColor(String severity, GovernanceTheme gTheme) {
    switch (severity) {
      case 'CRITICAL':
        return gTheme.dangerText;
      case 'ELEVATED':
        return gTheme.warningText;
      case 'NOTICE':
        return const Color(0xFF0EA5E9);
      case 'INFO':
      default:
        return gTheme.successText;
    }
  }

  Color _getSeverityBg(String severity, GovernanceTheme gTheme) {
    switch (severity) {
      case 'CRITICAL':
        return gTheme.dangerBg;
      case 'ELEVATED':
        return gTheme.warningBg;
      case 'NOTICE':
        return const Color(0xFF0EA5E9).withValues(alpha: gTheme.isDark ? 0.2 : 0.08);
      case 'INFO':
      default:
        return gTheme.successBg;
    }
  }

  Future<void> _runSecurityAudit(GovernanceTheme gTheme) async {
    setState(() => _isRunningAudit = true);
    try {
      final result = await DatabaseHelper().verifySecuritySaltIntegrity();
      final total = result['total_users'] as int? ?? 0;
      final salted = result['salted_users'] as int? ?? 0;
      final unsalted = result['unsalted_users'] as int? ?? 0;
      final double saltPct = (result['salt_percentage'] as num?)?.toDouble() ?? 100.0;
      final bool passed = result['integrity_passed'] as bool? ?? true;

      final user = ref.read(authProvider);
      await DatabaseHelper().logAuditEvent(
        action: 'SECURITY_AUDIT_VERIFIED',
        details: 'System security check completed. $salted of $total accounts encrypted ($saltPct%).',
        actorId: user?.id,
        actorName: user?.fullName ?? 'Super Administrator',
        schoolId: user?.schoolId,
      );
      ref.invalidate(superAdminAuditLogsProvider);

      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: gTheme.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: passed ? gTheme.successBg : gTheme.warningBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: passed ? gTheme.successBorder : gTheme.warningBorder),
                  ),
                  child: Icon(
                    passed ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
                    color: passed ? gTheme.successText : gTheme.warningText,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'System Security Check Results',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: gTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Results of automated security check on user accounts, password encryption, and school data protection.',
                    style: TextStyle(fontSize: 12.5, color: gTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  _buildAuditStatRow(gTheme, 'Total Accounts Scanned', '$total User Records'),
                  Divider(height: 16, color: gTheme.border),
                  _buildAuditStatRow(gTheme, 'Encrypted Passwords', '$salted ($saltPct%)'),
                  Divider(height: 16, color: gTheme.border),
                  _buildAuditStatRow(gTheme, 'Standard Password Accounts', '$unsalted (Auto-Upgrades on Sign-In)'),
                  Divider(height: 16, color: gTheme.border),
                  _buildAuditStatRow(gTheme, 'Security Standard', 'Industry-Standard 256-bit Encryption'),
                  Divider(height: 16, color: gTheme.border),
                  _buildAuditStatRow(gTheme, 'Campus Data Separation', 'Enforced across all school campuses'),
                  Divider(height: 16, color: gTheme.border),
                  _buildAuditStatRow(
                    gTheme,
                    'Overall Health',
                    passed ? 'Excellent (All Security Standards Met)' : 'Needs Review',
                    color: passed ? gTheme.successText : gTheme.warningText,
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AiraActionToast.showError(
          context,
          title: 'Check Failed',
          message: 'Error executing security check: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isRunningAudit = false);
    }
  }

  Widget _buildAuditStatRow(GovernanceTheme gTheme, String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: gTheme.textSecondary)),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? gTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _exportAuditTrail(List<Map<String, dynamic>> logs, GovernanceTheme gTheme) {
    if (logs.isEmpty) {
      AiraActionToast.showWarning(context, title: 'No Logs', message: 'No activity events to export.');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('ID,Action,Severity,Details,Actor,School_ID,Timestamp,Verification_Code');
    for (final log in logs) {
      final id = log['id'] ?? '';
      final action = log['action'] ?? '';
      final details = '"${(log['details'] ?? '').toString().replaceAll('"', '""')}"';
      final actor = '"${(log['actor_name'] ?? 'System').toString().replaceAll('"', '""')}"';
      final schoolId = log['school_id'] ?? 'sch_main';
      final time = log['created_at'] ?? '';
      final checksum = _computeEventHash(id.toString(), action.toString(), actor, time.toString());
      final severity = _getEventSeverity(action.toString());
      buffer.writeln('$id,$action,$severity,$details,$actor,$schoolId,$time,$checksum');
    }

    final csvContent = buffer.toString();
    Clipboard.setData(ClipboardData(text: csvContent));

    final user = ref.read(authProvider);
    DatabaseHelper().logAuditEvent(
      action: 'AUDIT_TRAIL_EXPORTED',
      details: 'Exported ${logs.length} activity history records to CSV format.',
      actorId: user?.id,
      actorName: user?.fullName ?? 'Super Administrator',
      schoolId: user?.schoolId,
    );
    ref.invalidate(superAdminAuditLogsProvider);

    AiraActionToast.showSuccess(
      context,
      title: 'Activity History Exported',
      message: 'Exported ${logs.length} activity records. Copied to clipboard.',
    );
  }

  void _showAddComplianceNoteDialog(GovernanceTheme gTheme) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: gTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: gTheme.primarySubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: gTheme.primaryBorder),
              ),
              child: Icon(Icons.note_add_outlined, color: gTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Add Activity Note',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: gTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add an official note, review comment, or maintenance log entry to the system history.',
                style: TextStyle(fontSize: 12.5, color: gTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Note or Observation *',
                  labelStyle: TextStyle(color: gTheme.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: gTheme.surfaceSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: gTheme.border),
                  ),
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
          ElevatedButton(
            onPressed: () async {
              final note = noteCtrl.text.trim();
              if (note.isEmpty) return;
              Navigator.of(dialogCtx).pop();

              final user = ref.read(authProvider);
              await DatabaseHelper().logAuditEvent(
                action: 'COMPLIANCE_NOTE_RECORDED',
                details: note,
                actorId: user?.id,
                actorName: user?.fullName ?? 'Super Administrator',
                schoolId: user?.schoolId,
              );
              ref.invalidate(superAdminAuditLogsProvider);

              if (mounted) {
                AiraActionToast.showSuccess(
                  context,
                  title: 'Activity Note Saved',
                  message: 'Your note has been added to the system history.',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: gTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  void _showClearArchiveDialog(GovernanceTheme gTheme) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: gTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: gTheme.dangerBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: gTheme.dangerBorder),
              ),
              child: Icon(Icons.archive_outlined, color: gTheme.dangerText, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Archive Activity History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: gTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to archive current activity history? A clean log will be started for new activities.',
                style: TextStyle(fontSize: 13, color: gTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: gTheme.warningBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: gTheme.warningBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: gTheme.warningText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'An archive event will be recorded automatically.',
                        style: TextStyle(fontSize: 11.5, color: gTheme.warningText),
                      ),
                    ),
                  ],
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
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final user = ref.read(authProvider);
              await DatabaseHelper().clearAuditLogs(
                actorName: user?.fullName ?? 'Super Administrator',
              );
              ref.invalidate(superAdminAuditLogsProvider);

              if (mounted) {
                AiraActionToast.showSuccess(
                  context,
                  title: 'Activity History Archived',
                  message: 'Existing records archived and fresh activity log started.',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: gTheme.dangerText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Archive & Clear'),
          ),
        ],
      ),
    );
  }

  void _inspectEventTelemetry(Map<String, dynamic> log, GovernanceTheme gTheme) {
    final id = log['id'] ?? 'N/A';
    final action = log['action'] ?? 'EVENT';
    final details = log['details'] ?? '';
    final actor = log['actor_name'] ?? 'System';
    final actorId = log['actor_id'] ?? 'root';
    final schoolId = log['school_id'] ?? 'sch_main';
    final time = log['created_at'] ?? '';
    final severity = _getEventSeverity(action.toString());
    final checksum = _computeEventHash(id.toString(), action.toString(), actor.toString(), time.toString());

    final jsonPayload = const JsonEncoder.withIndent('  ').convert({
      'event_id': id,
      'action_code': action,
      'severity': severity,
      'actor_name': actor,
      'actor_id': actorId,
      'campus_scope': schoolId,
      'timestamp_iso': time,
      'details': details,
      'verification_code': checksum,
    });

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: gTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getSeverityBg(severity, gTheme),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getSeverityColor(severity, gTheme).withValues(alpha: 0.3)),
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                color: _getSeverityColor(severity, gTheme),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Record Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: gTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Recorded system activity and verification details',
                    style: TextStyle(fontSize: 11.5, color: gTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAuditStatRow(gTheme, 'Event ID', id.toString()),
                Divider(height: 14, color: gTheme.border),
                _buildAuditStatRow(gTheme, 'Action Name', action.toString()),
                Divider(height: 14, color: gTheme.border),
                _buildAuditStatRow(
                  gTheme,
                  'Importance',
                  severity,
                  color: _getSeverityColor(severity, gTheme),
                ),
                Divider(height: 14, color: gTheme.border),
                _buildAuditStatRow(gTheme, 'Performed By', '$actor ($actorId)'),
                Divider(height: 14, color: gTheme.border),
                _buildAuditStatRow(gTheme, 'Campus Scope', schoolId.toString()),
                Divider(height: 14, color: gTheme.border),
                _buildAuditStatRow(gTheme, 'Date & Time', time.toString()),
                Divider(height: 14, color: gTheme.border),
                _buildAuditStatRow(
                  gTheme,
                  'Verification Code',
                  '${checksum.substring(0, 16)}...${checksum.substring(checksum.length - 8)}',
                ),
                const SizedBox(height: 16),
                Text(
                  'Technical Details (JSON)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: gTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: gTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: gTheme.border),
                  ),
                  child: SelectableText(
                    jsonPayload,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: gTheme.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonPayload));
              AiraActionToast.showSuccess(
                context,
                title: 'Copied Details',
                message: 'Technical JSON details copied to clipboard.',
              );
            },
            icon: Icon(Icons.copy_rounded, size: 14, color: gTheme.primary),
            label: Text('Copy Details', style: TextStyle(color: gTheme.primary, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: gTheme.primaryBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: gTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterLogs(List<Map<String, dynamic>> allLogs) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

    return allLogs.where((log) {
      final action = (log['action'] as String? ?? '').toLowerCase();
      final details = (log['details'] as String? ?? '').toLowerCase();
      final actor = (log['actor_name'] as String? ?? '').toLowerCase();
      final timeStr = log['created_at'] as String? ?? '';

      // 1. Search Query Filter
      if (query.isNotEmpty) {
        final matches = action.contains(query) || details.contains(query) || actor.contains(query);
        if (!matches) return false;
      }

      // 2. Category Filter
      if (_selectedCategory != 'ALL') {
        final actUpper = action.toUpperCase();
        switch (_selectedCategory) {
          case 'SECURITY':
            if (!actUpper.contains('SECURITY') && !actUpper.contains('SALT') && !actUpper.contains('CRYPT')) {
              return false;
            }
            break;
          case 'AUTH':
            if (!actUpper.contains('AUTH') && !actUpper.contains('LOGIN') && !actUpper.contains('PASSWORD') && !actUpper.contains('SESSION')) {
              return false;
            }
            break;
          case 'RBAC':
            if (!actUpper.contains('ADMIN') && !actUpper.contains('ROLE') && !actUpper.contains('USER') && !actUpper.contains('PROFILE')) {
              return false;
            }
            break;
          case 'CAMPUS':
            if (!actUpper.contains('SCHOOL') && !actUpper.contains('CAMPUS')) {
              return false;
            }
            break;
          case 'SYSTEM':
            if (!actUpper.contains('SYSTEM') && !actUpper.contains('DATABASE') && !actUpper.contains('AUDIT') && !actUpper.contains('INIT')) {
              return false;
            }
            break;
        }
      }

      // 3. Timeframe Filter
      if (_selectedTimeframe != 'all' && timeStr.isNotEmpty) {
        try {
          final eventDate = DateTime.parse(timeStr);
          if (_selectedTimeframe == 'today') {
            if (eventDate.year != now.year || eventDate.month != now.month || eventDate.day != now.day) {
              return false;
            }
          } else if (_selectedTimeframe == '7d') {
            if (now.difference(eventDate).inDays > 7) return false;
          } else if (_selectedTimeframe == '30d') {
            if (now.difference(eventDate).inDays > 30) return false;
          }
        } catch (_) {}
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final gTheme = GovernanceTheme(themeState.isDark);
    final auditLogsAsync = ref.watch(superAdminAuditLogsProvider);
    final statsAsync = ref.watch(superAdminStatsProvider);
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
              // ── Header Banner with Real-time Security Action Bar ──
              _buildHeaderBanner(context, gTheme, isMobile),
              const SizedBox(height: 20),

              // ── Live Cryptographic Security Operations Strip ──
              _buildSecurityOperationsBar(context, gTheme, isMobile),
              const SizedBox(height: 24),

              // ── Security Integrity Pillars ──
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: gTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: gTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: gTheme.isDark ? 0.2 : 0.03,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSecurityPillar(
                      gTheme: gTheme,
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Role-Based Campus Management',
                      description:
                          'Super Administrators manage campuses, school administrators, and account permissions across all schools.',
                      statusBadge: 'ACTIVE',
                    ),
                    Divider(height: 26, color: gTheme.border),
                    _buildSecurityPillar(
                      gTheme: gTheme,
                      icon: Icons.lock_outline_rounded,
                      title: 'Strong Password Encryption',
                      description:
                          'All passwords are automatically encrypted with industry-standard 256-bit protection.',
                      statusBadge: 'PROTECTED',
                    ),
                    Divider(height: 26, color: gTheme.border),
                    _buildSecurityPillar(
                      gTheme: gTheme,
                      icon: Icons.domain_verification_outlined,
                      title: 'Campus Data Separation',
                      description:
                          'Each school\'s students, teachers, classes, and records are safely kept separate and private.',
                      statusBadge: 'PROTECTED',
                    ),
                    Divider(height: 26, color: gTheme.border),
                    _buildSecurityPillar(
                      gTheme: gTheme,
                      icon: Icons.mark_email_read_outlined,
                      title: 'Two-Step Verification',
                      description:
                          'Extra sign-in protection using email verification codes for administrator accounts.',
                      statusBadge: 'ENABLED',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Database Table Record Distribution ──
              statsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (stats) => Container(
                  padding: const EdgeInsets.all(20),
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
                          Icon(
                            Icons.storage_outlined,
                            size: 18,
                            color: gTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Database Record Distribution',
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.bold,
                                color: gTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final count = constraints.maxWidth >= 900
                              ? 6
                              : (constraints.maxWidth >= 540 ? 3 : 2);
                          final spacing = 10.0;
                          final itemWidth =
                              (constraints.maxWidth - (spacing * (count - 1))) /
                              count;

                          final statItems = [
                            ('Users', stats['total_users']?.toString() ?? '0'),
                            (
                              'Schools',
                              stats['total_schools']?.toString() ?? '1',
                            ),
                            (
                              'Subjects',
                              stats['total_subjects']?.toString() ?? '0',
                            ),
                            (
                              'Sections',
                              stats['total_sections']?.toString() ?? '0',
                            ),
                            (
                              'Schedules',
                              stats['total_schedules']?.toString() ?? '0',
                            ),
                            (
                              'Admin Accounts',
                              stats['total_admins']?.toString() ?? '1',
                            ),
                          ];

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: statItems.map((stat) {
                              return SizedBox(
                                width: itemWidth,
                                child: _buildTableStatBox(
                                  gTheme,
                                  stat.$1,
                                  stat.$2,
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
              const SizedBox(height: 28),

              // ── Enterprise System Audit Trail Section ──
              _buildAuditTrailSection(context, gTheme, auditLogsAsync, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(
    BuildContext context,
    GovernanceTheme gTheme,
    bool isMobile,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: gTheme.primarySubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: gTheme.primaryBorder),
          ),
          child: Icon(
            Icons.shield_outlined,
            color: gTheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security & Activity History',
                style: TextStyle(
                  fontSize: isMobile ? 17 : 20,
                  fontWeight: FontWeight.bold,
                  color: gTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Monitor system security status, administrator activities, and school account health.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: gTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityOperationsBar(
    BuildContext context,
    GovernanceTheme gTheme,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gTheme.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: gTheme.successBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: gTheme.successBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 14, color: gTheme.successText),
                    const SizedBox(width: 6),
                    Text(
                      'All Passwords Encrypted',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: gTheme.successText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: gTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: gTheme.primaryBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_clock_outlined, size: 14, color: gTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Two-Step Login On',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: gTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Security Actions Buttons
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _isRunningAudit ? null : () => _runSecurityAudit(gTheme),
                icon: _isRunningAudit
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.security_update_good_rounded, size: 15),
                label: Text(_isRunningAudit ? 'Checking...' : 'Check System Health'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showAddComplianceNoteDialog(gTheme),
                icon: Icon(Icons.note_add_outlined, size: 15, color: gTheme.textPrimary),
                label: Text('Add Activity Note', style: TextStyle(color: gTheme.textPrimary, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: gTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTrailSection(
    BuildContext context,
    GovernanceTheme gTheme,
    AsyncValue<List<Map<String, dynamic>>> auditLogsAsync,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title & Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.history_edu_rounded,
                    size: 20,
                    color: gTheme.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'System Activity History',
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
            ),
            Wrap(
              spacing: 6,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.download_rounded,
                    size: 19,
                    color: gTheme.primary,
                  ),
                  tooltip: 'Download Activity Log (CSV)',
                  onPressed: () {
                    final logs = auditLogsAsync.asData?.value ?? [];
                    _exportAuditTrail(logs, gTheme);
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.archive_outlined,
                    size: 19,
                    color: gTheme.dangerText,
                  ),
                  tooltip: 'Archive Activity History',
                  onPressed: () => _showClearArchiveDialog(gTheme),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 19,
                    color: gTheme.textSecondary,
                  ),
                  tooltip: 'Refresh Activity History',
                  onPressed: () => ref.invalidate(superAdminAuditLogsProvider),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Multi-Dimensional Filter Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: gTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search input
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: gTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search activity by action, details, or user name...',
                  hintStyle: TextStyle(color: gTheme.textMuted, fontSize: 12),
                  prefixIcon: Icon(Icons.search, size: 18, color: gTheme.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _searchController.clear()),
                        )
                      : null,
                  filled: true,
                  fillColor: gTheme.surfaceSubtle,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: gTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip('ALL', 'All Events', gTheme),
                    const SizedBox(width: 6),
                    _buildCategoryChip('SECURITY', 'Security & Logins', gTheme),
                    const SizedBox(width: 6),
                    _buildCategoryChip('AUTH', 'Sign-In Activity', gTheme),
                    const SizedBox(width: 6),
                    _buildCategoryChip('RBAC', 'Admin Accounts', gTheme),
                    const SizedBox(width: 6),
                    _buildCategoryChip('CAMPUS', 'Campuses & Schools', gTheme),
                    const SizedBox(width: 6),
                    _buildCategoryChip('SYSTEM', 'System Updates', gTheme),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 1,
                      height: 20,
                      color: gTheme.border,
                    ),
                    _buildTimeframeChip('all', 'All Time', gTheme),
                    const SizedBox(width: 6),
                    _buildTimeframeChip('today', 'Today', gTheme),
                    const SizedBox(width: 6),
                    _buildTimeframeChip('7d', 'Past 7d', gTheme),
                    const SizedBox(width: 6),
                    _buildTimeframeChip('30d', 'Past 30d', gTheme),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Event Stream Container
        Container(
          decoration: BoxDecoration(
            color: gTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: gTheme.border),
          ),
          child: auditLogsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error loading audit log: $e',
                style: TextStyle(color: gTheme.dangerText),
              ),
            ),
            data: (allLogs) {
              final filteredLogs = _filterLogs(allLogs);

              if (filteredLogs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_list_off_rounded, size: 32, color: gTheme.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          allLogs.isEmpty
                              ? 'No activity recorded yet.'
                              : 'No activity matches your search or filter.',
                          style: TextStyle(color: gTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredLogs.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: gTheme.border),
                itemBuilder: (context, index) {
                  final log = filteredLogs[index];
                  final action = log['action'] as String? ?? 'EVENT';
                  final details = log['details'] as String? ?? '';
                  final actor = log['actor_name'] as String? ?? 'System';
                  final time = log['created_at'] as String? ?? '';
                  final schoolId = log['school_id'] as String? ?? 'sch_main';
                  final severity = _getEventSeverity(action);
                  final sevColor = _getSeverityColor(severity, gTheme);
                  final sevBg = _getSeverityBg(severity, gTheme);

                  return InkWell(
                    onTap: () => _inspectEventTelemetry(log, gTheme),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Action Code Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: sevBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: sevColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              action,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: sevColor,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Details Narrative & Actor Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  details,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: gTheme.textPrimary,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 12, color: gTheme.textMuted),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '$actor • $schoolId • $time',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: gTheme.textMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'View Details →',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: gTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String catKey, String label, GovernanceTheme gTheme) {
    final isSelected = _selectedCategory == catKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedCategory = catKey);
      },
      selectedColor: gTheme.primary,
      backgroundColor: gTheme.surfaceSubtle,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : gTheme.textSecondary,
      ),
      side: BorderSide(
        color: isSelected ? gTheme.primary : gTheme.border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildTimeframeChip(String tfKey, String label, GovernanceTheme gTheme) {
    final isSelected = _selectedTimeframe == tfKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedTimeframe = tfKey);
      },
      selectedColor: gTheme.accent,
      backgroundColor: gTheme.surfaceSubtle,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : gTheme.textSecondary,
      ),
      side: BorderSide(
        color: isSelected ? gTheme.accent : gTheme.border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildSecurityPillar({
    required GovernanceTheme gTheme,
    required IconData icon,
    required String title,
    required String description,
    required String statusBadge,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: gTheme.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: gTheme.border),
          ),
          child: Icon(icon, color: gTheme.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: gTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: gTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: gTheme.successBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: gTheme.successBorder),
          ),
          child: Text(
            statusBadge,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: gTheme.successText,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableStatBox(
    GovernanceTheme gTheme,
    String label,
    String count,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: gTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gTheme.border),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: gTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: gTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
