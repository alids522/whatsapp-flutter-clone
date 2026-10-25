class Profile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  Profile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        displayName: json['display_name'] as String? ??
            json['username'] as String? ??
            '',
        avatarUrl: json['avatar_url'] as String?,
      );
}

class ChatSummary {
  final String id;
  final String title;
  final bool isGroup;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool lastMessageMine;
  final bool lastMessageRead;

  ChatSummary({
    required this.id,
    required this.title,
    required this.isGroup,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageMine = false,
    this.lastMessageRead = true,
  });
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String? body;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.body,
    this.imageUrl,
    required this.createdAt,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        chatId: json['chat_id'] as String,
        senderId: json['sender_id'] as String,
        body: json['body'] as String?,
        imageUrl: json['image_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        isRead: json['is_read'] as bool? ?? false,
      );
}

class StatusItem {
  final String id;
  final String userId;
  final String username;
  final String text;
  final DateTime createdAt;

  StatusItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.text,
    required this.createdAt,
  });

  factory StatusItem.fromJson(
    Map<String, dynamic> json,
    String username,
  ) =>
      StatusItem(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        username: username,
        text: json['text'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
