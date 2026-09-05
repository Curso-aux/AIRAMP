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
    final user = ref.watch(authProvider);
    if (user != null) {
      // In a real app, we would use a real token
      _connect(user.id, 'mock_token');
    } else {
      _disconnect();
    }
    return ChatState();
  }

  void _connect(String userId, String token) {
    final repo = ref.read(chatRepositoryProvider);
    final stream = repo.connect(userId, token);
    
    state = state.copyWith(isConnected: true);
    
    _subscription = stream.listen(
      (data) {
        _handleWebSocketEvent(data);
      },
      onError: (e) {
        state = state.copyWith(isConnected: false);
      },
      onDone: () {
        state = state.copyWith(isConnected: false);
      },
    );
    
    // Mock initial data if stream is empty (for UI development)
    _loadMockData();
  }

  void _disconnect() {
    _subscription?.cancel();
    ref.read(chatRepositoryProvider).disconnect();
    state = ChatState();
  }
  
  void _loadMockData() {
    final mockConvo = ChatConversation(
      id: 'mock_convo_1',
      type: 'direct',
      name: 'Maria Lopez',
      participants: [
        ChatUser(id: 'student_1', fullName: 'Maria Lopez', email: 'maria@test.com', role: 'student')
      ],
      lastMessage: ChatMessage(
        id: 'msg_1',
        conversationId: 'mock_convo_1',
        senderId: 'student_1',
        text: 'Hello Sir John, I have a question.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      ),
      unreadCount: 1,
    );
    
    state = state.copyWith(
      conversations: [mockConvo],
      messages: {
        'mock_convo_1': [mockConvo.lastMessage!]
      },
    );
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
