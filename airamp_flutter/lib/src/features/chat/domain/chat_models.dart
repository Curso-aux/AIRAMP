class ChatUser {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? section;
  final String? grade;
  final String? profileImage;

  ChatUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.section,
    this.grade,
    this.profileImage,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      section: json['section'],
      grade: json['grade'],
      profileImage: json['profileImage'] ?? json['profile_image'],
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
      'profile_image': profileImage,
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
  final String? sectionKey;
  final int? sectionId;
  final String? roomAdminId;
  final String? roomAdminName;
  final List<String> participantIds;

  ChatConversation({
    required this.id,
    required this.type,
    this.name,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    this.isArchived = false,
    this.sectionKey,
    this.sectionId,
    this.roomAdminId,
    this.roomAdminName,
    this.participantIds = const [],
  });

  ChatConversation copyWith({
    String? id,
    String? type,
    String? name,
    List<ChatUser>? participants,
    ChatMessage? lastMessage,
    int? unreadCount,
    bool? isArchived,
    String? sectionKey,
    int? sectionId,
    String? roomAdminId,
    String? roomAdminName,
    List<String>? participantIds,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
      sectionKey: sectionKey ?? this.sectionKey,
      sectionId: sectionId ?? this.sectionId,
      roomAdminId: roomAdminId ?? this.roomAdminId,
      roomAdminName: roomAdminName ?? this.roomAdminName,
      participantIds: participantIds ?? this.participantIds,
    );
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    List<String> parsedParticipantIds = [];
    final rawIds =
        json['participant_ids'] ??
        json['participantIds'] ??
        json['participants'];
    if (rawIds is List) {
      parsedParticipantIds = rawIds
          .map((e) => e is Map ? (e['id']?.toString() ?? '') : e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return ChatConversation(
      id: json['id'] ?? '',
      type: json['type'] ?? 'direct',
      name: json['name'],
      participants:
          (json['participants'] as List?)
              ?.whereType<Map>()
              .map((e) => ChatUser.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      isArchived:
          (json['isArchived'] ?? json['is_archived']) == 1 ||
          (json['isArchived'] == true),
      sectionKey: json['section_key'] ?? json['sectionKey'],
      sectionId: json['section_id'] is int
          ? json['section_id']
          : int.tryParse(json['section_id']?.toString() ?? ''),
      roomAdminId: json['room_admin_id'] ?? json['roomAdminId'],
      roomAdminName: json['room_admin_name'] ?? json['roomAdminName'],
      participantIds: parsedParticipantIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'unreadCount': unreadCount,
      'isArchived': isArchived,
      'section_key': sectionKey,
      'section_id': sectionId,
      'room_admin_id': roomAdminId,
      'room_admin_name': roomAdminName,
      'participant_ids': participantIds,
    };
  }
}
