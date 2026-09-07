class ChatUser {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? section;
  final String? grade;
  
  ChatUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.section,
    this.grade,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      section: json['section'],
      grade: json['grade'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'role': role,
      'section': section,
      'grade': grade,
    };
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final String createdAt;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'] ?? '',
      text: json['text'] ?? '',
      createdAt: json['createdAt'] ?? '',
      isRead: json['isRead'] ?? false,
    );
  }
}

class ChatConversation {
  final String id;
  final String type; // 'direct' | 'group'
  final String? name;
  final List<ChatUser> participants;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final bool isArchived;

  ChatConversation({
    required this.id,
    required this.type,
    this.name,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    this.isArchived = false,
  });

  ChatConversation copyWith({
    String? id,
    String? type,
    String? name,
    List<ChatUser>? participants,
    ChatMessage? lastMessage,
    int? unreadCount,
    bool? isArchived,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] ?? '',
      type: json['type'] ?? 'direct',
      name: json['name'],
      participants: (json['participants'] as List?)
              ?.map((e) => ChatUser.fromJson(e))
              .toList() ??
          [],
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      isArchived: (json['isArchived'] ?? json['is_archived']) == 1 || (json['isArchived'] == true),
    );
  }
}
