import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../application/chat_provider.dart';
import '../domain/chat_models.dart';
import 'new_conversation_modal.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  int _selectedTab = 0; // 0 = Chats, 1 = Contacts
  final TextEditingController _convoSearchController = TextEditingController();
  final TextEditingController _contactSearchController = TextEditingController();

  String _convoSearchQuery = '';
  String _contactSearchQuery = '';
  String _selectedRole = 'all'; // 'all', 'teacher', 'student'
  String _selectedGrade = 'All';
  String _selectedSection = 'All';
  bool _showArchived = false;

  final List<String> _gradeOptions = ['All', 'Grade 10', 'Grade 11', 'Grade 12'];
  final List<String> _sectionOptions = ['All', 'Emerald', 'Ruby', 'Diamond', 'Gold'];

  @override
  void dispose() {
    _convoSearchController.dispose();
    _contactSearchController.dispose();
    super.dispose();
  }

  void _openNewConversationModal(BuildContext context) async {
    final conv = await showModalBottomSheet<ChatConversation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewConversationModal(),
    );

    if (conv != null && context.mounted) {
      context.push('/chat/${conv.id}');
    }
  }

  Future<void> _startDirectChat(ChatUser user) async {
    final conv = await ref.read(chatProvider.notifier).getOrCreateConversation(user.id);
    if (conv != null && mounted) {
      context.push('/chat/${conv.id}');
    }
  }

  List<ChatUser> _getFilteredContacts(List<ChatUser> allUsers) {
    var list = allUsers;

    // Filter by role
    if (_selectedRole == 'teacher') {
      list = list.where((u) => u.role == 'admin' || u.role == 'super_admin').toList();
    } else if (_selectedRole == 'student') {
      list = list.where((u) => u.role == 'student').toList();
    }

    // Filter by grade
    if (_selectedGrade != 'All') {
      list = list.where((u) => u.grade == _selectedGrade).toList();
    }

    // Filter by section
    if (_selectedSection != 'All') {
      list = list.where((u) => u.section == _selectedSection).toList();
    }

    // Filter by search query
    if (_contactSearchQuery.trim().isNotEmpty) {
      final q = _contactSearchQuery.toLowerCase().trim();
      list = list.where((u) {
        final nameMatch = u.fullName.toLowerCase().contains(q);
        final emailMatch = u.email.toLowerCase().contains(q);
        final sectionMatch = u.section != null && u.section!.toLowerCase().contains(q);
        final gradeMatch = u.grade != null && u.grade!.toLowerCase().contains(q);
        final roleLabel = (u.role == 'admin' || u.role == 'super_admin') ? 'teacher' : 'student';
        final roleMatch = roleLabel.contains(q);
        return nameMatch || emailMatch || sectionMatch || gradeMatch || roleMatch;
      }).toList();
    }

    return list;
  }

  List<ChatConversation> _getFilteredConversations(List<ChatConversation> conversations) {
    var list = conversations.where((c) => c.isArchived == _showArchived).toList();
    if (_convoSearchQuery.trim().isEmpty) return list;
    final q = _convoSearchQuery.toLowerCase().trim();
    return list.where((c) {
      final nameMatch = (c.name ?? '').toLowerCase().contains(q);
      final lastMsgMatch = (c.lastMessage?.text ?? '').toLowerCase().contains(q);
      return nameMatch || lastMsgMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final chatState = ref.watch(chatProvider);

    final filteredConversations = _getFilteredConversations(chatState.conversations);
    final filteredContacts = _getFilteredContacts(chatState.availableUsers);

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNewConversationModal(context),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.edit, color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with connection status
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Messages & Contacts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: chatState.isConnected ? AppTheme.success : AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        chatState.isConnected ? 'Connected' : 'Offline',
                        style: TextStyle(
                          color: chatState.isConnected ? AppTheme.success : AppTheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab Switcher: Chats | Contacts
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const Key('tab_chats'),
                      onTap: () => setState(() => _selectedTab = 0),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 16,
                              color: _selectedTab == 0 ? Colors.black : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Chats (${chatState.conversations.where((c) => !c.isArchived).length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTab == 0 ? Colors.black : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      key: const Key('tab_contacts'),
                      onTap: () => setState(() => _selectedTab = 1),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.contacts_outlined,
                              size: 16,
                              color: _selectedTab == 1 ? Colors.black : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Contacts (${chatState.availableUsers.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTab == 1 ? Colors.black : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: _selectedTab == 0
                  ? _buildChatsView(filteredConversations)
                  : _buildContactsView(filteredContacts),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chats View ─────────────────────────────────────────────

  Widget _buildChatsView(List<ChatConversation> conversations) {
    final chatState = ref.watch(chatProvider);
    final archivedCount = chatState.conversations.where((c) => c.isArchived).length;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _convoSearchController,
            style: TextStyle(color: AppTheme.text),
            onChanged: (val) => setState(() => _convoSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search conversations...',
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              suffixIcon: _convoSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: AppTheme.textMuted, size: 18),
                      onPressed: () {
                        _convoSearchController.clear();
                        setState(() => _convoSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Active / Archived Toggle Pill (if any archived or viewing archived)
        if (archivedCount > 0 || _showArchived) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showArchived = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: !_showArchived ? AppTheme.primary : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: !_showArchived ? AppTheme.primary : AppTheme.border),
                    ),
                    child: Text(
                      'Active Chats',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: !_showArchived ? Colors.black : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _showArchived = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _showArchived ? Colors.amber.shade700 : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _showArchived ? Colors.amber.shade700 : AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.archive_outlined,
                          size: 14,
                          color: _showArchived ? Colors.white : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Archived ($archivedCount)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _showArchived ? Colors.white : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Gesture guide header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showArchived ? 'Showing archived conversations' : 'Slide right to edit · Slide left to archive',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              if (!_showArchived && archivedCount > 0)
                GestureDetector(
                  onTap: () => setState(() => _showArchived = true),
                  child: Text(
                    'View Archived ($archivedCount)',
                    style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        Expanded(
          child: conversations.isEmpty
              ? _buildEmptyState(context)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: conversations.length,
                  separatorBuilder: (_, _) => Divider(color: AppTheme.border, height: 1),
                  itemBuilder: (context, index) {
                    final convo = conversations[index];
                    final isGroup = convo.type == 'group';

                    return Dismissible(
                      key: Key('convo_${convo.id}'),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Edit Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                      secondaryBackground: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: convo.isArchived ? Colors.teal.shade600 : Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              convo.isArchived ? 'Unarchive' : 'Archive / Delete',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Icon(convo.isArchived ? Icons.unarchive : Icons.archive, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          _showEditChatDialog(convo);
                          return false;
                        } else {
                          _showChatOptionsSheet(convo);
                          return false;
                        }
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              backgroundColor: isGroup
                                  ? AppTheme.accent
                                  : Theme.of(context).colorScheme.primary,
                              child: Icon(
                                isGroup ? Icons.groups : Icons.person,
                                color: Colors.black,
                                size: 22,
                              ),
                            ),
                            if (isGroup)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.school, size: 10, color: Colors.black),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                convo.name ?? 'Chat',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isGroup)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySoft,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'Group',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          convo.lastMessage?.text ?? 'No messages yet',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: convo.unreadCount > 0
                            ? CircleAvatar(
                                radius: 12,
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: Text(
                                  convo.unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
                        onTap: () {
                          context.push('/chat/${convo.id}');
                        },
                        onLongPress: () {
                          _showChatOptionsSheet(convo);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Contacts View ──────────────────────────────────────────

  Widget _buildContactsView(List<ChatUser> contacts) {
    return Column(
      children: [
        // Contact Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _contactSearchController,
            style: TextStyle(color: AppTheme.text),
            onChanged: (val) => setState(() => _contactSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search by name, email, grade, section...',
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              suffixIcon: _contactSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: AppTheme.textMuted, size: 18),
                      onPressed: () {
                        _contactSearchController.clear();
                        setState(() => _contactSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Role Filter Pills: All | Teachers | Students
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildRoleChip('all', 'All Contacts'),
              const SizedBox(width: 8),
              _buildRoleChip('teacher', 'Teachers'),
              const SizedBox(width: 8),
              _buildRoleChip('student', 'Students'),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Grade and Section Filters (visible when Students or All selected)
        if (_selectedRole != 'teacher')
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Grade Dropdown Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedGrade != 'All' ? AppTheme.primary : AppTheme.border,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGrade,
                      isDense: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      icon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 18),
                      style: TextStyle(
                        fontSize: 12,
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

                // Section Dropdown Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedSection != 'All' ? AppTheme.primary : AppTheme.border,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSection,
                      isDense: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      icon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 18),
                      style: TextStyle(
                        fontSize: 12,
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
                if (_selectedGrade != 'All' || _selectedSection != 'All' || _selectedRole != 'all') ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRole = 'all';
                        _selectedGrade = 'All';
                        _selectedSection = 'All';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text('Reset', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 10),

        // Contacts list count header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Showing ${contacts.length} contacts',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (contacts.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Tap contact to view profile',
                    style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Contacts List
        Expanded(
          child: contacts.isEmpty
              ? _buildEmptyContactsState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) => Divider(color: AppTheme.border, height: 1),
                  itemBuilder: (context, index) {
                    final user = contacts[index];
                    final isTeacher = user.role == 'admin' || user.role == 'super_admin';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: GestureDetector(
                        onTap: () => _showUserProfileModal(user),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: isTeacher
                              ? AppTheme.primary
                              : AppTheme.accent,
                          child: Text(
                            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.fullName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isTeacher
                                  ? AppTheme.primarySoft
                                  : AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isTeacher
                                    ? AppTheme.primary.withValues(alpha: 0.4)
                                    : AppTheme.accent.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              isTeacher ? (user.role == 'super_admin' ? 'Admin' : 'Teacher') : 'Student',
                              style: TextStyle(
                                color: isTeacher ? AppTheme.primary : AppTheme.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          user.email,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.info_outline, size: 20, color: AppTheme.textSecondary),
                            onPressed: () => _showUserProfileModal(user),
                            tooltip: 'View Profile',
                          ),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.chat_bubble_outline, size: 18, color: AppTheme.primary),
                            ),
                            onPressed: () => _startDirectChat(user),
                            tooltip: 'Message ${user.fullName}',
                          ),
                        ],
                      ),
                      onTap: () => _showUserProfileModal(user),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRoleChip(String roleKey, String label) {
    final isSelected = _selectedRole == roleKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = roleKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyContactsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 56,
              color: AppTheme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No contacts found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing your search keywords, role, grade, or section filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _contactSearchController.clear();
                  _contactSearchQuery = '';
                  _selectedRole = 'all';
                  _selectedGrade = 'All';
                  _selectedSection = 'All';
                });
              },
              child: const Text('Reset All Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showArchived ? Icons.archive_outlined : Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _showArchived ? 'No archived chats' : 'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showArchived
                ? 'Slide a chat left or long-press to archive it'
                : 'Select a contact from the Contacts tab to start a chat',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          if (!_showArchived)
            ElevatedButton.icon(
              onPressed: () => setState(() => _selectedTab = 1),
              icon: const Icon(Icons.contacts_outlined, color: Colors.black),
              label: const Text('View Contacts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            )
          else
            OutlinedButton(
              onPressed: () => setState(() => _showArchived = false),
              child: const Text('Back to Active Chats'),
            ),
        ],
      ),
    );
  }

  // ── Profile & Chat Actions Modals ──────────────────────────

  void _showUserProfileModal(ChatUser user) {
    final isTeacher = user.role == 'admin' || user.role == 'super_admin';
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Large Avatar
              CircleAvatar(
                radius: 40,
                backgroundColor: isTeacher ? AppTheme.primary : AppTheme.accent,
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.fullName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              // Role Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isTeacher
                      ? AppTheme.primarySoft
                      : AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isTeacher
                        ? AppTheme.primary.withValues(alpha: 0.4)
                        : AppTheme.accent.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  isTeacher ? (user.role == 'super_admin' ? 'Super Admin' : 'Teacher') : 'Student',
                  style: TextStyle(
                    color: isTeacher ? AppTheme.primary : AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Profile Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    _buildProfileInfoRow(Icons.mail_outline, 'Email', user.email),
                    if (user.grade != null && user.grade!.isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildProfileInfoRow(Icons.school_outlined, 'Grade Level', user.grade!),
                    ],
                    if (user.section != null && user.section!.isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildProfileInfoRow(Icons.meeting_room_outlined, 'Section', user.section!),
                    ],
                    const Divider(height: 16),
                    _buildProfileInfoRow(Icons.badge_outlined, 'Account Role', isTeacher ? 'Faculty / Admin' : 'Learner'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startDirectChat(user);
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.black),
                      label: Text('Message ${user.fullName.split(' ').first}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  void _showChatOptionsSheet(ChatConversation convo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isArchived = convo.isArchived;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: convo.type == 'group' ? AppTheme.accent : Theme.of(context).colorScheme.primary,
                        child: Icon(convo.type == 'group' ? Icons.groups : Icons.person, color: Colors.black, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              convo.name ?? 'Chat',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              convo.type == 'group' ? 'Group Chat' : 'Direct Message',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),

                // Option 1: Edit Name
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                  ),
                  title: const Text('Edit Name', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Rename this conversation', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditChatDialog(convo);
                  },
                ),

                // Option 2: Archive / Unarchive
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                      color: Colors.amber.shade800,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    isArchived ? 'Unarchive Chat' : 'Archive Chat',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isArchived ? 'Move back to active chats' : 'Hide from active chat list',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(chatProvider.notifier).archiveConversation(convo.id, archive: !isArchived);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isArchived ? 'Chat unarchived' : 'Chat moved to archive'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () {
                              ref.read(chatProvider.notifier).archiveConversation(convo.id, archive: isArchived);
                            },
                          ),
                        ),
                      );
                    }
                  },
                ),

                // Option 3: Delete
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                  ),
                  title: Text('Delete Chat', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Delete conversation and message history', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteChatConfirm(convo);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditChatDialog(ChatConversation convo) {
    final controller = TextEditingController(text: convo.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Chat Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Chat Name',
            hintText: 'Enter new name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await ref.read(chatProvider.notifier).editConversationName(convo.id, newName);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteChatConfirm(ChatConversation convo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Conversation?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${convo.name ?? 'this chat'}"? All message history will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              await ref.read(chatProvider.notifier).deleteConversation(convo.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conversation deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
