import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../auth/application/auth_provider.dart';

/// Shows the announcements & notifications modal bottom sheet for students.
void showStudentAnnouncementsSheet(
  BuildContext context,
  List<Map<String, dynamic>> announcements,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.notifications_active, color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Announcements & Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.text),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: announcements.isEmpty
                ? Center(
                    child: Text('No announcements at this time.', style: TextStyle(color: AppTheme.textMuted)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: announcements.length,
                    itemBuilder: (context, i) {
                      final a = announcements[i];
                      final priority = a['priority']?.toString() ?? 'medium';
                      final isHigh = priority.toLowerCase() == 'high';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isHigh ? AppTheme.warning : AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (_) {
                                final sec = a['section']?.toString();
                                final hasSpecificSec = sec != null &&
                                    sec.isNotEmpty &&
                                    sec != 'All Sections' &&
                                    sec != 'All Handled Sections';
                                return Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isHigh
                                            ? AppTheme.warning.withValues(alpha: 0.2)
                                            : AppTheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        priority.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isHigh ? AppTheme.warning : AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    if (hasSpecificSec) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Text(
                                          'Section: $sec',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Text(
                                      a['created_at'] != null ? a['created_at'].toString().split('T').first : '',
                                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              a['title']?.toString() ?? '',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              a['message']?.toString() ?? '',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                            ),
                            if (a['author_name'] != null && a['author_name'].toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.person_outline, size: 12, color: AppTheme.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Posted by ${a['author_name']}',
                                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

/// Convenience helper to fetch student announcements from ref and display the sheet.
void showStudentAnnouncementsFromRef(
  BuildContext context,
  WidgetRef ref,
) {
  final currentUser = ref.read(authProvider);
  final allAnnouncements = ref.read(announcementsProvider);
  final studentSection = currentUser?.section?.trim().toLowerCase();

  final studentAnnouncements = allAnnouncements.where((a) {
    final aud = (a['target_audience'] as String? ?? 'all').toLowerCase();
    if (aud != 'all' && aud != 'students') return false;

    final aSec = (a['section'] as String?)?.trim();
    if (aSec == null ||
        aSec.isEmpty ||
        aSec == 'All Sections' ||
        aSec == 'All Handled Sections') {
      return true;
    }
    if (studentSection != null && studentSection.isNotEmpty) {
      return aSec.toLowerCase() == studentSection;
    }
    return false;
  }).toList();

  showStudentAnnouncementsSheet(context, studentAnnouncements);
}
