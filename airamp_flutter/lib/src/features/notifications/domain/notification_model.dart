class AppNotification {
  final String id;
  final String userId;
  final String type; // 'chat' | 'group_chat' | 'quiz' | 'offline_sync' | 'security' | 'announcement'
  final String title;
  final String message;
  final bool isRead;
  final String createdAt;
  final String? relatedId;
  final String? targetRoute;
  final int? subjectId;
  final String? actorId;
  final String? actorName;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.relatedId,
    this.targetRoute,
    this.subjectId,
    this.actorId,
    this.actorName,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'announcement',
      title: map['title']?.toString() ?? 'Notification',
      message: map['message']?.toString() ?? '',
      isRead: (map['is_read'] as int? ?? 0) == 1,
      createdAt: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      relatedId: map['related_id']?.toString(),
      targetRoute: map['target_route']?.toString(),
      subjectId: map['subject_id'] is int ? map['subject_id'] as int : int.tryParse(map['subject_id']?.toString() ?? ''),
      actorId: map['actor_id']?.toString(),
      actorName: map['actor_name']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt,
      'related_id': relatedId,
      'target_route': targetRoute,
      'subject_id': subjectId,
      'actor_id': actorId,
      'actor_name': actorName,
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? message,
    bool? isRead,
    String? createdAt,
    String? relatedId,
    String? targetRoute,
    int? subjectId,
    String? actorId,
    String? actorName,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      relatedId: relatedId ?? this.relatedId,
      targetRoute: targetRoute ?? this.targetRoute,
      subjectId: subjectId ?? this.subjectId,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
    );
  }
}
