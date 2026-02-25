/// Represents a highlighted span of text inside a [Message] that links
/// to a child [ConversationNode] (a "virtual page").
class TextLink {
  final String id;

  /// The exact text the user highlighted to create this exploration.
  final String triggerText;

  /// The [ConversationNode.id] of the virtual page created from this link.
  final String childNodeId;

  /// The [Message.id] that contains this link.
  final String messageId;

  /// Character offset (inclusive) of the trigger text in the raw message content.
  final int startOffset;

  /// Character offset (exclusive) of the trigger text in the raw message content.
  final int endOffset;

  const TextLink({
    required this.id,
    required this.triggerText,
    required this.childNodeId,
    required this.messageId,
    required this.startOffset,
    required this.endOffset,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'triggerText': triggerText,
        'childNodeId': childNodeId,
        'messageId': messageId,
        'startOffset': startOffset,
        'endOffset': endOffset,
      };

  factory TextLink.fromJson(Map<String, dynamic> json) => TextLink(
        id: json['id'] as String,
        triggerText: json['triggerText'] as String,
        childNodeId: json['childNodeId'] as String,
        messageId: json['messageId'] as String,
        startOffset: json['startOffset'] as int,
        endOffset: json['endOffset'] as int,
      );
}
