import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/app_toast.dart';
import '../../../core/components/empty_state.dart';
import '../../../core/theme/app_theme.dart';
import '../application/notification_provider.dart';
import '../domain/notification_model.dart';

/// Full-featured In-App Notification Center supporting real-time search,
/// category filtering, multi-select mode, batch deletion, and deep-linking.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  final List<Map<String, String>> _categories = const [
    {'id': 'all', 'label': 'All'},
    {'id': 'unread', 'label': 'Unread'},
    {'id': 'assignments', 'label': 'Assignments'},
    {'id': 'quizzes', 'label': 'Quizzes'},
    {'id': 'announcements', 'label': 'Announcements'},
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleItemSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<AppNotification> items) {
    setState(() {
      final allSelected =
          items.isNotEmpty && items.every((n) => _selectedIds.contains(n.id));
      if (allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(items.map((n) => n.id));
      }
    });
  }

  Future<void> _confirmBatchDelete() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete $count Notification${count > 1 ? 's' : ''}?',
          style: TextStyle(
            color: AppTheme.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete the selected notification${count > 1 ? 's' : ''}?',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final deleted = await ref
          .read(notificationsProvider.notifier)
          .deleteBatchNotifications(_selectedIds.toList());

      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        AppToast.showSuccess(
          context,
          '$deleted notification${deleted > 1 ? 's' : ''} deleted successfully.',
        );
      }
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
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate.split('T').first;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'chat':
      case 'group_chat':
        return const Color(0xFF3B82F6);
      case 'new_assignment':
      case 'activity_submission':
        return AppTheme.primary;
      case 'grade_released':
      case 'resubmission_allowed':
        return const Color(0xFF10B981);
      case 'quiz':
      case 'quiz_assigned':
      case 'quiz_completed':
        return AppTheme.warning;
      case 'security':
        return AppTheme.error;
      case 'announcement':
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble_outline_rounded;
      case 'group_chat':
        return Icons.groups_outlined;
      case 'new_assignment':
        return Icons.assignment_outlined;
      case 'activity_submission':
        return Icons.file_upload_outlined;
      case 'grade_released':
        return Icons.grade_outlined;
      case 'resubmission_allowed':
        return Icons.replay_outlined;
      case 'quiz':
      case 'quiz_assigned':
      case 'quiz_completed':
        return Icons.quiz_outlined;
      case 'security':
        return Icons.security_outlined;
      case 'announcement':
      default:
        return Icons.campaign_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = ref.watch(filteredNotificationsProvider);
    final activeCategory = ref.watch(notificationCategoryFilterProvider);
    final currentQuery = ref.watch(notificationSearchQueryProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.text),
          onPressed: () {
            if (_isSelectionMode) {
              setState(() {
                _isSelectionMode = false;
                _selectedIds.clear();
              });
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Text(
          _isSelectionMode
              ? '${_selectedIds.length} Selected'
              : 'Notifications',
          style: TextStyle(
            color: AppTheme.text,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_isSelectionMode) ...[
            if (unreadCount > 0)
              IconButton(
                icon: Icon(Icons.done_all_rounded, color: AppTheme.primary),
                tooltip: 'Mark all as read',
                onPressed: () {
                  ref.read(notificationsProvider.notifier).markAllAsRead();
                  AppToast.showSuccess(
                    context,
                    'All notifications marked as read.',
                  );
                },
              ),
            IconButton(
              icon: Icon(
                _isSelectionMode
                    ? Icons.close_rounded
                    : Icons.checklist_rounded,
                color: AppTheme.text,
              ),
              tooltip: 'Select multiple',
              onPressed: _toggleSelectionMode,
            ),
          ] else ...[
            TextButton(
              onPressed: _toggleSelectionMode,
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: AppTheme.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search notifications...',
                  hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: AppTheme.textMuted,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(notificationSearchQueryProvider.notifier)
                                .clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.background,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                ),
                onChanged: (val) {
                  ref
                      .read(notificationSearchQueryProvider.notifier)
                      .setQuery(val);
                },
              ),
            ),
          ),

          // 2. Category Filter Chips
          Container(
            color: AppTheme.surface,
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = activeCategory == cat['id'];
                final isUnread = cat['id'] == 'unread';

                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat['label']!),
                      if (isUnread && unreadCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.3)
                                : AppTheme.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.background,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.border.withValues(alpha: isDark ? 0.6 : 0.9),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(notificationCategoryFilterProvider.notifier)
                          .setCategory(cat['id']!);
                    }
                  },
                );
              },
            ),
          ),

          Divider(height: 1, color: AppTheme.border),

          // 3. Multi-Select Batch Action Bar
          if (_isSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.text,
                      side: BorderSide(color: AppTheme.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    icon: Icon(
                      filteredList.isNotEmpty &&
                              filteredList.every(
                                (n) => _selectedIds.contains(n.id),
                              )
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                      size: 18,
                    ),
                    label: Text(
                      filteredList.isNotEmpty &&
                              filteredList.every(
                                (n) => _selectedIds.contains(n.id),
                              )
                          ? 'Deselect All'
                          : 'Select All',
                      style: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () => _selectAll(filteredList),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.error.withValues(
                        alpha: 0.3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(
                      'Delete Selected (${_selectedIds.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : _confirmBatchDelete,
                  ),
                ],
              ),
            ),

          // 4. Notification List / Empty States
          Expanded(
            child: filteredList.isEmpty
                ? (currentQuery.isNotEmpty
                      ? Center(
                          child: AppEmptyState.search(
                            query: currentQuery,
                            onClearSearch: () {
                              _searchController.clear();
                              ref
                                  .read(
                                    notificationSearchQueryProvider.notifier,
                                  )
                                  .clear();
                            },
                          ),
                        )
                      : Center(
                          child: AppEmptyState(
                            icon: Icons.notifications_none_rounded,
                            title: activeCategory == 'unread'
                                ? 'No Unread Notifications'
                                : 'All Caught Up!',
                            message: activeCategory == 'unread'
                                ? 'You have read all your notifications.'
                                : 'No activity notifications available at this time.',
                          ),
                        ))
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref
                          .read(notificationsProvider.notifier)
                          .loadNotifications();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final notif = filteredList[index];
                        final isSelected = _selectedIds.contains(notif.id);
                        final color = _getNotificationColor(notif.type);
                        final icon = _getNotificationIcon(notif.type);

                        return Dismissible(
                          key: Key('notif_dismiss_${notif.id}'),
                          direction: _isSelectionMode
                              ? DismissDirection.none
                              : DismissDirection.endToStart,
                          onDismissed: (_) {
                            ref
                                .read(notificationsProvider.notifier)
                                .deleteNotification(notif.id);
                            AppToast.showSuccess(
                              context,
                              'Notification deleted.',
                            );
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withValues(alpha: 0.12)
                                  : (notif.isRead
                                        ? AppTheme.surface
                                        : color.withValues(alpha: 0.08)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : (notif.isRead
                                          ? AppTheme.border
                                          : color.withValues(alpha: 0.35)),
                                width: isSelected
                                    ? 1.5
                                    : (notif.isRead ? 1 : 1.2),
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleItemSelection(notif.id);
                                } else {
                                  if (!notif.isRead) {
                                    ref
                                        .read(notificationsProvider.notifier)
                                        .markAsRead(notif.id);
                                  }
                                  if (notif.targetRoute != null &&
                                      notif.targetRoute!.isNotEmpty) {
                                    try {
                                      context.push(notif.targetRoute!);
                                    } catch (_) {}
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_isSelectionMode) ...[
                                      Checkbox(
                                        value: isSelected,
                                        activeColor: AppTheme.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        onChanged: (_) =>
                                            _toggleItemSelection(notif.id),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: color.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Icon(icon, color: color, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notif.title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: notif.isRead
                                                        ? FontWeight.w600
                                                        : FontWeight.bold,
                                                    color: AppTheme.text,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _formatTimestamp(
                                                  notif.createdAt,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            notif.message,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: notif.isRead
                                                  ? AppTheme.textMuted
                                                  : AppTheme.textSecondary,
                                              height: 1.35,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (notif.actorName != null &&
                                              notif.actorName!.isNotEmpty &&
                                              notif.type != 'chat' &&
                                              notif.type != 'group_chat' &&
                                              notif.actorName !=
                                                  'Classmate') ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.person_outline_rounded,
                                                  size: 13,
                                                  color: AppTheme.textMuted,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  notif.actorName!,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.textMuted,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (!notif.isRead && !_isSelectionMode) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(top: 6),
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
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
