import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

import '../application/chat_provider.dart';
import '../domain/chat_models.dart';

/// Helper to get the first character of a name as uppercase for avatar.
String _getAvatarText(String name) {
  if (name.isEmpty) return '?';
  return name[0].toUpperCase();
}

/// Helper to get a human-readable role label.
String _getRoleLabel(String role) {
  if (role == 'super_admin') return 'Super Admin';
  if (role == 'admin') return 'Admin/Teacher';
  return 'Student';
}

/// Full-screen modal for starting a new conversation.
/// Cloned from rork's ChatListScreen.tsx Modal (lines 380–505).
class NewConversationModal extends ConsumerStatefulWidget {
  const NewConversationModal({super.key});

  @override
  ConsumerState<NewConversationModal> createState() =>
      _NewConversationModalState();
}

class _NewConversationModalState extends ConsumerState<NewConversationModal>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeTab = 'users'; // 'users' or 'contacts'
  String? _creatingChatUserId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _activeTab = _tabController.index == 0 ? 'users' : 'contacts';
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Filter users locally by name, email, or role.
  List<ChatUser> _filterUsers(List<ChatUser> users, String query) {
    if (query.trim().isEmpty) return users;
    final lower = query.toLowerCase();
    return users.where((u) {
      return u.fullName.toLowerCase().contains(lower) ||
          u.email.toLowerCase().contains(lower) ||
          _getRoleLabel(u.role).toLowerCase().contains(lower);
    }).toList();
  }

  Future<void> _handleStartChat(ChatUser user) async {
    setState(() => _creatingChatUserId = user.id);

    final conv =
        await ref.read(chatProvider.notifier).getOrCreateConversation(user.id);

    if (!mounted) return;
    setState(() => _creatingChatUserId = null);

    if (conv != null) {
      Navigator.of(context).pop(conv);
    }
  }

  @override
  Widget build(BuildContext context) {
    
    final chatState = ref.watch(chatProvider);
    final allUsers = chatState.availableUsers;
    final filteredUsers = _filterUsers(allUsers, _searchQuery);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Modal Header ──
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(
                  bottom: BorderSide(color: AppTheme.border, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Conversation',
                    style: TextStyle(
                      color: AppTheme.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close,
                      color: AppTheme.text,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab Bar ──
            Container(
              color: AppTheme.surface,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 2,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(text: 'App Users'),
                  Tab(text: 'Device Contacts'),
                ],
              ),
            ),

            // ── Search Bar ──
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Color(0x0DFFFFFF), // rgba(255,255,255,0.05)
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: AppTheme.textMuted, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: _activeTab == 'users'
                            ? 'Search users by name, email, or role...'
                            : 'Search contacts...',
                        hintStyle: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 4),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Icon(
                        Icons.close,
                        color: AppTheme.textMuted,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),

            // ── Tab Content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── App Users Tab ──
                  _buildUsersTab(filteredUsers),

                  // ── Device Contacts Tab ──
                  _buildContactsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab(List<ChatUser> users) {
    
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 80),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 48,
                color: AppTheme.textMuted.withValues(alpha: 0.5),
              ),
              SizedBox(height: 12),
              Text(
                'No users available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No users match your search.'
                    : 'You do not have permission to message anyone yet.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isCreating = _creatingChatUserId == user.id;

        return InkWell(
          onTap: isCreating ? null : () => _handleStartChat(user),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.border, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getAvatarText(user.fullName),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                SizedBox(width: 12),

                // Name + Role · Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${_getRoleLabel(user.role)} · ${user.email}',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Chevron or loading indicator
                if (isCreating)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactsTab() {
    
    // Device contacts placeholder — mirrors rork's empty state
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contacts_outlined,
              size: 48,
              color: AppTheme.textMuted.withValues(alpha: 0.5),
            ),
            SizedBox(height: 12),
            Text(
              'No matched contacts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Contacts from your device that have AIRA accounts will appear here.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement device contact import
              },
              icon: Icon(Icons.contacts_outlined, color: Colors.black),
              label: Text('Import Contacts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show the New Conversation modal as a full-screen
/// bottom sheet that slides up, matching rork's `animationType="slide"`.
Future<ChatConversation?> showNewConversationModal(BuildContext context) {
  return showModalBottomSheet<ChatConversation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
    ),
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.95,
        child: NewConversationModal(),
      );
    },
  );
}
