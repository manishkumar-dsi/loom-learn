import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/text_highlight.dart';
import '../../data/repositories/conversation_repository.dart';
import 'conversations_provider.dart';

class HighlightListItem {
  final TextHighlight highlight;
  final String conversationId;
  final String conversationTitle;
  final String nodeId;
  final String messageId;
  final String messagePreview;

  const HighlightListItem({
    required this.highlight,
    required this.conversationId,
    required this.conversationTitle,
    required this.nodeId,
    required this.messageId,
    required this.messagePreview,
  });
}

List<HighlightListItem> _flattenHighlights(
  ConversationRepository repo, {
  String? conversationId,
}) {
  final source = conversationId == null
      ? repo.conversations
      : repo.conversations.where((c) => c.id == conversationId);
  final items = <HighlightListItem>[];

  for (final conv in source) {
    for (final nodeEntry in conv.nodes.entries) {
      final nodeId = nodeEntry.key;
      final node = nodeEntry.value;
      for (final msg in node.messages) {
        if (msg.highlights.isEmpty) continue;
        for (final h in msg.highlights) {
          items.add(
            HighlightListItem(
              highlight: h,
              conversationId: conv.id,
              conversationTitle: conv.title,
              nodeId: nodeId,
              messageId: msg.id,
              messagePreview: msg.content,
            ),
          );
        }
      }
    }
  }
  items.sort((a, b) => b.highlight.createdAt.compareTo(a.highlight.createdAt));
  return items;
}

final globalHighlightsProvider = Provider<List<HighlightListItem>>((ref) {
  final repo = ref.watch(conversationRepositoryProvider);
  return _flattenHighlights(repo);
});

final conversationHighlightsProvider =
    Provider.family<List<HighlightListItem>, String>((ref, conversationId) {
  final repo = ref.watch(conversationRepositoryProvider);
  return _flattenHighlights(repo, conversationId: conversationId);
});
