import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/openai_service.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/conversation_node.dart';
import '../../data/models/message.dart';
import '../../data/models/text_highlight.dart';
import '../../data/repositories/conversation_repository.dart';
import 'api_key_provider.dart';
import 'conversations_provider.dart';

// ── Per-node chat state ────────────────────────────────────────────────────

class NodeChatState {
  final ConversationNode node;
  final bool isStreaming;
  final String? error;

  /// Virtual page navigation stack for this view. First element is always the
  /// root node; each exploration pushes a child node ID onto the stack.
  final List<String> nodeStack;

  const NodeChatState({
    required this.node,
    this.isStreaming = false,
    this.error,
    required this.nodeStack,
  });

  NodeChatState copyWith({
    ConversationNode? node,
    bool? isStreaming,
    String? error,
    List<String>? nodeStack,
  }) {
    return NodeChatState(
      node: node ?? this.node,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error,
      nodeStack: nodeStack ?? this.nodeStack,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<NodeChatState> {
  final ConversationRepository _repo;
  final OpenAIService _openAI;
  final String conversationId;
  final Ref _ref;

  ChatNotifier({
    required ConversationRepository repo,
    required OpenAIService openAI,
    required this.conversationId,
    required ConversationNode rootNode,
    required Ref ref,
  })  : _repo = repo,
        _openAI = openAI,
        _ref = ref,
        super(NodeChatState(node: rootNode, nodeStack: [rootNode.id]));

  // ── Navigation ─────────────────────────────────────────────────────────

  /// Returns the node currently shown in the active panel.
  ConversationNode get activeNode {
    final nodeId = state.nodeStack.last;
    final conv = _repo.getConversation(conversationId);
    return conv?.nodes[nodeId] ?? state.node;
  }

  void pushVirtualPage(String nodeId) {
    state = state.copyWith(nodeStack: [...state.nodeStack, nodeId]);
    _refreshActiveNode();
  }

  void popVirtualPage() {
    if (state.nodeStack.length <= 1) return;
    state = state.copyWith(
      nodeStack: state.nodeStack.sublist(0, state.nodeStack.length - 1),
    );
    _refreshActiveNode();
  }

  void popToRoot() {
    state = state.copyWith(nodeStack: [state.nodeStack.first]);
    _refreshActiveNode();
  }

  void _refreshActiveNode() {
    final conv = _repo.getConversation(conversationId);
    if (conv == null) return;
    final nodeId = state.nodeStack.last;
    final node = conv.nodes[nodeId];
    if (node != null) state = state.copyWith(node: node);
  }

  // ── Sending messages ────────────────────────────────────────────────────

  /// Sends [userText] in the context of [nodeId] and streams the AI reply.
  Future<void> sendMessage({
    required String nodeId,
    required String userText,
  }) async {
    final settings = _ref.read(settingsProvider);
    if (!settings.hasApiKey) {
      state = state.copyWith(
          error: 'No API key set. Add it in Settings.');
      return;
    }

    final conv = _repo.getConversation(conversationId);
    if (conv == null) return;

    final node = conv.nodes[nodeId];
    if (node == null) return;

    // Append user message
    final userMsg = Message(
      id: generateId(),
      role: MessageRole.user,
      content: userText.trim(),
      timestamp: DateTime.now(),
    );
    await _repo.addMessageToNode(
      conversationId: conversationId,
      nodeId: nodeId,
      message: userMsg,
    );

    // Create placeholder streaming message
    final assistantMsgId = generateId();
    final assistantMsg = Message(
      id: assistantMsgId,
      role: MessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    await _repo.addMessageToNode(
      conversationId: conversationId,
      nodeId: nodeId,
      message: assistantMsg,
    );

    state = state.copyWith(isStreaming: true, error: null);
    _refreshActiveNode();

    // Auto-title the root conversation from first user message
    if (node.isRoot && node.messages.isEmpty) {
      final title = _truncate(userText, 60);
      await _repo.renameConversation(conversationId, title);
      _ref.read(conversationsProvider.notifier).refresh();
    }

    // Build context from fresh repo state so the current user message is included
    final convAfter = _repo.getConversation(conversationId);
    if (convAfter == null) return;
    final contextMessages = _buildContext(convAfter.nodes, nodeId, settings.model);

    // Stream response
    final buffer = StringBuffer();
    try {
      await for (final delta in _openAI.streamChat(
        apiKey: settings.apiKey!,
        model: settings.model,
        messages: contextMessages,
      )) {
        buffer.write(delta);
        final partial = assistantMsg.copyWith(content: buffer.toString());
        await _repo.updateMessageInNode(
          conversationId: conversationId,
          nodeId: nodeId,
          message: partial,
        );
        _refreshActiveNode();
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }

    // Finalise message (clear streaming flag)
    final finalMsg = assistantMsg.copyWith(
      content: buffer.toString(),
      isStreaming: false,
    );
    await _repo.updateMessageInNode(
      conversationId: conversationId,
      nodeId: nodeId,
      message: finalMsg,
    );

    state = state.copyWith(isStreaming: false);
    _refreshActiveNode();
    _ref.read(conversationsProvider.notifier).refresh();
  }

  /// Creates a virtual page from a text selection and sends the user's question
  /// (or a default exploration prompt if [userQuestion] is null/empty).
  /// The selected text becomes a link to this exploration after the response.
  Future<String?> exploreText({
    required String parentNodeId,
    required String sourceMessageId,
    required String triggerText,
    required int startOffset,
    required int endOffset,
    String? userQuestion,
  }) async {
    final settings = _ref.read(settingsProvider);
    if (!settings.hasApiKey) {
      state = state.copyWith(error: 'No API key set.');
      return null;
    }

    final (:childNode, :link) = await _repo.createVirtualPage(
      conversationId: conversationId,
      parentNodeId: parentNodeId,
      sourceMessageId: sourceMessageId,
      triggerText: triggerText,
      startOffset: startOffset,
      endOffset: endOffset,
    );

    // Push the new page onto the stack
    pushVirtualPage(childNode.id);

    final prompt = (userQuestion != null && userQuestion.trim().isNotEmpty)
        ? userQuestion.trim()
        : _explorationPrompt(triggerText);
    await sendMessage(
      nodeId: childNode.id,
      userText: prompt,
    );

    return childNode.id;
  }

  Future<void> addHighlight({
    required String nodeId,
    required String messageId,
    required String selectedText,
    required int startOffset,
    required int endOffset,
    required HighlightColor color,
  }) async {
    try {
      await _repo.addHighlightToMessage(
        conversationId: conversationId,
        nodeId: nodeId,
        messageId: messageId,
        selectedText: selectedText,
        startOffset: startOffset,
        endOffset: endOffset,
        color: color,
      );
      _refreshActiveNode();
      _ref.read(conversationsProvider.notifier).refresh();
      state = state.copyWith(error: null);
    } catch (e) {
      state = state.copyWith(error: 'Failed to add highlight: $e');
    }
  }

  Future<void> removeHighlight({
    required String nodeId,
    required String messageId,
    required String highlightId,
  }) async {
    await _repo.removeHighlightFromMessage(
      conversationId: conversationId,
      nodeId: nodeId,
      messageId: messageId,
      highlightId: highlightId,
    );
    _refreshActiveNode();
    _ref.read(conversationsProvider.notifier).refresh();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Builds the messages list to send to the API, including a system prompt
  /// and (for virtual pages) the parent conversation context.
  List<Message> _buildContext(
    Map<String, ConversationNode> nodes,
    String nodeId,
    String model,
  ) {
    final node = nodes[nodeId]!;
    final messages = <Message>[];

    // Collect ancestor context (shallow — most recent N messages from parent)
    if (node.parentNodeId != null) {
      final parent = nodes[node.parentNodeId!];
      if (parent != null) {
        final parentMessages = parent.messages
            .where((m) => !m.isStreaming)
            .take(10)
            .toList();
        messages.add(Message(
          id: generateId(),
          role: MessageRole.system,
          content:
              'You are exploring the topic "${node.triggerText}" which was '
              'highlighted from a conversation. The parent conversation context '
              'is provided below for reference. Be educational and thorough.\n\n'
              'Parent context summary:\n'
              '${parentMessages.map((m) => '${m.role.name}: ${m.content}').join('\n')}',
          timestamp: DateTime.now(),
        ));
      }
    } else {
      messages.add(Message(
        id: generateId(),
        role: MessageRole.system,
        content:
            'You are a knowledgeable assistant. Provide clear, well-structured, '
            'and thorough responses using markdown where appropriate.',
        timestamp: DateTime.now(),
      ));
    }

    // Add current node messages (excluding the streaming placeholder)
    messages.addAll(
      node.messages.where((m) => !m.isStreaming).toList(),
    );

    return messages;
  }

  static String _explorationPrompt(String trigger) =>
      'Explain "$trigger" in depth. Use markdown formatting, include '
      'relevant examples, and highlight key sub-concepts.';

  static String _truncate(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max - 1)}…';
}

// ── Family provider ────────────────────────────────────────────────────────

/// One [ChatNotifier] per active conversation.
final chatProvider = StateNotifierProvider.family<ChatNotifier, NodeChatState,
    String>((ref, conversationId) {
  final repo = ref.watch(conversationRepositoryProvider);
  final conv = repo.getConversation(conversationId);
  if (conv == null) throw ArgumentError('No conversation: $conversationId');

  return ChatNotifier(
    repo: repo,
    openAI: OpenAIService(),
    conversationId: conversationId,
    rootNode: conv.rootNode,
    ref: ref,
  );
});
