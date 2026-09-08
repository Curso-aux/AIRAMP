import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../data/admin_repository.dart';

class AdminWebAnnouncementsScreen extends ConsumerStatefulWidget {
  const AdminWebAnnouncementsScreen({super.key});

  @override
  ConsumerState<AdminWebAnnouncementsScreen> createState() => _AdminWebAnnouncementsScreenState();
}

class _AdminWebAnnouncementsScreenState extends ConsumerState<AdminWebAnnouncementsScreen> {
  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(isoString);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    } catch (_) {
      return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final announcements = ref.watch(announcementsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Announcements & Broadcasts',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Broadcast school updates, examination schedules, and reminders to teachers and students',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showCreateAnnouncementDialog(),
                  icon: const Icon(Icons.campaign, size: 18),
                  label: const Text('Post Announcement'),
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

            if (announcements.isEmpty)
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
                    Icon(Icons.campaign_outlined, size: 54, color: AppTheme.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'No Announcements Published',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Post a school announcement to notify students and teachers in the app.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: announcements.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final a = announcements[index];
                  final id = a['id'] as int? ?? 0;
                  final title = a['title'] as String? ?? '';
                  final message = a['message'] as String? ?? '';
                  final priority = a['priority'] as String? ?? 'normal';
                  final audience = a['target_audience'] as String? ?? 'all';
                  final date = _formatDate(a['created_at'] as String?);

                  final isHigh = priority.toLowerCase() == 'high';
                  final isMedium = priority.toLowerCase() == 'medium';

                  return Container(
                    padding: const EdgeInsets.all(20),
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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isHigh
                                            ? AppTheme.error
                                            : (isMedium ? AppTheme.warning : AppTheme.primary))
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    priority.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isHigh
                                          ? AppTheme.error
                                          : (isMedium ? AppTheme.warning : AppTheme.primary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Text(
                                    'Audience: ${audience.toUpperCase()}',
                                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              tooltip: 'Delete Announcement',
                              icon: const Icon(Icons.delete_outline, size: 18),
                              color: AppTheme.error,
                              onPressed: () => _confirmDelete(id, title),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: AppTheme.textMuted),
                            const SizedBox(width: 6),
                            Text('Published on $date', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateAnnouncementDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String selectedPriority = 'medium';
    String selectedAudience = 'all';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(Icons.campaign, color: AppTheme.primary, size: 24),
                const SizedBox(width: 10),
                Text('Post Announcement', style: TextStyle(fontSize: 18, color: AppTheme.text)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Announcement Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: AppTheme.text),
                    decoration: InputDecoration(
                      hintText: 'e.g. Schedule of 1st Semester Final Exams',
                      filled: true,
                      fillColor: AppTheme.background,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Target Audience', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: selectedAudience,
                              dropdownColor: AppTheme.surface,
                              style: TextStyle(color: AppTheme.text, fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppTheme.background,
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All (Students & Teachers)')),
                                DropdownMenuItem(value: 'students', child: Text('Students Only')),
                                DropdownMenuItem(value: 'teachers', child: Text('Teachers Only')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedAudience = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Priority Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: selectedPriority,
                              dropdownColor: AppTheme.surface,
                              style: TextStyle(color: AppTheme.text, fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppTheme.background,
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'high', child: Text('High Priority')),
                                DropdownMenuItem(value: 'medium', child: Text('Medium Priority')),
                                DropdownMenuItem(value: 'normal', child: Text('Normal Priority')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedPriority = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text('Message Body', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    style: TextStyle(color: AppTheme.text),
                    decoration: InputDecoration(
                      hintText: 'Enter the complete announcement message...',
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.border)),
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
                  final title = titleController.text.trim();
                  final message = messageController.text.trim();
                  if (title.isEmpty || message.isEmpty) return;

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogCtx);
                  await ref.read(announcementsProvider.notifier).addAnnouncement({
                    'title': title,
                    'message': message,
                    'priority': selectedPriority,
                    'target_audience': selectedAudience,
                    'created_at': DateTime.now().toIso8601String(),
                  });
                  ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Announcement posted successfully!'),
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
                child: const Text('Publish Announcement', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(int id, String title) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete Announcement', style: TextStyle(color: AppTheme.text)),
        content: Text('Permanently remove "$title"?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(announcementsProvider.notifier).deleteAnnouncement(id);
              ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
