enum HighlightColor {
  yellow,
  green,
  pink,
  aqua,
  orange;

  String get label => switch (this) {
        yellow => 'Yellow',
        green => 'Green',
        pink => 'Pink',
        aqua => 'Aqua',
        orange => 'Orange',
      };
}

/// Represents a user-created highlight within assistant message content.
class TextHighlight {
  final String id;
  final String conversationId;
  final String nodeId;
  final String messageId;
  final String selectedText;
  final int startOffset;
  final int endOffset;
  final HighlightColor color;
  final DateTime createdAt;

  const TextHighlight({
    required this.id,
    required this.conversationId,
    required this.nodeId,
    required this.messageId,
    required this.selectedText,
    required this.startOffset,
    required this.endOffset,
    required this.color,
    required this.createdAt,
  });

  TextHighlight copyWith({
    HighlightColor? color,
  }) {
    return TextHighlight(
      id: id,
      conversationId: conversationId,
      nodeId: nodeId,
      messageId: messageId,
      selectedText: selectedText,
      startOffset: startOffset,
      endOffset: endOffset,
      color: color ?? this.color,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'nodeId': nodeId,
        'messageId': messageId,
        'selectedText': selectedText,
        'startOffset': startOffset,
        'endOffset': endOffset,
        'color': color.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TextHighlight.fromJson(Map<String, dynamic> json) => TextHighlight(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        nodeId: json['nodeId'] as String,
        messageId: json['messageId'] as String,
        selectedText: json['selectedText'] as String,
        startOffset: json['startOffset'] as int,
        endOffset: json['endOffset'] as int,
        color: HighlightColor.values.byName(json['color'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
