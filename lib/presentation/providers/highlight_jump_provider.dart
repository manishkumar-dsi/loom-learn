import 'package:flutter_riverpod/flutter_riverpod.dart';

class HighlightJumpTarget {
  final String conversationId;
  final String nodeId;
  final String messageId;
  final String highlightId;

  const HighlightJumpTarget({
    required this.conversationId,
    required this.nodeId,
    required this.messageId,
    required this.highlightId,
  });
}

final highlightJumpProvider = StateProvider<HighlightJumpTarget?>((ref) => null);
