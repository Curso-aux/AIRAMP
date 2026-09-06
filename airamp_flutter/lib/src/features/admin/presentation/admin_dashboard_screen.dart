import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_provider.dart';
import '../data/admin_repository.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);
    final announcements = ref.watch(announcementsProvider);
    
    final initial = currentUser?.fullName.isNotEmpty == true 
        ? currentUser!.fullName[0].toUpperCase() 
        : 'T';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Dashboard', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                      Text(
                        currentUser?.fullName ?? 'Teacher John Reyes',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      initial,
                      style: const TextStyle(fontSize: 24, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Stats Cards Row
              Row(
                children: [
                  Expanded(child: _buildStatCard(context, 'Students', Icons.people_outline, '1')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(context, 'Subjects', Icons.menu_book, '0')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(context, 'Sections', Icons.layers, '1')),
                ],
              ),
              const SizedBox(height: 32),

              // Announcements Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign, color: AppTheme.warning, size: 20),
                      const SizedBox(width: 8),
                      Text('Announcements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _showPostAnnouncementSheet(context, ref),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.add, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (announcements.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Text(
                    'No announcements yet. Post one for your students.',
                    style: TextStyle(color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                  ),
                )
              else
                ...announcements.map((a) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: a['priority'] == 'Important' ? AppTheme.error : AppTheme.border,
                      width: a['priority'] == 'Important' ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              a['title'],
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold, 
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (a['priority'] == 'Important')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.errorSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Important',
                                style: TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 20),
                            color: Theme.of(context).colorScheme.surface,
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showPostAnnouncementSheet(context, ref, initialAnnouncement: a);
                              } else if (value == 'delete') {
                                ref.read(announcementsProvider.notifier).deleteAnnouncement(a['id']);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit', style: TextStyle(color: AppTheme.text)),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete', style: TextStyle(color: AppTheme.error)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a['message'],
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.people_outline, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                          const SizedBox(width: 4),
                          Text(
                            a['target_audience'],
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      )
                    ],
                  ),
                )),

              const SizedBox(height: 32),

              // Subjects Overview Section
              Text('Subjects Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Center(
                  child: Text(
                    'No subjects available',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, IconData icon, String count) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          const SizedBox(height: 12),
          Text(count, style: const TextStyle(color: AppTheme.text, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  void _showPostAnnouncementSheet(BuildContext context, WidgetRef ref, {Map<String, dynamic>? initialAnnouncement}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PostAnnouncementSheet(
        initialAnnouncement: initialAnnouncement,
        onPost: (announcement) {
          if (initialAnnouncement != null) {
            ref.read(announcementsProvider.notifier).updateAnnouncement(initialAnnouncement['id'], announcement);
          } else {
            ref.read(announcementsProvider.notifier).addAnnouncement(announcement);
          }
        },
      ),
    );
  }
}

class _PostAnnouncementSheet extends StatefulWidget {
  final Map<String, dynamic>? initialAnnouncement;
  final void Function(Map<String, dynamic> announcement) onPost;

  const _PostAnnouncementSheet({this.initialAnnouncement, required this.onPost});

  @override
  State<_PostAnnouncementSheet> createState() => _PostAnnouncementSheetState();
}

class _PostAnnouncementSheetState extends State<_PostAnnouncementSheet> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _priority = 'Normal';
  String _targetAudience = 'All My Students';

  @override
  void initState() {
    super.initState();
    if (widget.initialAnnouncement != null) {
      _titleController.text = widget.initialAnnouncement!['title'];
      _messageController.text = widget.initialAnnouncement!['message'];
      _priority = widget.initialAnnouncement!['priority'];
      _targetAudience = widget.initialAnnouncement!['target_audience'];
    }
  }

  final List<String> _priorities = ['Normal', 'Important'];
  final List<Map<String, dynamic>> _audiences = [
    {'label': 'All My Students', 'icon': Icons.people_outline},
    {'label': 'By Grade Level', 'icon': Icons.public},
    {'label': 'By Section', 'icon': Icons.menu_book},
    {'label': 'Specific Students', 'icon': Icons.person_outline},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialAnnouncement != null ? 'Edit Announcement' : 'Post Announcement',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 24),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title Field
            TextField(
              controller: _titleController,
              style: const TextStyle(color: AppTheme.text),
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: 12),

            // Message Field
            TextField(
              controller: _messageController,
              style: const TextStyle(color: AppTheme.text),
              decoration: const InputDecoration(hintText: 'Message...'),
              maxLines: 4,
            ),
            const SizedBox(height: 20),

            // Priority
            const Text('Priority', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ..._priorities.map((p) => _buildSelectableOption(
              label: p,
              isSelected: _priority == p,
              onTap: () => setState(() => _priority = p),
            )),
            const SizedBox(height: 20),

            // Target Audience
            const Text('Target Audience', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ..._audiences.map((a) => _buildSelectableOption(
              label: a['label'],
              icon: a['icon'],
              isSelected: _targetAudience == a['label'],
              onTap: () => setState(() => _targetAudience = a['label']),
            )),
            const SizedBox(height: 24),

            // Post Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_titleController.text.isNotEmpty && _messageController.text.isNotEmpty) {
                    widget.onPost({
                      'title': _titleController.text,
                      'message': _messageController.text,
                      'priority': _priority,
                      'target_audience': _targetAudience,
                      'created_at': DateTime.now().toIso8601String(),
                    });
                  }
                  Navigator.pop(context);
                },
                icon: Icon(widget.initialAnnouncement != null ? Icons.save : Icons.send, color: Colors.black, size: 18),
                label: Text(widget.initialAnnouncement != null ? 'Update Announcement' : 'Post Announcement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectableOption({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: isSelected ? Colors.black : AppTheme.textMuted),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

