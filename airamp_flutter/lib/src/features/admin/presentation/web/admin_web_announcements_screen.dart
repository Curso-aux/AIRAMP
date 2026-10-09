import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/services/session_draft_service.dart';
import '../../../auth/application/auth_provider.dart';
import '../../data/admin_repository.dart';

class AdminWebAnnouncementsScreen extends ConsumerStatefulWidget {
  const AdminWebAnnouncementsScreen({super.key});

  @override
  ConsumerState<AdminWebAnnouncementsScreen> createState() => _AdminWebAnnouncementsScreenState();
}

class _AdminWebAnnouncementsScreenState extends ConsumerState<AdminWebAnnouncementsScreen> {
  int _selectedTab = 0; // 0: Announcements, 1: Inquiries & Replies
  String _inquiryFilter = 'all'; // 'all', 'pending', 'replied'
  final TextEditingController _inquirySearchController = TextEditingController();
  String _inquirySearchQuery = '';

  @override
  void initState() {
    super.initState();
    _inquirySearchController.addListener(() {
      setState(() {
        _inquirySearchQuery = _inquirySearchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _inquirySearchController.dispose();
    super.dispose();
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final announcements = ref.watch(announcementsProvider);
    final inquiries = ref.watch(inquiriesProvider);
    final pendingCount = ref.watch(pendingInquiriesCountProvider).value ?? 0;
    final currentUser = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header & Tab Navigation ────────────────────────
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final isNarrow = headerConstraints.maxWidth < 650;

                final titleSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Announcements & Inquiries Hub',
                      style: TextStyle(
                        fontSize: isNarrow ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Broadcast school announcements and send direct replies to student & faculty inquiries',
                      style: TextStyle(fontSize: isNarrow ? 12.5 : 14, color: AppTheme.textSecondary),
                    ),
                  ],
                );

                final actionBtn = _selectedTab == 0
                    ? ElevatedButton.icon(
                        onPressed: () => _showAnnouncementDialog(),
                        icon: const Icon(Icons.campaign_rounded, size: 18),
                        label: const Text('Post Announcement'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          minimumSize: const Size(0, 40),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => ref.read(inquiriesProvider.notifier).loadInquiries(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Refresh Inquiries'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          minimumSize: const Size(0, 40),
                        ),
                      );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleSection,
                      const SizedBox(height: 14),
                      actionBtn,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleSection),
                    const SizedBox(width: 16),
                    actionBtn,
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Segmented Tab Selector ──────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabButton(
                    index: 0,
                    title: 'School Announcements',
                    icon: Icons.campaign_outlined,
                    count: announcements.length,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 4),
                  _buildTabButton(
                    index: 1,
                    title: 'Inquiries & Replies Hub',
                    icon: Icons.question_answer_outlined,
                    count: inquiries.length,
                    badgeCount: pendingCount,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Main Content according to active tab ───────────────
            if (_selectedTab == 0)
              _buildAnnouncementsView(announcements)
            else
              _buildInquiriesView(inquiries, currentUser, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String title,
    required IconData icon,
    required int count,
    int? badgeCount,
    required bool isDark,
  }) {
    final isSelected = _selectedTab == index;

    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.primary : AppTheme.primary)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.black : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.black : AppTheme.text,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.black.withValues(alpha: 0.15)
                    : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : AppTheme.textSecondary,
                ),
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : AppTheme.warning,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount pending',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? AppTheme.primary : Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ── INQUIRIES & REPLIES VIEW ──────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════
  Widget _buildInquiriesView(
    List<Map<String, dynamic>> inquiries,
    dynamic currentUser,
    bool isDark,
  ) {
    // Filter inquiries
    final filtered = inquiries.where((inq) {
      final status = (inq['status'] as String? ?? 'pending').toLowerCase();
      if (_inquiryFilter == 'pending' && status != 'pending') return false;
      if (_inquiryFilter == 'replied' && status != 'replied') return false;

      if (_inquirySearchQuery.isNotEmpty) {
        final id = (inq['user_id'] as String? ?? '').toLowerCase();
        final name = (inq['user_name'] as String? ?? '').toLowerCase();
        final email = (inq['user_email'] as String? ?? '').toLowerCase();
        final question = (inq['question'] as String? ?? '').toLowerCase();
        final ticket = (inq['id'] as String? ?? '').toLowerCase();
        return id.contains(_inquirySearchQuery) ||
            name.contains(_inquirySearchQuery) ||
            email.contains(_inquirySearchQuery) ||
            question.contains(_inquirySearchQuery) ||
            ticket.contains(_inquirySearchQuery);
      }
      return true;
    }).toList();

    final pendingTotal = inquiries.where((i) => i['status'] == 'pending').length;
    final repliedTotal = inquiries.where((i) => i['status'] == 'replied').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Controls: Search & Filter Chips ────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inquirySearchController,
                      style: TextStyle(fontSize: 13, color: AppTheme.text),
                      decoration: InputDecoration(
                        hintText: 'Search by Student/Teacher ID, name, email, or question...',
                        hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                        suffixIcon: _inquirySearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () => _inquirySearchController.clear(),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildFilterChip('all', 'All Inquiries (${inquiries.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', 'Pending ($pendingTotal)', isWarning: pendingTotal > 0),
                  const SizedBox(width: 8),
                  _buildFilterChip('replied', 'Replied ($repliedTotal)', isSuccess: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Inquiries List ─────────────────────────────────────────
        if (filtered.isEmpty)
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
                Icon(Icons.inbox_rounded, size: 54, color: AppTheme.textMuted),
                const SizedBox(height: 16),
                Text(
                  _inquirySearchQuery.isNotEmpty
                      ? 'No matching inquiries found'
                      : (_inquiryFilter == 'pending'
                          ? 'No pending inquiries!'
                          : 'No user inquiries submitted yet'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 6),
                Text(
                  'Questions asked by teachers or students via the School Management Assistant will appear here for administrative reply.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final inq = filtered[index];
              return _buildInquiryCard(inq, currentUser, isDark);
            },
          ),
      ],
    );
  }

  Widget _buildFilterChip(String filterKey, String label, {bool isWarning = false, bool isSuccess = false}) {
    final isSelected = _inquiryFilter == filterKey;
    Color activeColor = AppTheme.primary;
    if (isWarning) activeColor = AppTheme.warning;
    if (isSuccess) activeColor = AppTheme.success;

    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _inquiryFilter = filterKey),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        color: isSelected ? Colors.black : AppTheme.text,
      ),
      selectedColor: activeColor,
      backgroundColor: AppTheme.background,
      side: BorderSide(
        color: isSelected ? activeColor : AppTheme.border,
      ),
    );
  }

  Widget _buildInquiryCard(Map<String, dynamic> inq, dynamic currentUser, bool isDark) {
    final ticketId = inq['id'] as String? ?? '';
    final userId = inq['user_id'] as String? ?? '';
    final userName = inq['user_name'] as String? ?? 'User';
    final userEmail = inq['user_email'] as String? ?? '';
    final userRole = inq['user_role'] as String? ?? 'student';
    final question = inq['question'] as String? ?? '';
    final status = inq['status'] as String? ?? 'pending';
    final replyText = inq['reply'] as String?;
    final repliedAt = _formatDate(inq['replied_at'] as String?);
    final repliedBy = inq['replied_by'] as String?;
    final createdAt = _formatDate(inq['created_at'] as String?);

    final isPending = status == 'pending';
    final isTeacher = userRole.toLowerCase() == 'teacher';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? AppTheme.warning.withValues(alpha: 0.4)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Badges, ID, Role & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isTeacher ? AppTheme.accent : AppTheme.primary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isTeacher ? 'FACULTY' : 'STUDENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isTeacher ? AppTheme.accent : AppTheme.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      'ID: $userId',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  Text(
                    'Ticket #$ticketId',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPending ? AppTheme.warning : AppTheme.success)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPending ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                      size: 14,
                      color: isPending ? AppTheme.warning : AppTheme.success,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPending ? 'PENDING REPLY' : 'REPLIED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isPending ? AppTheme.warning : AppTheme.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: User details & email
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                userName,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mail_outline_rounded, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    userEmail,
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              Text(
                createdAt,
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Question Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.help_outline_rounded, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'INQUIRY QUESTION',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  question,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.text,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          // If already replied, show the reply card
          if (!isPending && replyText != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.quickreply_rounded, size: 16, color: AppTheme.success),
                      const SizedBox(width: 6),
                      Text(
                        'ADMINISTRATIVE RESPONSE (By ${repliedBy ?? 'Admin'} on $repliedAt)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    replyText,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.text,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 13, color: AppTheme.success),
                          const SizedBox(width: 4),
                          Text(
                            'Sent to Email ($userEmail)',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 13, color: AppTheme.success),
                          const SizedBox(width: 4),
                          Text(
                            'Posted to In-App System Notifications ($userId)',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Action Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _showReplyDialog(inq, currentUser),
              icon: Icon(
                isPending ? Icons.reply_rounded : Icons.edit_note_rounded,
                size: 16,
              ),
              label: Text(isPending ? 'Reply to User' : 'Update / Resend Reply'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPending ? AppTheme.primary : AppTheme.surface,
                foregroundColor: isPending ? Colors.black : AppTheme.text,
                side: isPending ? null : BorderSide(color: AppTheme.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── REPLY MODAL DIALOG ──────────────────────────────────────────
  void _showReplyDialog(Map<String, dynamic> inq, dynamic currentUser) {
    final ticketId = inq['id'] as String? ?? '';
    final userId = inq['user_id'] as String? ?? '';
    final userName = inq['user_name'] as String? ?? 'User';
    final userEmail = inq['user_email'] as String? ?? '';
    final userRole = inq['user_role'] as String? ?? 'student';
    final question = inq['question'] as String? ?? '';
    final existingReply = inq['reply'] as String? ?? '';

    final replyController = TextEditingController(text: existingReply);
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.reply_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reply to Inquiry ($ticketId)',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      Text(
                        'Recipient: $userName ($userId • ${userRole.toUpperCase()})',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Inquiry Question Summary Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QUESTION ASKED:',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            question,
                            style: TextStyle(fontSize: 13, color: AppTheme.text, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Destination Info
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.mark_email_read_rounded, size: 14, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Delivery 1: Official Email to $userEmail',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.text),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.notifications_active_rounded, size: 14, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Delivery 2: In-App System Notification for $userId ($userName)',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.text),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Administrative Response:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: replyController,
                      maxLines: 5,
                      style: TextStyle(fontSize: 13.5, color: AppTheme.text),
                      decoration: InputDecoration(
                        hintText: 'Type your official administrative reply to the student/faculty...',
                        hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSending ? null : () => Navigator.pop(dialogCtx),
                child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton.icon(
                onPressed: isSending
                    ? null
                    : () async {
                        final reply = replyController.text.trim();
                        if (reply.isEmpty) return;

                        setDialogState(() => isSending = true);

                        final adminName = currentUser?.name ?? currentUser?.username ?? 'School Administration';
                        final adminId = currentUser?.id ?? 'admin';

                        final messenger = ScaffoldMessenger.of(context);

                        await ref.read(inquiriesProvider.notifier).reply(
                          inquiryId: ticketId,
                          replyText: reply,
                          adminName: adminName,
                          adminId: adminId,
                        );

                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('✓ Reply sent to $userName via email ($userEmail) and in-app system notification!'),
                              backgroundColor: AppTheme.success,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                icon: isSending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.send_rounded, size: 16, color: Colors.black),
                label: Text(
                  isSending ? 'Sending...' : 'Send Reply to Email & System',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ── ANNOUNCEMENTS VIEW (PRESERVED) ────────────────────────────────
  // ══════════════════════════════════════════════════════════════════
  Widget _buildAnnouncementsView(List<Map<String, dynamic>> announcements) {
    if (announcements.isEmpty) {
      return Container(
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
      );
    }

    return ListView.separated(
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit Announcement',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: AppTheme.primary,
                        onPressed: () => _showAnnouncementDialog(existing: a),
                      ),
                      IconButton(
                        tooltip: 'Delete Announcement',
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: AppTheme.error,
                        onPressed: () => _confirmDelete(id, title),
                      ),
                    ],
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
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Posted: $date',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  if (a['author_name'] != null && (a['author_name'] as String).isNotEmpty)
                    Text(
                      'By: ${a['author_name']}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAnnouncementDialog({Map<String, dynamic>? existing}) {
    final isEditing = existing != null;
    final id = existing?['id'] as int? ?? 0;

    final formId = isEditing ? 'admin_edit_announcement_$id' : 'admin_new_announcement';
    final savedDraftTitle = SessionDraftService.instance.getField(formId, 'title');
    final savedDraftMessage = SessionDraftService.instance.getField(formId, 'message');
    final savedDraftPriority = SessionDraftService.instance.getField(formId, 'priority');
    final savedDraftAudience = SessionDraftService.instance.getField(formId, 'target_audience');

    final initialTitle = savedDraftTitle ?? existing?['title'] as String? ?? '';
    final initialMessage = savedDraftMessage ?? existing?['message'] as String? ?? '';
    final initialPriority = savedDraftPriority ?? existing?['priority'] as String? ?? 'normal';
    final initialAudience = savedDraftAudience ?? existing?['target_audience'] as String? ?? 'all';

    final titleController = TextEditingController(text: initialTitle);
    final messageController = TextEditingController(text: initialMessage);
    String selectedPriority = initialPriority;
    String selectedAudience = initialAudience;

    final unbindTitle = titleController.bindSessionDraft(formId: formId, fieldKey: 'title');
    final unbindMessage = messageController.bindSessionDraft(formId: formId, fieldKey: 'message');

    void cleanUp() {
      unbindTitle();
      unbindMessage();
      titleController.dispose();
      messageController.dispose();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_note : Icons.campaign,
                  color: AppTheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  isEditing ? 'Edit Announcement' : 'Post New Announcement',
                  style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Announcement Title',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      style: TextStyle(fontSize: 14, color: AppTheme.text),
                      decoration: InputDecoration(
                        hintText: 'e.g., Midterm Examination Schedule Released',
                        hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Content / Message',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      style: TextStyle(fontSize: 14, color: AppTheme.text),
                      decoration: InputDecoration(
                        hintText: 'Provide details, instructions, or deadlines...',
                        hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Priority',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: selectedPriority,
                                dropdownColor: AppTheme.surface,
                                style: TextStyle(fontSize: 13, color: AppTheme.text),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: AppTheme.border),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                                  DropdownMenuItem(value: 'high', child: Text('High / Urgent')),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setDialogState(() => selectedPriority = v);
                                    SessionDraftService.instance.saveField(formId, 'priority', v);
                                  }
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
                              Text(
                                'Target Audience',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: selectedAudience,
                                dropdownColor: AppTheme.surface,
                                style: TextStyle(fontSize: 13, color: AppTheme.text),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: AppTheme.border),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All Users')),
                                  DropdownMenuItem(value: 'students', child: Text('Students Only')),
                                  DropdownMenuItem(value: 'teachers', child: Text('Faculty / Teachers')),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setDialogState(() => selectedAudience = v);
                                    SessionDraftService.instance.saveField(formId, 'target_audience', v);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  cleanUp();
                },
                child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final message = messageController.text.trim();
                  if (title.isEmpty || message.isEmpty) return;

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogCtx);
                  cleanUp();
                  if (isEditing) {
                    await ref.read(announcementsProvider.notifier).updateAnnouncement(id, {
                      'title': title,
                      'message': message,
                      'priority': selectedPriority,
                      'target_audience': selectedAudience,
                    });
                  } else {
                    await ref.read(announcementsProvider.notifier).addAnnouncement({
                      'title': title,
                      'message': message,
                      'priority': selectedPriority,
                      'target_audience': selectedAudience,
                      'created_at': DateTime.now().toIso8601String(),
                    });
                    SessionDraftService.instance.clearForm(formId);
                  }
                  ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? 'Announcement updated successfully!' : 'Announcement posted successfully!'),
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
                child: Text(
                  isEditing ? 'Save Changes' : 'Publish Announcement',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
