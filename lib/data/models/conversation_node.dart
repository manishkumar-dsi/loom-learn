import 'message.dart';

/// A "page" in the conversation graph. The root node is the main chat thread;
/// child nodes are virtual pages created by text-selection exploration.
class ConversationNode {
  final String id;

  /// ID of the owning [Conversation].
  final String conversationId;

  /// Null for the root node; set to the parent node's ID for virtual pages.
  final String? parentNodeId;

  /// The text the user selected to spawn this virtual page (null for root).
  final String? triggerText;

  /// Display title (derived from triggerText or the first user message).
  final String title;

  final List<Message> messages;

  final DateTime createdAt;

  const ConversationNode({
    required this.id,
    required this.conversationId,
    this.parentNodeId,
    this.triggerText,
    required this.title,
    this.messages = const [],
    required this.createdAt,
  });

  bool get isRoot => parentNodeId == null;

  ConversationNode copyWith({
    String? title,
    List<Message>? messages,
  }) {
    return ConversationNode(
      id: id,
      conversationId: conversationId,
      parentNodeId: parentNodeId,
      triggerText: triggerText,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'parentNodeId': parentNodeId,
        'triggerText': triggerText,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory ConversationNode.fromJson(Map<String, dynamic> json) =>
      ConversationNode(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        parentNodeId: json['parentNodeId'] as String?,
        triggerText: json['triggerText'] as String?,
        title: json['title'] as String,
        messages: (json['messages'] as List<dynamic>)
            .map((e) => Message.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
