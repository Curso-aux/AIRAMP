import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';
import '../../auth/application/auth_provider.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

class ChatState {
  final bool isConnected;
  final List<ChatConversation> conversations;
  final Map<String, List<ChatMessage>> messages; // conversationId -> messages

  ChatState({
    this.isConnected = false,
    this.conversations = const [],
    this.messages = const {},
  });

  ChatState copyWith({
    bool? isConnected,
    List<ChatConversation>? conversations,
    Map<String, List<ChatMessage>>? messages,
  }) {
    return ChatState(
      isConnected: isConnected ?? this.isConnected,
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  StreamSubscription? _subscription;

  @override
  ChatState build() {
    // Listen to auth changes AFTER build returns.
    // Use ref.listen instead of ref.watch to avoid circular state access.
    ref.listen<User?>(authProvider, (prev, next) {
      if (next != null && prev == null) {
        _connectAndLoad(next.id);
      } else if (next == null && prev != null) {
        _disconnect();
      }
    });

    // Check current auth state for initial load (scheduled after build)
    final user = ref.read(authProvider);
    if (user != null) {
      // Schedule after build completes to avoid "read state during build" error
      Future.microtask(() => _connectAndLoad(user.id));
    }

    return ChatState();
  }

  void _connectAndLoad(String userId) {
    // For now, skip the real WebSocket (no backend running) and just load mock data
    state = state.copyWith(isConnected: false);
    // _loadMockData(); // Uncomment to pre-populate with mock conversations
  }

  void _disconnect() {
    _subscription?.cancel();
    ref.read(chatRepositoryProvider).disconnect();
    state = ChatState();
  }

  void _handleWebSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type == 'message') {
      final msg = ChatMessage.fromJson(event['message']);
      final messagesMap = Map<String, List<ChatMessage>>.from(state.messages);
      final list = messagesMap[msg.conversationId] ?? [];
      messagesMap[msg.conversationId] = [...list, msg];
      
      state = state.copyWith(messages: messagesMap);
    }
  }

  void sendMessage(String conversationId, String text) {
    final user = ref.read(authProvider);
    if (user == null) return;
    
    // Optimistic update
    final newMsg = ChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: user.id,
      text: text,
      createdAt: DateTime.now().toIso8601String(),
    );
    
    final messagesMap = Map<String, List<ChatMessage>>.from(state.messages);
    final list = messagesMap[conversationId] ?? [];
    messagesMap[conversationId] = [...list, newMsg];
    
    state = state.copyWith(messages: messagesMap);
    
    // Send over socket
    ref.read(chatRepositoryProvider).sendMessage(conversationId, text);
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(() {
  return ChatNotifier();
});
