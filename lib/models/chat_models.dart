class TopicChat {
  final String id;
  final String title;
  final DateTime createdAt;

  TopicChat({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory TopicChat.fromMap(Map<String, dynamic> map) {
    return TopicChat(
      id: map['id'],
      title: map['title'] ?? 'Chat',
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class ChatMessage {
  final String id;
  final String chatId;
  final String sender;
  final String content;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.sender,
    required this.content,
    required this.sentAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      chatId: map['chat_id'],
      sender: map['sender'] ?? 'user',
      content: map['content'] ?? '',
      sentAt: DateTime.parse(map['sent_at']),
    );
  }
}