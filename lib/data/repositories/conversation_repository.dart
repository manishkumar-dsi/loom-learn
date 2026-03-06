import '../../core/services/storage_service.dart';
import '../../core/utils/id_generator.dart';
import '../models/conversation.dart';
import '../models/conversation_node.dart';
import '../models/message.dart';
import '../models/text_link.dart';
import '../models/text_highlight.dart';

/// Manages the full lifecycle of [Conversation]s and their [ConversationNode]s.
///
/// This repository is the single source of truth for conversation data. All
/// mutations go through here and are immediately persisted via [StorageService].
class ConversationRepository {
  final StorageService _storage;

  ConversationRepository(this._storage);

  List<Conversation> _conversations = [];

  // ── Initialisation ─────────────────────────────────────────────────────────

  void init() {
    _conversations = _storage.loadConversations();
  }

  List<Conversation> get conversations =>
      List.unmodifiable(_conversations);

  // ── Conversation CRUD ──────────────────────────────────────────────────────

  /// Creates a new conversation in memory and returns it. Call
  /// [persistConversations] to save to storage (e.g. after showing UI).
  Conversation createConversationSync({String title = 'New Chat'}) {
    final conversationId = generateId();
    final rootNodeId = generateId();
    final now = DateTime.now();

    final rootNode = ConversationNode(
      id: rootNodeId,
      conversationId: conversationId,
      title: title,
      createdAt: now,
    );

    final conversation = Conversation(
      id: conversationId,
      title: title,
      rootNodeId: rootNodeId,
      nodes: {rootNodeId: rootNode},
      createdAt: now,
      updatedAt: now,
    );

    _conversations = [conversation, ..._conversations];
    return conversation;
  }

  /// Persists current [conversations] to storage. Safe to call fire-and-forget.
  Future<void> persistConversations() =>
      _storage.saveConversations(_conversations);

  Future<Conversation> createConversation({String title = 'New Chat'}) async {
    final conversation = createConversationSync(title: title);
    await persistConversations();
    return conversation;
  }

  Conversation? getConversation(String id) {
    try {
      return _conversations.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Conversation> updateConversation(Conversation updated) async {
    _conversations = _conversations
        .map((c) => c.id == updated.id ? updated : c)
        .toList();
    await _storage.saveConversations(_conversations);
    return updated;
  }

  Future<void> deleteConversation(String id) async {
    _conversations = _conversations.where((c) => c.id != id).toList();
    await _storage.saveConversations(_conversations);
  }

  Future<Conversation> renameConversation(String id, String title) async {
    final conv = getConversation(id);
    if (conv == null) throw StateError('Conversation $id not found');
    return updateConversation(conv.copyWith(title: title));
  }

  // ── Node & Message operations ──────────────────────────────────────────────

  Future<ConversationNode> addMessageToNode({
    required String conversationId,
    required String nodeId,
    required Message message,
  }) async {
    final conv = getConversation(conversationId);
    if (conv == null) throw StateError('Conversation $conversationId not found');

    final node = conv.nodes[nodeId];
    if (node == null) throw StateError('Node $nodeId not found');

    final updatedNode = node.copyWith(
      messages: [...node.messages, message],
    );
    final updatedNodes = Map<String, ConversationNode>.from(conv.nodes)
      ..[nodeId] = updatedNode;

    await updateConversation(
      conv.copyWith(nodes: updatedNodes, updatedAt: DateTime.now()),
    );
    return updatedNode;
  }

  Future<ConversationNode> updateMessageInNode({
    required String conversationId,
    required String nodeId,
    required Message message,
  }) async {
    final conv = getConversation(conversationId);
    if (conv == null) throw StateError('Conversation $conversationId not found');

    final node = conv.nodes[nodeId];
    if (node == null) throw StateError('Node $nodeId not found');

    final updatedMessages =
        node.messages.map((m) => m.id == message.id ? message : m).toList();

    final updatedNode = node.copyWith(messages: updatedMessages);
    final updatedNodes = Map<String, ConversationNode>.from(conv.nodes)
      ..[nodeId] = updatedNode;

    await updateConversation(
      conv.copyWith(nodes: updatedNodes, updatedAt: DateTime.now()),
    );
    return updatedNode;
  }

  Future<Message> addHighlightToMessage({
    required String conversationId,
    required String nodeId,
    required String messageId,
    required String selectedText,
    required int startOffset,
    required int endOffset,
    required HighlightColor color,
  }) async {
    final conv = getConversation(conversationId);
    if (conv == null) throw StateError('Conversation $conversationId not found');
    final node = conv.nodes[nodeId];
    if (node == null) throw StateError('Node $nodeId not found');

    Message? target;
    final updatedMessages = node.messages.map((m) {
      if (m.id != messageId) return m;
      final normalized = selectedText.trim();
      if (normalized.isEmpty) return m;
      target = m;

      final duplicate = m.highlights.any((h) =>
          h.startOffset == startOffset &&
          h.endOffset == endOffset &&
          h.selectedText == normalized);
      if (duplicate) return m;

      final highlight = TextHighlight(
        id: generateId(),
        conversationId: conversationId,
        nodeId: nodeId,
        messageId: messageId,
        selectedText: normalized,
        startOffset: startOffset,
        endOffset: endOffset,
        color: color,
        createdAt: DateTime.now(),
      );
      final contentWithHighlight = _highlightSelectedTextInPlace(
        content: m.content,
        selectedText: normalized,
        highlight: highlight,
        startOffset: startOffset,
        endOffset: endOffset,
      );
      final updated = m.copyWith(
        highlights: [...m.highlights, highlight],
        content: contentWithHighlight,
      );
      target = updated;
      return updated;
    }).toList();

    if (target == null) throw StateError('Message $messageId not found');

    final updatedNode = node.copyWith(messages: updatedMessages);
    final updatedNodes = Map<String, ConversationNode>.from(conv.nodes)
      ..[nodeId] = updatedNode;
    await updateConversation(
      conv.copyWith(nodes: updatedNodes, updatedAt: DateTime.now()),
    );
    return target!;
  }

  Future<void> removeHighlightFromMessage({
    required String conversationId,
    required String nodeId,
    required String messageId,
    required String highlightId,
  }) async {
    final conv = getConversation(conversationId);
    if (conv == null) throw StateError('Conversation $conversationId not found');
    final node = conv.nodes[nodeId];
    if (node == null) throw StateError('Node $nodeId not found');

    final updatedMessages = node.messages.map((m) {
      if (m.id != messageId) return m;
      return m.copyWith(
        highlights: m.highlights.where((h) => h.id != highlightId).toList(),
      );
    }).toList();

    final updatedNode = node.copyWith(messages: updatedMessages);
    final updatedNodes = Map<String, ConversationNode>.from(conv.nodes)
      ..[nodeId] = updatedNode;
    await updateConversation(
      conv.copyWith(nodes: updatedNodes, updatedAt: DateTime.now()),
    );
  }

  List<TextHighlight> getHighlightsForConversation(String conversationId) {
    final conv = getConversation(conversationId);
    if (conv == null) return const [];
    final items = <TextHighlight>[];
    for (final node in conv.nodes.values) {
      for (final msg in node.messages) {
        items.addAll(msg.highlights);
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  List<TextHighlight> getAllHighlights() {
    final items = <TextHighlight>[];
    for (final conv in _conversations) {
      for (final node in conv.nodes.values) {
        for (final msg in node.messages) {
          items.addAll(msg.highlights);
        }
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// Creates a child [ConversationNode] (virtual page) from a text selection.
  ///
  /// Also attaches a [TextLink] to the [sourceMessageId] in the source node
  /// so that the triggering text is rendered as a navigable link.
  Future<({ConversationNode childNode, TextLink link})> createVirtualPage({
    required String conversationId,
    required String parentNodeId,
    required String sourceMessageId,
    required String triggerText,
    required int startOffset,
    required int endOffset,
  }) async {
    final conv = getConversation(conversationId);
    if (conv == null) throw StateError('Conversation $conversationId not found');

    final childNodeId = generateId();
    final linkId = generateId();
    final now = DateTime.now();

    // Build the child node
    final childNode = ConversationNode(
      id: childNodeId,
      conversationId: conversationId,
      parentNodeId: parentNodeId,
      triggerText: triggerText,
      title: _titleFromTrigger(triggerText),
      createdAt: now,
    );

    // Build the link that embeds in the parent message
    final link = TextLink(
      id: linkId,
      triggerText: triggerText,
      childNodeId: childNodeId,
      messageId: sourceMessageId,
      startOffset: startOffset,
      endOffset: endOffset,
    );

    // Attach link to source message in parent node
    final parentNode = conv.nodes[parentNodeId]!;
    final updatedMessages = parentNode.messages.map((m) {
      if (m.id != sourceMessageId) return m;
      final contentWithLink = _linkSelectedTextInPlace(
        content: m.content,
        triggerText: triggerText,
        childNodeId: childNodeId,
        startOffset: startOffset,
        endOffset: endOffset,
      );
      return m.copyWith(
        links: [...m.links, link],
        content: contentWithLink,
      );
    }).toList();

    final updatedParent = parentNode.copyWith(messages: updatedMessages);
    final updatedNodes = Map<String, ConversationNode>.from(conv.nodes)
      ..[parentNodeId] = updatedParent
      ..[childNodeId] = childNode;

    await updateConversation(
      conv.copyWith(nodes: updatedNodes, updatedAt: now),
    );

    return (childNode: childNode, link: link);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _titleFromTrigger(String trigger) {
    const maxLen = 50;
    return trigger.length <= maxLen
        ? trigger
        : '${trigger.substring(0, maxLen - 1)}…';
  }

  static String _escapeMarkdownLinkLabel(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)')
        .replaceAll('\n', ' ');
  }

  static String _linkSelectedTextInPlace({
    required String content,
    required String triggerText,
    required String childNodeId,
    required int startOffset,
    required int endOffset,
  }) {
    final trimmed = triggerText.trim();
    if (trimmed.isEmpty) return content;
    if (content.contains('(loom://explore/$childNodeId)')) return content;

    final mdLabel = _escapeMarkdownLinkLabel(trimmed);
    final mdLink = '[$mdLabel](loom://explore/$childNodeId)';

    // 1) Best effort: use provided offsets if they match the source content.
    if (startOffset >= 0 &&
        endOffset > startOffset &&
        endOffset <= content.length &&
        content.substring(startOffset, endOffset) == triggerText) {
      return content.replaceRange(startOffset, endOffset, mdLink);
    }

    // 2) Fallback: replace first non-linked occurrence in content.
    final linkedRanges = _markdownLinkRanges(content);
    var idx = content.indexOf(trimmed);
    while (idx != -1) {
      final inLinkedRange = linkedRanges
          .any((r) => idx >= r.$1 && idx < r.$2);
      if (!inLinkedRange) {
        return content.replaceRange(idx, idx + trimmed.length, mdLink);
      }
      idx = content.indexOf(trimmed, idx + trimmed.length);
    }

    // 3) Last fallback: leave content unchanged (chips still provide navigation).
    return content;
  }

  static List<(int, int)> _markdownLinkRanges(String content) {
    final ranges = <(int, int)>[];
    final regex = RegExp(r'\[[^\]]+\]\([^)]+\)');
    for (final m in regex.allMatches(content)) {
      ranges.add((m.start, m.end));
    }
    return ranges;
  }

  static String _highlightSelectedTextInPlace({
    required String content,
    required String selectedText,
    required TextHighlight highlight,
    required int startOffset,
    required int endOffset,
  }) {
    final text = selectedText.trim();
    if (text.isEmpty) return content;
    final markerStart = '[[hl:${highlight.color.name}:${highlight.id}]]';
    const markerEnd = '[[/hl]]';
    final wrapped = '$markerStart$text$markerEnd';

    // Prefer exact offsets when they point to the selected text.
    if (startOffset >= 0 &&
        endOffset > startOffset &&
        endOffset <= content.length &&
        content.substring(startOffset, endOffset) == selectedText) {
      return content.replaceRange(startOffset, endOffset, wrapped);
    }

    // Fallback: replace first plain occurrence outside markdown links/highlights.
    final linkedRanges = _markdownLinkRanges(content);
    final highlightedRanges = _highlightRanges(content);
    var idx = content.indexOf(text);
    while (idx != -1) {
      final inLinkedRange = linkedRanges.any((r) => idx >= r.$1 && idx < r.$2);
      final inHighlightRange = highlightedRanges
          .any((r) => idx >= r.$1 && idx < r.$2);
      if (!inLinkedRange && !inHighlightRange) {
        return content.replaceRange(idx, idx + text.length, wrapped);
      }
      idx = content.indexOf(text, idx + text.length);
    }
    return content;
  }

  static List<(int, int)> _highlightRanges(String content) {
    final ranges = <(int, int)>[];
    final regex = RegExp(r'\[\[hl:[^\]]+\]\].*?\[\[/hl\]\]');
    for (final m in regex.allMatches(content)) {
      ranges.add((m.start, m.end));
    }
    return ranges;
  }
}
