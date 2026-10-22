import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

import '../application/chat_provider.dart';
import '../domain/chat_models.dart';

/// Helper to get a human-readable role label.
String _getRoleLabel(String role) {
  if (role == 'super_admin') return 'Super Admin';
  if (role == 'admin') return 'Administrator';
  if (role == 'teacher') return 'Teacher';
  return 'Student';
}

/// Modern modal sheet for starting a new conversation.
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
      if (_tabController.indexIsChanging) return;
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
      list = list.where((u) => u.role == 'teacher' || u.role == 'admin' || u.role == 'super_admin').toList();
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
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.90,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Scaffold(
          backgroundColor: AppTheme.background,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            top: true,
            bottom: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Drag Handle Pill ──
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Executive Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Conversation',
                              style: TextStyle(
                                color: AppTheme.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Select a contact or classmate to chat',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Tactile, reachable circular close button with min 44x44 touch target
                      Material(
                        color: AppTheme.surfaceLight,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: const Key('modal_close_button'),
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.border.withValues(alpha: 0.8),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.close_rounded,
                              color: AppTheme.text,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Apple/Linear Segmented Pill Tabs ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSegmentedTab(
                            title: 'App Users',
                            count: allUsers.length,
                            isActive: _activeTab == 'users',
                            onTap: () {
                              _tabController.animateTo(0);
                              setState(() => _activeTab = 'users');
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildSegmentedTab(
                            title: 'Device Contacts',
                            isActive: _activeTab == 'contacts',
                            onTap: () {
                              _tabController.animateTo(1);
                              setState(() => _activeTab = 'contacts');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Search Input ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.border.withValues(alpha: 0.7),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            maxLength: 60,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            style: TextStyle(color: AppTheme.text, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: _activeTab == 'users'
                                  ? 'Search name, email, grade, or section...'
                                  : 'Search device contacts...',
                              hintStyle: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 11),
                              isDense: true,
                            ),
                            onChanged: (value) => setState(() => _searchQuery = value),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear_rounded, color: AppTheme.textMuted, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

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
        ),
      ),
    );
  }

  Widget _buildSegmentedTab({
    required String title,
    int? count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? AppTheme.primary : AppTheme.textMuted,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : AppTheme.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isActive ? AppTheme.primary : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab(List<ChatUser> users) {
    return Column(
      children: [
        // ── Consolidated Horizontal Filter Strip ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildRoleChip('all', 'All'),
              const SizedBox(width: 6),
              _buildRoleChip('teacher', 'Teachers'),
              const SizedBox(width: 6),
              _buildRoleChip('student', 'Students'),
              if (_selectedRole != 'teacher') ...[
                const SizedBox(width: 6),
                Container(
                  height: 16,
                  width: 1,
                  color: AppTheme.border,
                ),
                const SizedBox(width: 6),
                _buildDropdownChip(
                  label: _selectedGrade == 'All' ? 'Grade: All' : _selectedGrade,
                  isActive: _selectedGrade != 'All',
                  value: _selectedGrade,
                  items: _gradeOptions,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedGrade = val);
                  },
                ),
                const SizedBox(width: 6),
                _buildDropdownChip(
                  label: _selectedSection == 'All' ? 'Section: All' : 'Sec. $_selectedSection',
                  isActive: _selectedSection != 'All',
                  value: _selectedSection,
                  items: _sectionOptions,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSection = val);
                  },
                ),
              ],
              if (_selectedGrade != 'All' || _selectedSection != 'All' || _selectedRole != 'all') ...[
                const SizedBox(width: 6),
                _buildResetChip(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Users List or Empty ──
        Expanded(
          child: users.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.people_outline_rounded,
                            size: 32,
                            color: AppTheme.textMuted.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No contacts match',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 6),
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
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => Divider(
                    color: AppTheme.border.withValues(alpha: 0.5),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isCreating = _creatingChatUserId == user.id;
                    final isTeacher = user.role == 'teacher' || user.role == 'admin' || user.role == 'super_admin';

                    final List<String> details = [];
                    if (user.grade != null && user.grade!.isNotEmpty) details.add(user.grade!);
                    if (user.section != null && user.section!.isNotEmpty) details.add('Sec. ${user.section!}');
                    details.add(user.email);
                    final subtitleText = details.join(' • ');

                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: isCreating ? null : () => _handleStartChat(user),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        child: Row(
                          children: [
                            _buildAvatar(user.fullName, role: user.role, size: 42),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
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
                                      const SizedBox(width: 8),
                                      // Role Tag
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isTeacher
                                              ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                                              : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isTeacher
                                                ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
                                                : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          _getRoleLabel(user.role),
                                          style: TextStyle(
                                            color: isTeacher
                                                ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))
                                                : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF64748B) : const Color(0xFF64748B)),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    subtitleText,
                                    style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 12.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
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
                                Icons.chevron_right_rounded,
                                color: AppTheme.textMuted.withValues(alpha: 0.6),
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

  Widget _buildRoleChip(String roleKey, String label) {
    final isSelected = _selectedRole == roleKey;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = roleKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF334155) : const Color(0xFF1E293B))
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF475569) : const Color(0xFF1E293B))
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownChip({
    required String label,
    required bool isActive,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: Theme.of(context).colorScheme.surface,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            size: 16,
          ),
          style: TextStyle(
            fontSize: 12,
            color: isActive
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
          items: items.map((item) {
            String display = item;
            if (item == 'All') {
              display = label.startsWith('Grade') ? 'Grade: All' : 'Section: All';
            }
            return DropdownMenuItem(
              value: item,
              child: Text(display),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildResetChip() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
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
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh_rounded,
              size: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Text(
              'Reset',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, {required String role, double size = 42}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isTeacher = role == 'teacher' || role == 'admin' || role == 'super_admin';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor;
    final Color textColor;
    final Color borderColor;

    if (isTeacher) {
      bgColor = isDark ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B);
      textColor = Colors.white;
      borderColor = isDark ? const Color(0xFF3B82F6) : const Color(0xFF334155);
    } else {
      bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      textColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
      borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(
          color: borderColor.withValues(alpha: 0.8),
          width: 1.0,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }

  Widget _buildContactsTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.contacts_outlined,
                size: 32,
                color: AppTheme.textMuted.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No matched device contacts',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Device contacts with registered AIRA accounts will appear here automatically.',
              style: TextStyle(
                fontSize: 13,
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
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const NewConversationModal(),
  );
}
