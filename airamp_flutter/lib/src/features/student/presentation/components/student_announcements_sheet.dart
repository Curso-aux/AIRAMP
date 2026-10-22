import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../notifications/application/notification_provider.dart';
import '../../../notifications/domain/notification_model.dart';

/// Shows the unified Notifications & Announcements modal bottom sheet.
void showStudentAnnouncementsSheet(
  BuildContext context,
  List<Map<String, dynamic>> announcements,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _NotificationsAndAnnouncementsSheet(
      initialAnnouncements: announcements,
    ),
  );
}

class _NotificationsAndAnnouncementsSheet extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> initialAnnouncements;

  const _NotificationsAndAnnouncementsSheet({
    required this.initialAnnouncements,
  });

  @override
  ConsumerState<_NotificationsAndAnnouncementsSheet> createState() =>
      _NotificationsAndAnnouncementsSheetState();
}

class _NotificationsAndAnnouncementsSheetState
    extends ConsumerState<_NotificationsAndAnnouncementsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble_outline_rounded;
      case 'group_chat':
        return Icons.groups_rounded;
      case 'quiz':
        return Icons.quiz_rounded;
      case 'offline_sync':
        return Icons.folder_special_rounded;
      case 'security':
        return Icons.security_rounded;
      case 'announcement':
      default:
        return Icons.campaign_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'chat':
        return AppTheme.primary;
      case 'group_chat':
        return const Color(0xFF3B82F6);
      case 'quiz':
        return AppTheme.warning;
      case 'offline_sync':
        return AppTheme.success;
      case 'security':
        return const Color(0xFFEF4444);
      case 'announcement':
      default:
        return AppTheme.primary;
    }
  }

  String _formatTimestamp(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notificationsProvider);
    final notifications = notifState.notifications;
    final unreadCount = notifState.unreadCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter announcements if updated in ref
    final currentUser = ref.watch(authProvider);
    final allAnnouncements = ref.watch(announcementsProvider);
    final studentSection = currentUser?.section?.trim().toLowerCase();

    final announcements = allAnnouncements.isNotEmpty
        ? allAnnouncements.where((a) {
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
          }).toList()
        : widget.initialAnnouncements;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
            child: Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Notifications & Updates',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unreadCount > 0)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(notificationsProvider.notifier).markAllAsRead();
                    },
                    icon: Icon(Icons.done_all_rounded, size: 16, color: AppTheme.primary),
                    label: Text(
                      'Mark all read',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppTheme.text),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tab Bar Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceLight : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.black,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Flexible(
                          child: Text(
                            'Notifications',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.warning,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Flexible(
                          child: Text(
                            'Announcements',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (announcements.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${announcements.length}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),
          Divider(height: 1, color: AppTheme.border),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Messages & Activity
                _buildActivityAndMessagesTab(notifications),

                // Tab 2: Announcements
                _buildAnnouncementsTab(announcements),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityAndMessagesTab(List<AppNotification> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_none_rounded, color: AppTheme.primary, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'All Caught Up!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'New messages from teachers, classmates, group chats, and assessment alerts will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: notifications.length,
      itemBuilder: (context, i) {
        final notif = notifications[i];
        final color = _getNotificationColor(notif.type);
        final icon = _getNotificationIcon(notif.type);

        return Dismissible(
          key: Key(notif.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            ref.read(notificationsProvider.notifier).deleteNotification(notif.id);
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: notif.isRead
                  ? AppTheme.background
                  : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: notif.isRead ? AppTheme.border : color.withValues(alpha: 0.4),
                width: notif.isRead ? 1 : 1.3,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (!notif.isRead) {
                  ref.read(notificationsProvider.notifier).markAsRead(notif.id);
                }
                if (notif.targetRoute != null && notif.targetRoute!.isNotEmpty) {
                  Navigator.pop(context);
                  try {
                    context.push(notif.targetRoute!);
                  } catch (_) {}
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Icon(icon, color: color, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notif.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                    color: AppTheme.text,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatTimestamp(notif.createdAt),
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notif.message,
                            style: TextStyle(
                              color: notif.isRead ? AppTheme.textSecondary : AppTheme.text,
                              fontSize: 13,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!notif.isRead) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementsTab(List<Map<String, dynamic>> announcements) {
    if (announcements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.campaign_outlined, color: AppTheme.textMuted, size: 36),
              const SizedBox(height: 12),
              Text(
                'No announcements at this time.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
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
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Text(
                              'Section: $sec',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
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
                    Expanded(
                      child: Text(
                        'Posted by ${a['author_name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
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
