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
  final List<dynamic>? attachedFiles;
  final String? feedback; // 'like' | 'dislike' | null
  final DateTime sentAt;

  AgentChatMessage({
    required this.id,
    required this.chatId,
    required this.sender,
    required this.messageType,
    required this.content,
    this.toolCalls,
    this.toolResults,
    this.attachedFiles,
    this.feedback,
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
      attachedFiles: map['attached_files'],
      feedback: map['feedback'],
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
    List<dynamic>? attachedFiles,
    String? feedback,
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
      attachedFiles: attachedFiles ?? this.attachedFiles,
      feedback: feedback ?? this.feedback,
      sentAt: sentAt ?? this.sentAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender': sender.name,
      'message_type': messageType.name,
      'content': content,
      'tool_calls': toolCalls,
      'tool_results': toolResults,
      'attached_files': attachedFiles,
      'feedback': feedback,
      'sent_at': sentAt.toIso8601String(),
    };
  }
}
