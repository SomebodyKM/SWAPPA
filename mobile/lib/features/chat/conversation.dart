/// A single chat message. Mirrors the backend `Message` document
/// (`GET /conversations/:id/messages`, and realtime `message:*` socket events).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.body,
    this.mediaUrl,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String type; // text | image | audio | video | system
  final String? body;
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool isFromMe(String myUserId) => senderId == myUserId;

  String get timeLabel {
    final local = createdAt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  ChatMessage copyWith({
    String? body,
    DateTime? editedAt,
    DateTime? deletedAt,
  }) => ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    type: type,
    body: body ?? this.body,
    mediaUrl: mediaUrl,
    createdAt: createdAt,
    editedAt: editedAt ?? this.editedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return ChatMessage(
      id: (json['_id'] ?? json['id']).toString(),
      conversationId: (json['conversation'] ?? '').toString(),
      senderId: (json['sender'] ?? '').toString(),
      type: (json['type'] ?? 'text') as String,
      body: json['body'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      createdAt: parse(json['createdAt']) ?? DateTime.now(),
      editedAt: parse(json['editedAt']),
      deletedAt: parse(json['deletedAt']),
    );
  }
}

/// A conversation between the signed-in user and one other participant.
/// Mirrors the backend `Conversation` document (`GET/POST /conversations`),
/// with `participants` already resolved down to "the other person".
class Conversation {
  const Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount;

  String get initials {
    final parts = otherUserName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Compact relative time for the conversation list ("2m", "1h", "3d").
  String get relativeTime {
    final t = lastMessageAt;
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  factory Conversation.fromJson(Map<String, dynamic> json, String myUserId) {
    final participants = ((json['participants'] as List?) ?? const [])
        .whereType<Map>()
        .map((p) => p.cast<String, dynamic>())
        .toList();
    final other = participants.firstWhere(
      (p) => (p['_id'] ?? p['id']).toString() != myUserId,
      orElse: () => participants.isNotEmpty
          ? participants.first
          : const <String, dynamic>{},
    );
    return Conversation(
      id: (json['_id'] ?? json['id']).toString(),
      otherUserId: (other['_id'] ?? other['id'] ?? '').toString(),
      otherUserName: (other['displayName'] ?? 'Unknown') as String,
      otherUserPhotoUrl: other['photoUrl'] as String?,
      lastMessagePreview: json['lastMessagePreview'] as String?,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString())
          : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}
