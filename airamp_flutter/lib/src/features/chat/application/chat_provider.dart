import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';
import '../../auth/application/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/firestore_service.dart';
import '../../notifications/application/notification_provider.dart';

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
  StreamSubscription? _activeMessageSubscription;
  String? _currentSubscribedConversationId;
  Timer? _periodicSyncTimer;
  bool _disposed = false;

  @override
  ChatState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _subscription?.cancel();
      _activeMessageSubscription?.cancel();
      _periodicSyncTimer?.cancel();
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

    // Lightweight cloud sync loop so incoming messages appear across devices automatically
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_disposed) return;
      final curUser = ref.read(authProvider);
      if (curUser != null) {
        try {
          await loadLocalConversations(force: false);
        } catch (_) {}
        if (_currentSubscribedConversationId != null && !_disposed) {
          try {
            await reloadMessages(_currentSubscribedConversationId!);
          } catch (_) {}
        }
      }
    });

    return ChatState();
  }

  /// Reload messages for a specific conversation from DB and Cloud Firestore.
  Future<void> reloadMessages(String conversationId) async {
    try {
      if (_disposed) return;
      // Sync latest cloud messages from Cloud Firestore first
      try {
        await FirestoreService().syncCloudMessagesForConversation(conversationId);
      } catch (_) {}
      if (_disposed) return;

      await _applyLocalMessages(conversationId);
    } catch (e) {
      debugPrint('[ChatNotifier] Error refreshing conversation messages: $e');
    }
  }

  Future<void> _applyLocalMessages(String conversationId) async {
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

    // De-duplicate by id & prune redundant welcome announcements
    final Map<String, ChatMessage> byId = {};
    bool hasSeenWelcome = false;
    for (final m in messages) {
      final isWelcome = m.text.startsWith('Welcome to the official group chat for ');
      if (isWelcome) {
        if (hasSeenWelcome) continue;
        hasSeenWelcome = true;
      }
      byId[m.id] = m;
    }

    final deduped = byId.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final messagesMap = Map<String, List<ChatMessage>>.from(state.messages);
    messagesMap[conversationId] = deduped;

    final lastMsg = deduped.isNotEmpty ? deduped.last : null;
    final updatedConvos = state.conversations.map((c) {
      if (c.id == conversationId) {
        return c.copyWith(lastMessage: lastMsg);
      }
      return c;
    }).toList();

    if (_disposed) return;
    state = state.copyWith(messages: messagesMap, conversations: updatedConvos);
  }

  /// Subscribes to real-time Cloud Firestore push updates for the active chat room.
  void subscribeToConversation(String conversationId) {
    final cleanConvId = conversationId.trim();
    if (cleanConvId.isEmpty) return;

    // Cancel previous room listener if switching rooms
    if (_currentSubscribedConversationId != cleanConvId) {
      _activeMessageSubscription?.cancel();
      _activeMessageSubscription = null;
      _currentSubscribedConversationId = cleanConvId;
    } else if (_activeMessageSubscription != null) {
      // Already subscribed to same conversation — just reload history
      reloadMessages(cleanConvId);
      return;
    }

    // Fetch cloud history immediately
    reloadMessages(cleanConvId);

    // Attach real-time Firestore snapshot listener
    _activeMessageSubscription = FirestoreService()
        .streamConversationMessages(cleanConvId)
        .listen(
      (rawMessages) async {
        if (_disposed) return;
        if (rawMessages.isEmpty) return;

        final db = DatabaseHelper();
        final currentUser = ref.read(authProvider);
        final myId = currentUser?.id;

        final List<ChatMessage> chatMsgs = [];
        for (final m in rawMessages) {
          final id = m['id']?.toString() ?? '';
          final text = m['text']?.toString() ?? '';
          final senderId = m['sender_id']?.toString() ?? '';
          final createdAt = m['created_at']?.toString() ?? DateTime.now().toIso8601String();
          final isRead = (m['is_read'] == true || m['is_read'] == 1);

          if (id.isEmpty || text.isEmpty) continue;

          chatMsgs.add(ChatMessage(
            id: id,
            conversationId: cleanConvId,
            senderId: senderId,
            text: text,
            createdAt: createdAt,
            isRead: isRead,
          ));

          // Save to local SQLite (non-blocking)
          db.saveMessage({
            'id': id,
            'conversation_id': cleanConvId,
            'sender_id': senderId,
            'text': text,
            'created_at': createdAt,
            'is_read': (isRead || senderId == myId) ? 1 : 0,
          }).catchError((_) {});
        }

        if (chatMsgs.isEmpty) return;

        // MERGE with existing messages in state rather than wiping them out!
        final existing = state.messages[cleanConvId] ?? [];
        final Map<String, ChatMessage> byId = {};
        for (final m in existing) {
          byId[m.id] = m;
        }

        bool hasSeenWelcome = false;
        for (final m in chatMsgs) {
          final isWelcome = m.text.startsWith('Welcome to the official group chat for ');
          if (isWelcome) {
            if (hasSeenWelcome) continue;
            hasSeenWelcome = true;
          }
          byId[m.id] = m;
        }

        final merged = byId.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        final messagesMap = Map<String, List<ChatMessage>>.from(state.messages);
        messagesMap[cleanConvId] = merged;

        final lastMsg = merged.isNotEmpty ? merged.last : null;
        final updatedConvos = state.conversations.map((c) {
          if (c.id == cleanConvId) return c.copyWith(lastMessage: lastMsg);
          return c;
        }).toList();

        if (_disposed) return;
        state = state.copyWith(
          messages: messagesMap,
          conversations: updatedConvos,
          isConnected: true,
        );

        // Notify for incoming messages from others
        final incoming = chatMsgs.where((m) => m.senderId != myId).toList();
        if (incoming.isNotEmpty) {
          _notifyIncomingMessage(incoming.last);
        }
      },
      onError: (err) {
        debugPrint('[ChatNotifier] Realtime stream error for $cleanConvId: $err');
      },
    );
  }

  void unsubscribeFromConversation([String? conversationId]) {
    if (conversationId == null || _currentSubscribedConversationId == conversationId) {
      _activeMessageSubscription?.cancel();
      _activeMessageSubscription = null;
      _currentSubscribedConversationId = null;
    }
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
    } catch (e) {
      debugPrint('[ChatNotifier] Error marking conversation as read: $e');
    }
  }

  /// Load conversations and messages from local SQLite database.
  Future<void> loadLocalConversations({bool force = true}) async {
    try {
      if (_disposed) return;
      // Sync cloud conversations and messages to local SQLite
      try {
        await FirestoreService().syncCloudConversationsToLocal(force: force);
        await FirestoreService().syncCloudMessagesToLocal(force: force);
        await FirestoreService().syncLocalMessagesToCloud();
      } catch (_) {}

      final db = DatabaseHelper();
      await db.normalizeDirectConversations();
      if (_disposed) return;

      final currentUser = ref.read(authProvider);
      if (currentUser == null) {
        if (!_disposed) {
          state = state.copyWith(conversations: [], messages: {});
        }
        return;
      }
      final myId = currentUser.id;

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
            // Institutional privacy: students cannot direct message other students
            if (currentUser.role == 'student' && matchedOther.role == 'student') {
              continue;
            }
            // Teachers can only direct message colleagues/admins and students in their handled sections
            if (currentUser.role == 'teacher' && matchedOther.role == 'student') {
              final handledSections = await db.getSectionsForTeacher(currentUser.id);
              final cleanSections = handledSections
                  .map((s) => s.trim().toLowerCase())
                  .where((s) => s.isNotEmpty && s != 'all handled sections' && s != 'all sections')
                  .map((s) {
                    if (s.startsWith('grade')) {
                      final idx = s.indexOf('-');
                      if (idx != -1) return s.substring(idx + 1).trim();
                    }
                    return s;
                  })
                  .toSet();
              var sSec = matchedOther.section?.trim().toLowerCase() ?? '';
              if (sSec.startsWith('grade')) {
                final idx = sSec.indexOf('-');
                if (idx != -1) sSec = sSec.substring(idx + 1).trim();
              }
              if (sSec.isEmpty || !cleanSections.contains(sSec)) {
                continue;
              }
            }
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

        final Map<String, ChatMessage> byId = {};
        bool hasSeenWelcome = false;
        for (final m in messages) {
          final isWelcome = m.text.startsWith('Welcome to the official group chat for ');
          if (isWelcome) {
            if (hasSeenWelcome) continue;
            hasSeenWelcome = true;
          }
          byId[m.id] = m;
        }
        final deduped = byId.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        loadedMessages[convId] = deduped;

        final lastMsg = deduped.isNotEmpty ? deduped.last : null;
        final isArchived = (row['is_archived'] as int? ?? 0) == 1;

        // Parse section-specific fields
        final secKey = row['section_key']?.toString().trim().toUpperCase();
        final secId = row['section_id'] is int ? row['section_id'] as int : int.tryParse(row['section_id']?.toString() ?? '');
        final roomAdminId = row['room_admin_id']?.toString();
        final roomAdminName = row['room_admin_name']?.toString();

        List<String> participantIds = [];
        final rawParticipantIds = row['participant_ids'];
        if (rawParticipantIds is String && rawParticipantIds.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawParticipantIds);
            if (decoded is List) {
              participantIds = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            }
          } catch (_) {
            participantIds = rawParticipantIds.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          }
        }

        // Strict section access control:
        // Only students enrolled in that section can view/join that section's group chat
        if (!isDirect && secKey != null && secKey.isNotEmpty) {
          if (currentUser.role == 'student') {
            final mySec = currentUser.section?.trim().toUpperCase() ?? '';
            final isMember = participantIds.contains(myId);
            final keyMatches = mySec.isNotEmpty && (mySec == secKey || mySec.contains(secKey));
            final nameMatches = mySec.isNotEmpty &&
                row['name']?.toString().toUpperCase().contains(mySec) == true;

            if (!isMember && !keyMatches && !nameMatches) {
              // Student does NOT belong to this section; hide this group chat
              continue;
            }
          } else if (currentUser.role == 'teacher') {
            final isRoomAdmin = roomAdminId == myId;
            final isMember = participantIds.contains(myId);
            // Allow if teacher is room admin or explicitly a participant
            if (!isRoomAdmin && !isMember) {
              // Check if teacher teaches any subjects in this section
              final mySubjects = await db.getSubjectsForTeacher(myId);
              final mySubCodes = mySubjects.map((s) => s['subject_code']?.toString().toUpperCase() ?? '').toSet();
              final sqliteDb = await db.database;
              final secRow = (await sqliteDb.query('sections', where: 'UPPER(enrollment_key) = ?', whereArgs: [secKey])).firstOrNull;
              bool teachesInSection = false;
              if (secRow != null && secRow['subject_ids'] != null) {
                try {
                  final decoded = jsonDecode(secRow['subject_ids'].toString());
                  if (decoded is List) {
                    teachesInSection = decoded.any((c) => mySubCodes.contains(c.toString().toUpperCase()));
                  }
                } catch (_) {}
              }
              if (!teachesInSection) {
                continue;
              }
            }
          }
        }

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
          sectionKey: secKey,
          sectionId: secId,
          roomAdminId: roomAdminId,
          roomAdminName: roomAdminName,
          participantIds: participantIds,
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
    if (FirestoreService().isAvailable) {
      state = state.copyWith(isConnected: true);
    }
    if (!ApiClient.isCloudAvailable) {
      if (!FirestoreService().isAvailable) {
        state = state.copyWith(isConnected: false);
      }
      return;
    }
    final repo = ref.read(chatRepositoryProvider);
    final token = ApiClient.hasSession ? userId : '';
    _subscription?.cancel();
    final stream = repo.connect(userId, token);
    _subscription = stream.listen(
      _handleWebSocketEvent,
      onError: (_) {
        if (!FirestoreService().isAvailable) {
          state = state.copyWith(isConnected: false);
        }
      },
      onDone: () {
        if (!FirestoreService().isAvailable) {
          state = state.copyWith(isConnected: false);
        }
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
      _notifyIncomingMessage(msg);
    }
  }

  void _notifyIncomingMessage(ChatMessage msg) {
    final currentUser = ref.read(authProvider);
    if (currentUser == null || msg.senderId == currentUser.id) return;

    // Find sender details
    final sender = state.availableUsers.cast<ChatUser?>().firstWhere(
      (u) => u?.id == msg.senderId,
      orElse: () => null,
    );
    final senderName = sender?.fullName ?? 'Classmate';

    // Find conversation details
    final convo = state.conversations.cast<ChatConversation?>().firstWhere(
      (c) => c?.id == msg.conversationId,
      orElse: () => null,
    );

    final isGroup = convo?.type == 'group' || !msg.conversationId.startsWith('dm_');
    final String title;
    if (isGroup && convo?.name != null && convo!.name!.isNotEmpty) {
      title = '$senderName in ${convo.name}';
    } else {
      title = senderName;
    }

    ref.read(notificationsProvider.notifier).addNotification(
      userId: currentUser.id,
      type: isGroup ? 'group_chat' : 'chat',
      title: title,
      message: msg.text,
      relatedId: msg.conversationId,
      targetRoute: '/chat/${msg.conversationId}',
      actorId: msg.senderId,
      actorName: senderName,
      showBanner: true,
    );
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
    
    // 1. Optimistic UI update immediately
    final messagesMap = Map<String, List<ChatMessage>>.from(state.messages);
    final list = messagesMap[conversationId] ?? [];
    // De-duplicate guard: don't add if same id already present
    if (!list.any((m) => m.id == msgId)) {
      messagesMap[conversationId] = [...list, newMsg];
    }
    
    final hasConvo = state.conversations.any((c) => c.id == conversationId);
    List<ChatConversation> updatedConvos;
    if (hasConvo) {
      updatedConvos = state.conversations.map((c) {
        if (c.id == conversationId) return c.copyWith(lastMessage: newMsg);
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

    // 2. Save locally (non-blocking)
    DatabaseHelper().saveMessage({
      'id': msgId,
      'conversation_id': conversationId,
      'sender_id': user.id,
      'text': text.trim(),
      'created_at': now,
      'is_read': 0,
    }).catchError((_) {});

    // 3. For direct conversations, notify recipient in local DB
    if (conversationId.startsWith('dm_')) {
      final parts = conversationId.replaceFirst('dm_', '').split('_');
      final recipientId = parts.firstWhere((id) => id != user.id, orElse: () => '');
      if (recipientId.isNotEmpty) {
        DatabaseHelper().createNotification(
          userId: recipientId,
          type: 'chat',
          title: user.fullName,
          message: text.trim(),
          relatedId: conversationId,
          targetRoute: '/chat/$conversationId',
          actorId: user.id,
          actorName: user.fullName,
        ).catchError((_) => '');
      }
    }

    // 4. Push to Cloud Firestore with guaranteed subcollection storage
    FirestoreService().saveChatMessage(
      conversationId: conversationId,
      messageId: msgId,
      data: {
        'id': msgId,
        'conversation_id': conversationId,
        'sender_id': user.id,
        'sender_name': user.fullName,
        'sender_role': user.role,
        'text': text.trim(),
        'created_at': now,
        'is_read': false,
      },
    ).then((_) {
      debugPrint('[ChatNotifier] Message $msgId delivered to Cloud Firestore');
    }).catchError((e) {
      debugPrint('[ChatNotifier] Firestore push failed: $e');
    });

    // 5. Send over WebSocket if available (optional fallback)
    try {
      ref.read(chatRepositoryProvider).sendMessage(conversationId, text.trim());
    } catch (_) {}
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
    if (user == null) {
      throw StateError('User must be logged in to create subject group chat.');
    }
    final creatorUser = ChatUser(id: user.id, fullName: user.fullName, email: user.email, role: user.role, profileImage: user.profileImage);

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
      List<ChatUser> filtered = currentUser != null
          ? users.where((u) => u.id != currentUser.id).toList()
          : users;

      // Apply institutional privacy boundaries
      if (currentUser != null) {
        if (currentUser.role == 'student') {
          // Students can ONLY contact their professors/teachers and school administrators
          final sqliteDb = await db.database;
          final teacherRows = await sqliteDb.rawQuery('''
            SELECT DISTINCT s.teacher_id, s.teacher_name 
            FROM enrollments e
            JOIN subjects s ON e.subject_id = s.id
            WHERE e.student_id = ? AND e.status = 'active'
          ''', [currentUser.id]);

          final enrolledTeacherIds = teacherRows
              .map((r) => r['teacher_id']?.toString().trim())
              .where((id) => id != null && id.isNotEmpty)
              .toSet();
          final enrolledTeacherNames = teacherRows
              .map((r) => r['teacher_name']?.toString().trim().toLowerCase())
              .where((n) => n != null && n.isNotEmpty)
              .toSet();

          filtered = filtered.where((u) {
            // School administrators are always reachable
            if (u.role == 'admin' || u.role == 'super_admin') return true;
            // Teachers / Professors: must teach an enrolled subject (or all teachers if not yet enrolled)
            if (u.role == 'teacher') {
              if (enrolledTeacherIds.isNotEmpty || enrolledTeacherNames.isNotEmpty) {
                return enrolledTeacherIds.contains(u.id) ||
                    enrolledTeacherNames.contains(u.fullName.trim().toLowerCase());
              }
              return true;
            }
            // Students cannot direct message other students (peers interact in the Section GC)
            return false;
          }).toList();
        } else if (currentUser.role == 'teacher') {
          // Teachers can contact fellow teachers/admins and ONLY students in their handled sections
          final handledSections = await db.getSectionsForTeacher(currentUser.id);
          final cleanHandledSections = handledSections
              .map((s) => s.trim().toLowerCase())
              .where((s) => s.isNotEmpty && s != 'all handled sections' && s != 'all sections')
              .map((s) {
                if (s.startsWith('grade')) {
                  final idx = s.indexOf('-');
                  if (idx != -1) return s.substring(idx + 1).trim();
                }
                return s;
              })
              .toSet();

          filtered = filtered.where((u) {
            // Teachers can contact fellow teachers and school administrators
            if (u.role == 'teacher' || u.role == 'admin' || u.role == 'super_admin') {
              return true;
            }
            // Teachers can ONLY contact students in their handled sections
            if (u.role == 'student') {
              if (cleanHandledSections.isEmpty) return false;
              var studentSec = u.section?.trim().toLowerCase();
              if (studentSec == null || studentSec.isEmpty) return false;
              if (studentSec.startsWith('grade')) {
                final idx = studentSec.indexOf('-');
                if (idx != -1) studentSec = studentSec.substring(idx + 1).trim();
              }
              return cleanHandledSections.contains(studentSec);
            }
            return false;
          }).toList();
        }
      }

      if (_disposed) return;
      state = state.copyWith(availableUsers: filtered);
    } catch (e) {
      debugPrint('[ChatNotifier] Error filtering available users: $e');
    }
  }

  /// Retrieves or creates a 1-on-1 direct conversation with the target user.
  Future<ChatConversation?> getOrCreateConversation(String targetUserId) async {
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return null;
    final myId = currentUser.id;

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

    // Institutional access boundaries:
    if (currentUser.role == 'student' && targetUser?.role == 'student') {
      debugPrint('[ChatNotifier] Blocked attempt by student to create 1-on-1 chat with another student.');
      return null;
    }

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
