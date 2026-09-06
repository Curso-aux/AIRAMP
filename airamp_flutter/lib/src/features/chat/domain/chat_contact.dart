/// Model for device contacts that can be matched to AIRA app users.
/// Mirrors the rork ChatContact type.
class ChatContact {
  final String id;
  final String name;
  final List<String> phoneNumbers;
  final List<String> emails;
  final String? matchedUserId;

  ChatContact({
    required this.id,
    required this.name,
    this.phoneNumbers = const [],
    this.emails = const [],
    this.matchedUserId,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phoneNumbers: List<String>.from(json['phoneNumbers'] ?? []),
      emails: List<String>.from(json['emails'] ?? []),
      matchedUserId: json['matchedUserId'],
    );
  }
}
