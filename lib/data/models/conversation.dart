import 'conversation_node.dart';

/// Top-level container for a full conversation, including all its virtual pages.
///
/// A [Conversation] is a directed graph of [ConversationNode]s where the
/// root node is the primary chat thread and child nodes are virtual pages
/// created through text-selection exploration.
class Conversation {
  final String id;
  final String title;

  /// ID of the root [ConversationNode] (the main chat thread).
  final String rootNodeId;

  /// All nodes in this conversation, keyed by [ConversationNode.id].
  final Map<String, ConversationNode> nodes;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.title,
    required this.rootNodeId,
    required this.nodes,
    required this.createdAt,
    required this.updatedAt,
  });

  ConversationNode get rootNode => nodes[rootNodeId]!;

  Conversation copyWith({
    String? title,
    Map<String, ConversationNode>? nodes,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      rootNodeId: rootNodeId,
      nodes: nodes ?? this.nodes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'rootNodeId': rootNodeId,
        'nodes': nodes
            .map((key, value) => MapEntry(key, value.toJson())),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        title: json['title'] as String,
        rootNodeId: json['rootNodeId'] as String,
        nodes: (json['nodes'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(
            key,
            ConversationNode.fromJson(value as Map<String, dynamic>),
          ),
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
