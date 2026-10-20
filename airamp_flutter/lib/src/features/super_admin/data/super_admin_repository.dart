import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';

// --- Super Admin Global Metrics Provider ---
final superAdminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await DatabaseHelper().getSuperAdminGlobalStats();
});

// --- System Audit Logs Provider ---
final superAdminAuditLogsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await DatabaseHelper().getAuditLogs(limit: 40);
});
