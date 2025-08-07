enum MessageSender { user, ai }
enum AgentMessageType { text, toolRequest, toolResult, error, toolInProgress }

class AgentChatMessage {
  final String id;
  final String chatId;
  final MessageSender sender;
  final AgentMessageType messageType;
  final String content;
  final Map<String, dynamic>? toolCalls;
  final Map<String, dynamic>? toolResults;
  final DateTime sentAt;

  AgentChatMessage({
    required this.id,
    required this.chatId,
    required this.sender,
    required this.messageType,
    required this.content,
    this.toolCalls,
    this.toolResults,
    required this.sentAt,
  });

  factory AgentChatMessage.fromMap(Map<String, dynamic> map) {
    return AgentChatMessage(
      id: map['id'],
      chatId: map['chat_id'],
      sender: MessageSender.values.byName(map['sender']),
      messageType: AgentMessageType.values.byName(map['message_type']),
      content: map['content'] ?? '',
      toolCalls: map['tool_calls'],
      toolResults: map['tool_results'],
      sentAt: DateTime.parse(map['sent_at']),
    );
  }

  AgentChatMessage copyWith({
    String? id,
    String? chatId,
    MessageSender? sender,
    AgentMessageType? messageType,
    String? content,
    Map<String, dynamic>? toolCalls,
    Map<String, dynamic>? toolResults,
    DateTime? sentAt,
  }) {
    return AgentChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      sender: sender ?? this.sender,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      toolCalls: toolCalls ?? this.toolCalls,
      toolResults: toolResults ?? this.toolResults,
      sentAt: sentAt ?? this.sentAt,
    );
  }
}
