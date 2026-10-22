import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/session_draft_service.dart';
import '../application/chat_provider.dart';
import '../domain/chat_models.dart';
import '../../auth/application/auth_provider.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatRoomScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  final SessionDraftDisposer _draftDisposer = SessionDraftDisposer();

  String get _formId => 'chat_draft_${widget.conversationId}';

  @override
  void initState() {
    super.initState();
    _draftDisposer.add(_controller.bindSessionDraft(
      formId: _formId,
      fieldKey: 'msg',
      onDraftRestored: () => setState(() {}),
    ));
    // Ensure latest messages are loaded from DB and marked as read
    Future.microtask(() async {
      await ref.read(chatProvider.notifier).reloadMessages(widget.conversationId);
      await ref.read(chatProvider.notifier).markConversationAsRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _draftDisposer.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      ref.read(chatProvider.notifier).sendMessage(widget.conversationId, text);
      SessionDraftService.instance.clearForm(_formId);
      _controller.clear();
    }
  }

  String _formatTime(String isoString) {
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '';
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final user = ref.watch(authProvider);
    final messages = chatState.messages[widget.conversationId] ?? [];
    
    // Find conversation
    final convo = chatState.conversations.cast<ChatConversation?>().firstWhere(
      (c) => c?.id == widget.conversationId,
      orElse: () => null,
    );

    String displayName = convo?.name ?? 'Chat';
    String? subtitle;
    if (convo != null && convo.type == 'direct') {
      ChatUser? otherUser;
      if (convo.participants.isNotEmpty) {
        final filtered = convo.participants.where((p) => p.id != user?.id);
        otherUser = filtered.isNotEmpty ? filtered.first : convo.participants.first;
      }
      if (otherUser == null && convo.id.startsWith('dm_')) {
        final matches = chatState.availableUsers.where((u) => u.id != user?.id && convo.id.contains(u.id));
        if (matches.isNotEmpty) {
          otherUser = matches.first;
        }
      }
      if (otherUser != null) {
        displayName = otherUser.fullName;
        if (otherUser.role == 'student') {
          final parts = [
            'Student',
            if (otherUser.grade != null && otherUser.grade!.isNotEmpty) otherUser.grade!,
            if (otherUser.section != null && otherUser.section!.isNotEmpty) 'Sec. ${otherUser.section!}',
          ];
          subtitle = parts.join(' · ');
        } else {
          subtitle = otherUser.role == 'super_admin' ? 'Super Admin' : 'Teacher';
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayName,
              style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        iconTheme: IconThemeData(color: AppTheme.text),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // Show latest messages at bottom
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                // Since it's reversed, index 0 is the last item in the array
                final msg = messages[messages.length - 1 - index];
                final isMe = msg.senderId == user?.id;
                final timeStr = _formatTime(msg.createdAt);

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: () => _showMessageOptions(msg, isMe),
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isMe
                            ? LinearGradient(
                                colors: [AppTheme.primary, AppTheme.primaryDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: !isMe ? Theme.of(context).colorScheme.surface : null,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(3),
                          bottomRight: isMe ? const Radius.circular(3) : const Radius.circular(16),
                        ),
                        border: !isMe ? Border.all(color: AppTheme.border.withValues(alpha: 0.7)) : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.text,
                            style: TextStyle(
                              color: isMe ? Colors.white : AppTheme.text,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                          if (timeStr.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: isMe ? Colors.white.withValues(alpha: 0.7) : AppTheme.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 3),
                                  Icon(
                                    msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12).copyWith(bottom: MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.6))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 1000,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    style: TextStyle(color: AppTheme.text),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      counterText: '',
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppTheme.primary, width: 1.2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _sendMessage,
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(ChatMessage msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy Message'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                },
              ),
              if (isMe) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                  title: const Text('Edit Message'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditMessageDialog(msg);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteMessageConfirm(msg);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMessageDialog(ChatMessage msg) {
    final controller = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          maxLength: 1000,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(hintText: 'Edit your message'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isNotEmpty) {
                await ref.read(chatProvider.notifier).editMessage(widget.conversationId, msg.id, newText);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMessageConfirm(ChatMessage msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              await ref.read(chatProvider.notifier).deleteMessage(widget.conversationId, msg.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
