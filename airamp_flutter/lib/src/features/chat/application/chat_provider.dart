import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';
import '../../auth/application/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/database/database_helper.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

class ChatState {
  final bool isConnected;
  final List<ChatConversation> conversations;
  final Map<String, List<ChatMessage>> messages; // conversationId -> messages
  final List<ChatUser> availableUsers;

  ChatState({
    this.isConnected = false,
    this.conversations = const [],
    this.messages = const {},
    this.availableUsers = const [],
  });

  ChatState copyWith({
    bool? isConnected,
    List<ChatConversation>? conversations,
    Map<String, List<ChatMessage>>? messages,
    List<ChatUser>? availableUsers,
  }) {
    return ChatState(
      isConnected: isConnected ?? this.isConnected,
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
      availableUsers: availableUsers ?? this.availableUsers,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  StreamSubscription? _subscription;
  bool _disposed = false;

  @override
  ChatState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _subscription?.cancel();
    });

    // Listen to auth changes: whenever user logs in or switches, reload everything!
    ref.listen<User?>(authProvider, (prev, next) {
      if (next != null) {
        Future.microtask(() async {
          if (_disposed) return;
          await loadAvailableUsers();
          if (_disposed) return;
          await loadLocalConversations();
          if (_disposed) return;
          _connectAndLoad(next.id);
        });
      } else if (prev != null) {
        _disconnect();
      }
    });

    // Load local conversations and connect websocket if authenticated
    final user = ref.read(authProvider);
    Future.microtask(() async {
      if (_disposed) return;
      await loadAvailableUsers();
      if (_disposed) return;
      await loadLocalConversations();
      if (_disposed) return;
      if (user != null) {
        _connectAndLoad(user.id);
      }
    });

    return ChatState();
  }

  /// Reload messages for a specific conversation from DB (so student sees teacher's messages)
  Future<void> reloadMessages(String conversationId) async {
    try {
      if (_disposed) return;
      final db = DatabaseHelper();
      final rawMessages = await db.getMessages(conversationId);
      if (_disposed) return;
      final messages = rawMessages.map((m) => ChatMessage(
        id: m['id'] as String,
        conversationId: conversationId,
        senderId: m['sender_id'] as String,
        text: m['text'] as String,
        createdAt: m['created_at'] as String,
        isRead: (m['is_read'] as int? ?? 0) == 1,
      )).toList();
      final messagesMap = Map<String, List<ChatMessage>>.from(state.messages);
      messagesMap[conversationId] = messages;

      final lastMsg = messages.isNotEmpty ? messages.last : null;
      final updatedConvos = state.conversations.map((c) {
        if (c.id == conversationId) {
          return c.copyWith(lastMessage: lastMsg);
        }
        return c;
      }).toList();

      if (_disposed) return;
      state = state.copyWith(messages: messagesMap, conversations: updatedConvos);
    } catch (_) {}
  }

  /// Mark messages in conversation as read and update unread count
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      if (_disposed) return;
      final user = ref.read(authProvider);
      final myId = user?.id;
      final db = DatabaseHelper();
      await db.markMessagesAsRead(conversationId, excludeSenderId: myId);
      if (_disposed) return;

      final currentMsgs = state.messages[conversationId];
      if (currentMsgs != null) {
        final updatedMsgs = currentMsgs.map((m) {
          if (m.senderId != myId && !m.isRead) {
            return ChatMessage(
              id: m.id,
              conversationId: m.conversationId,
              senderId: m.senderId,
              text: m.text,
              createdAt: m.createdAt,
              isRead: true,
            );
          }
          return m;
        }).toList();

        final messagesMap = Map<String, List<ChatMessage>>.from(state.messages);
        messagesMap[conversationId] = updatedMsgs;

        final updatedConvos = state.conversations.map((c) {
          if (c.id == conversationId) {
            return c.copyWith(unreadCount: 0);
          }
          return c;
        }).toList();

        if (_disposed) return;
        state = state.copyWith(messages: messagesMap, conversations: updatedConvos);
      }
    } catch (_) {}
  }

  /// Load conversations and messages from local SQLite database.
  Future<void> loadLocalConversations() async {
    try {
      if (_disposed) return;
      final db = DatabaseHelper();
      await db.normalizeDirectConversations();
      if (_disposed) return;

      final currentUser = ref.read(authProvider);
      final myId = currentUser?.id ?? 'teacher_1';

      final allUserRows = await db.getUsers();
      if (_disposed) return;
      final allUsers = allUserRows.map((r) => ChatUser.fromJson(r)).toList();

      final rows = await db.getConversations();
      if (_disposed) return;
      final List<ChatConversation> loadedConversations = [];
      final Map<String, List<ChatMessage>> loadedMessages = {};

      for (final row in rows) {
        final convId = row['id'] as String;
        final type = row['type'] as String? ?? 'direct';
        final isDirect = type == 'direct' || convId.startsWith('dm_');

        ChatUser? otherParticipant;

        if (isDirect) {
          ChatUser? matchedOther;
          for (final u in allUsers) {
            if (u.id == myId) continue;
            final sorted = [myId, u.id]..sort();
            final expected = 'dm_${sorted[0]}_${sorted[1]}';
            final legacy1 = 'dm_${myId}_${u.id}';
            final legacy2 = 'dm_${u.id}_$myId';
            if (convId == expected || convId == legacy1 || convId == legacy2) {
              matchedOther = u;
              break;
            }
          }

          if (matchedOther != null) {
            otherParticipant = matchedOther;
          } else {
            // Direct conversation between two other users; hide from current user
            continue;
          }
        }

        final rawMessages = await db.getMessages(convId);
        if (_disposed) return;
        final messages = rawMessages.map((m) => ChatMessage(
          id: m['id'] as String,
          conversationId: convId,
          senderId: m['sender_id'] as String,
          text: m['text'] as String,
          createdAt: m['created_at'] as String,
          isRead: (m['is_read'] as int? ?? 0) == 1,
        )).toList();

        loadedMessages[convId] = messages;

        final lastMsg = messages.isNotEmpty ? messages.last : null;
        final isArchived = (row['is_archived'] as int? ?? 0) == 1;

        // Display name: for direct chats, always show the OTHER participant's name!
        String displayName;
        if (isDirect && otherParticipant != null) {
          displayName = otherParticipant.fullName;
        } else {
          displayName = row['name'] as String? ?? 'Chat';
        }

        final unreadCount = messages.where((m) => m.senderId != myId && !m.isRead).length;

        loadedConversations.add(ChatConversation(
          id: convId,
          type: type,
          name: displayName,
          participants: otherParticipant != null ? [otherParticipant] : const [],
          lastMessage: lastMsg,
          unreadCount: unreadCount,
          isArchived: isArchived,
        ));
      }

      if (_disposed) return;
      state = state.copyWith(
        conversations: loadedConversations,
        messages: loadedMessages,
      );
    } catch (_) {
      // Fallback silently if db query fails
    }
  }

  void _connectAndLoad(String userId) {
    if (_disposed) return;
    if (!ApiClient.isCloudAvailable) {
      state = state.copyWith(isConnected: false);
      return;
    }
    final repo = ref.read(chatRepositoryProvider);
    final token = ApiClient.hasSession ? userId : '';
    _subscription?.cancel();
    final stream = repo.connect(userId, token);
    _subscription = stream.listen(
      _handleWebSocketEvent,
      onError: (_) {
        state = state.copyWith(isConnected: false);
      },
      onDone: () {
        state = state.copyWith(isConnected: false);
      },
    );
    state = state.copyWith(isConnected: true);
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
    if (user == null || text.trim().isEmpty) return;
    
    final now = DateTime.now().toIso8601String();
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

    final newMsg = ChatMessage(
      id: msgId,
      conversationId: conversationId,
      senderId: user.id,
      text: text.trim(),
      createdAt: now,
      isRead: false,
    );
    
    // Save locally: is_read is 0 so recipient sees it as unread message
    DatabaseHelper().saveMessage({
      'id': msgId,
      'conversation_id': conversationId,
      'sender_id': user.id,
      'text': text.trim(),
      'created_at': now,
      'is_read': 0,
    }).catchError((_) {});

    final messagesMap = Map<String, List<ChatMessage>>.from(state.messages);
    final list = messagesMap[conversationId] ?? [];
    messagesMap[conversationId] = [...list, newMsg];
    
    // Update conversation lastMessage in list
    final hasConvo = state.conversations.any((c) => c.id == conversationId);
    List<ChatConversation> updatedConvos;
    if (hasConvo) {
      updatedConvos = state.conversations.map((c) {
        if (c.id == conversationId) {
          return c.copyWith(lastMessage: newMsg);
        }
        return c;
      }).toList();
    } else {
      final newConvo = ChatConversation(
        id: conversationId,
        type: conversationId.startsWith('dm_') ? 'direct' : 'group',
        name: 'Chat',
        participants: const [],
        lastMessage: newMsg,
        unreadCount: 0,
      );
      updatedConvos = [newConvo, ...state.conversations];
    }

    state = state.copyWith(messages: messagesMap, conversations: updatedConvos);
    
    // Send over socket if available
    ref.read(chatRepositoryProvider).sendMessage(conversationId, text.trim());
  }

  /// Creates or retrieves a dedicated subject group chat conversation.
  Future<ChatConversation> createSubjectGroupChat({
    required String subjectName,
    String? subjectCode,
    int? subjectId,
  }) async {
    final code = subjectCode?.trim() ?? '';
    final name = subjectName.trim();
    final groupName = code.isNotEmpty ? '$code - $name' : name;

    // Check if a group chat for this subject already exists
    if (subjectId != null) {
      final existingRow = await DatabaseHelper().getConversationBySubjectId(subjectId);
      if (existingRow != null) {
        final existingId = existingRow['id'] as String;
        final match = state.conversations.where((c) => c.id == existingId);
        if (match.isNotEmpty) {
          return match.first;
        }
      }
    }

    final convId = 'group_subject_${subjectId ?? DateTime.now().millisecondsSinceEpoch}';
    final user = ref.read(authProvider);
    final creatorUser = user != null
        ? ChatUser(id: user.id, fullName: user.fullName, email: user.email, role: user.role)
        : ChatUser(id: 'teacher_1', fullName: 'Teacher', email: '', role: 'admin');

    final now = DateTime.now().toIso8601String();
    final welcomeMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final welcomeText = 'Welcome to the $groupName group chat! Announcements, discussion topics, and questions can be posted here.';

    final welcomeMsg = ChatMessage(
      id: welcomeMsgId,
      conversationId: convId,
      senderId: creatorUser.id,
      text: welcomeText,
      createdAt: now,
      isRead: true,
    );

    // Persist to local database
    await DatabaseHelper().saveConversation({
      'id': convId,
      'type': 'group',
      'name': groupName,
      'subject_id': subjectId,
      'created_at': now,
    });

    await DatabaseHelper().saveMessage({
      'id': welcomeMsgId,
      'conversation_id': convId,
      'sender_id': creatorUser.id,
      'text': welcomeText,
      'created_at': now,
      'is_read': 1,
    });

    final newConversation = ChatConversation(
      id: convId,
      type: 'group',
      name: groupName,
      participants: [creatorUser],
      lastMessage: welcomeMsg,
      unreadCount: 0,
    );

    final updatedConvos = [
      newConversation,
      ...state.conversations.where((c) => c.id != convId),
    ];
    final updatedMessages = Map<String, List<ChatMessage>>.from(state.messages);
    updatedMessages[convId] = [welcomeMsg];

    state = state.copyWith(
      conversations: updatedConvos,
      messages: updatedMessages,
    );

    return newConversation;
  }

  /// Loads all available app users for contacts and 1-on-1 conversations.
  Future<void> loadAvailableUsers() async {
    try {
      if (_disposed) return;
      final db = DatabaseHelper();
      final rows = await db.getUsers();
      if (_disposed) return;
      final currentUser = ref.read(authProvider);

      final users = rows.map((r) => ChatUser.fromJson(r)).toList();
      final filtered = currentUser != null
          ? users.where((u) => u.id != currentUser.id).toList()
          : users;

      if (_disposed) return;
      state = state.copyWith(availableUsers: filtered);
    } catch (_) {}
  }

  /// Retrieves or creates a 1-on-1 direct conversation with the target user.
  Future<ChatConversation?> getOrCreateConversation(String targetUserId) async {
    final currentUser = ref.read(authProvider);
    final myId = currentUser?.id ?? 'teacher_1';

    // Canonical direct conversation ID: sorted so it is identical for both users
    final sortedIds = [myId, targetUserId]..sort();
    final canonicalId = 'dm_${sortedIds[0]}_${sortedIds[1]}';
    final legacyId1 = 'dm_${myId}_$targetUserId';
    final legacyId2 = 'dm_${targetUserId}_$myId';

    // Find the target user in availableUsers or database
    ChatUser? targetUser;
    final match = state.availableUsers.where((u) => u.id == targetUserId);
    if (match.isNotEmpty) {
      targetUser = match.first;
    } else {
      final db = DatabaseHelper();
      final rows = await db.getUsers();
      if (_disposed) return null;
      final dbMatch = rows.where((r) => r['id'] == targetUserId);
      if (dbMatch.isNotEmpty) {
        targetUser = ChatUser.fromJson(dbMatch.first);
      }
    }

    final targetName = targetUser?.fullName ?? 'Direct Chat';

    // Check existing conversation in state
    for (final conv in state.conversations) {
      if (conv.id == canonicalId || conv.id == legacyId1 || conv.id == legacyId2) {
        return conv.copyWith(
          name: targetName,
          participants: targetUser != null ? [targetUser] : conv.participants,
        );
      }
    }

    // Check database
    final dbHelper = DatabaseHelper();
    final existingRow = await dbHelper.getDirectConversation(myId, targetUserId);
    if (existingRow != null) {
      final existingId = existingRow['id'] as String;
      final rawMessages = await dbHelper.getMessages(existingId);
      if (_disposed) return null;
      final messages = rawMessages.map((m) => ChatMessage(
        id: m['id'] as String,
        conversationId: existingId,
        senderId: m['sender_id'] as String,
        text: m['text'] as String,
        createdAt: m['created_at'] as String,
        isRead: (m['is_read'] as int? ?? 0) == 1,
      )).toList();

      final existingConv = ChatConversation(
        id: existingId,
        type: 'direct',
        name: targetName,
        participants: targetUser != null ? [targetUser] : [],
        lastMessage: messages.isNotEmpty ? messages.last : null,
        unreadCount: messages.where((m) => m.senderId != myId && !m.isRead).length,
      );

      final updatedMessages = Map<String, List<ChatMessage>>.from(state.messages);
      updatedMessages[existingId] = messages;

      if (_disposed) return existingConv;
      state = state.copyWith(
        conversations: [existingConv, ...state.conversations.where((c) => c.id != existingId)],
        messages: updatedMessages,
      );
      return existingConv;
    }

    // Create new direct conversation using canonical ID
    final now = DateTime.now().toIso8601String();

    await dbHelper.saveConversation({
      'id': canonicalId,
      'type': 'direct',
      'name': targetName,
      'created_at': now,
    });
    if (_disposed) return null;

    final newConv = ChatConversation(
      id: canonicalId,
      type: 'direct',
      name: targetName,
      participants: targetUser != null ? [targetUser] : [],
      lastMessage: null,
      unreadCount: 0,
    );

    if (_disposed) return newConv;
    state = state.copyWith(
      conversations: [newConv, ...state.conversations.where((c) => c.id != canonicalId)],
    );

    return newConv;
  }

  Future<void> editConversationName(String conversationId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    if (_disposed) return;
    final dbHelper = DatabaseHelper();
    await dbHelper.updateConversationName(conversationId, trimmed);
    if (_disposed) return;

    final updated = state.conversations.map((c) {
      if (c.id == conversationId) {
        return c.copyWith(name: trimmed);
      }
      return c;
    }).toList();

    if (_disposed) return;
    state = state.copyWith(conversations: updated);
  }

  Future<void> archiveConversation(String conversationId, {bool archive = true}) async {
    if (_disposed) return;
    final dbHelper = DatabaseHelper();
    await dbHelper.setConversationArchived(conversationId, archive);
    if (_disposed) return;

    final updated = state.conversations.map((c) {
      if (c.id == conversationId) {
        return c.copyWith(isArchived: archive);
      }
      return c;
    }).toList();

    if (_disposed) return;
    state = state.copyWith(conversations: updated);
  }

  Future<void> deleteConversation(String conversationId) async {
    if (_disposed) return;
    final dbHelper = DatabaseHelper();
    await dbHelper.deleteConversation(conversationId);
    if (_disposed) return;

    final updatedConversations = state.conversations.where((c) => c.id != conversationId).toList();
    final updatedMessages = Map<String, List<ChatMessage>>.from(state.messages);
    updatedMessages.remove(conversationId);

    if (_disposed) return;
    state = state.copyWith(
      conversations: updatedConversations,
      messages: updatedMessages,
    );
  }

  Future<void> editMessage(String conversationId, String messageId, String newText) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    if (_disposed) return;
    final dbHelper = DatabaseHelper();
    await dbHelper.updateMessageText(messageId, trimmed);
    if (_disposed) return;

    final currentMsgs = state.messages[conversationId] ?? [];
    final updatedMsgs = currentMsgs.map((m) {
      if (m.id == messageId) {
        return ChatMessage(
          id: m.id,
          conversationId: m.conversationId,
          senderId: m.senderId,
          text: trimmed,
          createdAt: m.createdAt,
          isRead: m.isRead,
        );
      }
      return m;
    }).toList();

    final updatedMap = Map<String, List<ChatMessage>>.from(state.messages);
    updatedMap[conversationId] = updatedMsgs;

    final updatedConvos = state.conversations.map((c) {
      if (c.id == conversationId && c.lastMessage?.id == messageId) {
        return c.copyWith(lastMessage: updatedMsgs.last);
      }
      return c;
    }).toList();

    if (_disposed) return;
    state = state.copyWith(
      messages: updatedMap,
      conversations: updatedConvos,
    );
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    if (_disposed) return;
    final dbHelper = DatabaseHelper();
    await dbHelper.deleteMessage(messageId);
    if (_disposed) return;

    final currentMsgs = state.messages[conversationId] ?? [];
    final updatedMsgs = currentMsgs.where((m) => m.id != messageId).toList();

    final updatedMap = Map<String, List<ChatMessage>>.from(state.messages);
    updatedMap[conversationId] = updatedMsgs;

    final updatedConvos = state.conversations.map((c) {
      if (c.id == conversationId && c.lastMessage?.id == messageId) {
        return c.copyWith(lastMessage: updatedMsgs.isNotEmpty ? updatedMsgs.last : null);
      }
      return c;
    }).toList();

    if (_disposed) return;
    state = state.copyWith(
      messages: updatedMap,
      conversations: updatedConvos,
    );
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(() {
  return ChatNotifier();
});
