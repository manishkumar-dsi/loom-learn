import 'package:flutter_test/flutter_test.dart';
import 'package:loom_learn/data/models/conversation.dart';
import 'package:loom_learn/data/models/conversation_node.dart';
import 'package:loom_learn/data/models/message.dart';
import 'package:loom_learn/data/models/text_link.dart';

void main() {
  group('TextLink', () {
    test('serialises and deserialises correctly', () {
      const link = TextLink(
        id: 'l1',
        triggerText: 'quantum',
        childNodeId: 'node2',
        messageId: 'msg1',
        startOffset: 5,
        endOffset: 12,
      );
      final json = link.toJson();
      final restored = TextLink.fromJson(json);

      expect(restored.id, link.id);
      expect(restored.triggerText, link.triggerText);
      expect(restored.startOffset, link.startOffset);
      expect(restored.endOffset, link.endOffset);
    });
  });

  group('Message', () {
    test('serialises and deserialises correctly', () {
      final msg = Message(
        id: 'm1',
        role: MessageRole.assistant,
        content: 'Hello world',
        timestamp: DateTime(2026, 1, 1),
        links: [
          const TextLink(
            id: 'l1',
            triggerText: 'world',
            childNodeId: 'n2',
            messageId: 'm1',
            startOffset: 6,
            endOffset: 11,
          ),
        ],
      );

      final json = msg.toJson();
      final restored = Message.fromJson(json);

      expect(restored.id, msg.id);
      expect(restored.role, MessageRole.assistant);
      expect(restored.links, hasLength(1));
      expect(restored.links.first.triggerText, 'world');
    });

    test('copyWith preserves unspecified fields', () {
      final msg = Message(
        id: 'm1',
        role: MessageRole.user,
        content: 'original',
        timestamp: DateTime.now(),
      );

      final updated = msg.copyWith(content: 'updated', isStreaming: true);
      expect(updated.content, 'updated');
      expect(updated.isStreaming, true);
      expect(updated.id, msg.id);
      expect(updated.role, msg.role);
    });
  });

  group('ConversationNode', () {
    test('isRoot returns true only for root nodes', () {
      final root = ConversationNode(
        id: 'root',
        conversationId: 'c1',
        title: 'Main chat',
        createdAt: DateTime.now(),
      );
      final child = ConversationNode(
        id: 'child',
        conversationId: 'c1',
        parentNodeId: 'root',
        triggerText: 'hello',
        title: 'hello',
        createdAt: DateTime.now(),
      );

      expect(root.isRoot, isTrue);
      expect(child.isRoot, isFalse);
    });

    test('serialises and deserialises', () {
      final node = ConversationNode(
        id: 'n1',
        conversationId: 'c1',
        title: 'Test',
        createdAt: DateTime(2026, 2, 1),
      );

      final json = node.toJson();
      final restored = ConversationNode.fromJson(json);

      expect(restored.id, node.id);
      expect(restored.title, node.title);
      expect(restored.isRoot, isTrue);
    });
  });

  group('Conversation', () {
    test('rootNode returns the correct node', () {
      final node = ConversationNode(
        id: 'root',
        conversationId: 'c1',
        title: 'Main',
        createdAt: DateTime.now(),
      );
      final conv = Conversation(
        id: 'c1',
        title: 'Chat 1',
        rootNodeId: 'root',
        nodes: {'root': node},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(conv.rootNode.id, 'root');
    });
  });
}
