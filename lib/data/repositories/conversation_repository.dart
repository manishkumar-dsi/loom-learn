import '../../core/services/storage_service.dart';
import '../../core/utils/id_generator.dart';
import '../models/conversation.dart';
import '../models/conversation_node.dart';
import '../models/message.dart';
import '../models/text_link.dart';

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

  Future<Conversation> createConversation({String title = 'New Chat'}) async {
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
    await _storage.saveConversations(_conversations);
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
      return m.copyWith(links: [...m.links, link]);
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
}
