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
  if (role == 'admin') return 'Teacher';
  return 'Student';
}

/// Full-screen modal for starting a new conversation.
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

  String _selectedRole = 'all'; // 'all', 'teacher', 'student'
  String _selectedGrade = 'All';
  String _selectedSection = 'All';

  final List<String> _gradeOptions = ['All', 'Grade 10', 'Grade 11', 'Grade 12'];
  final List<String> _sectionOptions = ['All', 'Emerald', 'Ruby', 'Diamond', 'Gold'];

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

  /// Filter users locally by name, email, role, grade, or section.
  List<ChatUser> _filterUsers(List<ChatUser> users, String query) {
    var list = users;

    if (_selectedRole == 'teacher') {
      list = list.where((u) => u.role == 'admin' || u.role == 'super_admin').toList();
    } else if (_selectedRole == 'student') {
      list = list.where((u) => u.role == 'student').toList();
    }

    if (_selectedGrade != 'All') {
      list = list.where((u) => u.grade == _selectedGrade).toList();
    }

    if (_selectedSection != 'All') {
      list = list.where((u) => u.section == _selectedSection).toList();
    }

    if (query.trim().isNotEmpty) {
      final lower = query.toLowerCase().trim();
      list = list.where((u) {
        return u.fullName.toLowerCase().contains(lower) ||
            u.email.toLowerCase().contains(lower) ||
            (u.section != null && u.section!.toLowerCase().contains(lower)) ||
            (u.grade != null && u.grade!.toLowerCase().contains(lower)) ||
            _getRoleLabel(u.role).toLowerCase().contains(lower);
      }).toList();
    }

    return list;
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'App Users / Contacts'),
                  Tab(text: 'Device Contacts'),
                ],
              ),
            ),

            // ── Search Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: AppTheme.textMuted, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: false,
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: _activeTab == 'users'
                            ? 'Search by name, email, grade, section...'
                            : 'Search contacts...',
                        hintStyle: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
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
    return Column(
      children: [
        // Role and attribute filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // Role Filter Chips
              Row(
                children: [
                  _buildModalRoleChip('all', 'All'),
                  const SizedBox(width: 6),
                  _buildModalRoleChip('teacher', 'Teachers'),
                  const SizedBox(width: 6),
                  _buildModalRoleChip('student', 'Students'),
                ],
              ),
              if (_selectedRole != 'teacher') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Grade Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _selectedGrade != 'All' ? AppTheme.primary : AppTheme.border,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedGrade,
                          isDense: true,
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          icon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 16),
                          style: TextStyle(
                            fontSize: 11,
                            color: _selectedGrade != 'All' ? AppTheme.primary : AppTheme.text,
                            fontWeight: _selectedGrade != 'All' ? FontWeight.bold : FontWeight.normal,
                          ),
                          items: _gradeOptions.map((grade) {
                            return DropdownMenuItem(
                              value: grade,
                              child: Text(grade == 'All' ? 'Grade: All' : grade),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedGrade = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Section Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _selectedSection != 'All' ? AppTheme.primary : AppTheme.border,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSection,
                          isDense: true,
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          icon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 16),
                          style: TextStyle(
                            fontSize: 11,
                            color: _selectedSection != 'All' ? AppTheme.primary : AppTheme.text,
                            fontWeight: _selectedSection != 'All' ? FontWeight.bold : FontWeight.normal,
                          ),
                          items: _sectionOptions.map((sec) {
                            return DropdownMenuItem(
                              value: sec,
                              child: Text(sec == 'All' ? 'Section: All' : 'Sec. $sec'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSection = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // List or Empty
        Expanded(
          child: users.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: AppTheme.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No contacts match',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search query or filters.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isCreating = _creatingChatUserId == user.id;
                    final isTeacher = user.role == 'admin' || user.role == 'super_admin';

                    return InkWell(
                      onTap: isCreating ? null : () => _handleStartChat(user),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppTheme.border, width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isTeacher ? AppTheme.primary : AppTheme.accent,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _getAvatarText(user.fullName),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Name + Role Badge + Section & Grade + Email
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          user.fullName,
                                          style: TextStyle(
                                            color: AppTheme.text,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isTeacher
                                              ? AppTheme.primarySoft
                                              : AppTheme.accent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isTeacher
                                                ? AppTheme.primary.withValues(alpha: 0.4)
                                                : AppTheme.accent.withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Text(
                                          _getRoleLabel(user.role),
                                          style: TextStyle(
                                            color: isTeacher ? AppTheme.primary : AppTheme.accent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.email,
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
                ),
        ),
      ],
    );
  }

  Widget _buildModalRoleChip(String roleKey, String label) {
    final isSelected = _selectedRole == roleKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = roleKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildContactsTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contacts_outlined,
              size: 48,
              color: AppTheme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No matched device contacts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Device contacts with AIRA accounts will appear here.',
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
}

/// Helper function to show the New Conversation modal.
Future<ChatConversation?> showNewConversationModal(BuildContext context) {
  return showModalBottomSheet<ChatConversation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
    ),
    builder: (context) {
      return const FractionallySizedBox(
        heightFactor: 0.95,
        child: NewConversationModal(),
      );
    },
  );
}
