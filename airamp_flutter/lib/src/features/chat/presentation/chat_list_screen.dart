import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../application/chat_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: AppTheme.primary),
            onPressed: () {},
          )
        ],
      ),
      body: chatState.conversations.isEmpty
          ? const Center(
              child: Text('No messages yet', style: TextStyle(color: AppTheme.textMuted)),
            )
          : ListView.separated(
              itemCount: chatState.conversations.length,
              separatorBuilder: (context, index) => const Divider(color: AppTheme.border, height: 1),
              itemBuilder: (context, index) {
                final convo = chatState.conversations[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      convo.name != null && convo.name!.isNotEmpty ? convo.name![0] : '?',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    convo.name ?? 'Unknown',
                    style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    convo.lastMessage?.text ?? 'No messages',
                    style: const TextStyle(color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: convo.unreadCount > 0
                      ? CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.primary,
                          child: Text(
                            convo.unreadCount.toString(),
                            style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        )
                      : null,
                  onTap: () {
                    context.push('/chat/${convo.id}');
                  },
                );
              },
            ),
    );
  }
}
