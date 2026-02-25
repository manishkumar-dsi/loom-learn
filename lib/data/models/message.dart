import 'text_link.dart';

enum MessageRole { user, assistant, system }

/// A single turn in a conversation node.
class Message {
  final String id;
  final MessageRole role;

  /// Raw text content. May contain markdown for assistant messages.
  final String content;

  final DateTime timestamp;

  /// Links embedded in this message's content (only on assistant messages).
  final List<TextLink> links;

  /// True while the assistant is still streaming a response.
  final bool isStreaming;

  const Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.links = const [],
    this.isStreaming = false,
  });

  Message copyWith({
    String? content,
    List<TextLink>? links,
    bool? isStreaming,
  }) {
    return Message(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      links: links ?? this.links,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'links': links.map((l) => l.toJson()).toList(),
        'isStreaming': false, // never persist a streaming state
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        role: MessageRole.values.byName(json['role'] as String),
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        links: (json['links'] as List<dynamic>?)
                ?.map((e) => TextLink.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        isStreaming: false,
      );
}
