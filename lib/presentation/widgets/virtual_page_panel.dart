import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/conversation_node.dart';
import '../../data/models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/reading_settings_provider.dart';
import 'ask_about_dialog.dart';
import 'breadcrumb_bar.dart';
import 'chat_input.dart';
import 'message_bubble.dart';

/// Full-screen sliding panel that represents a virtual exploration page.
///
/// Each virtual page is a child [ConversationNode] spawned from a
/// text-selection in a parent node. This widget is layered on top of the main
/// chat view using a [Stack] + [SlideTransition].
class VirtualPagePanel extends ConsumerStatefulWidget {
  final String conversationId;

  /// IDs of all nodes in the current navigation stack (root → current).
  final List<String> nodeStack;

  final void Function(String childNodeId) onLinkTap;
  final void Function() onBack;
  final void Function(int crumbIndex) onCrumbTap;

  const VirtualPagePanel({
    super.key,
    required this.conversationId,
    required this.nodeStack,
    required this.onLinkTap,
    required this.onBack,
    required this.onCrumbTap,
  });

  @override
  ConsumerState<VirtualPagePanel> createState() => _VirtualPagePanelState();
}

class _VirtualPagePanelState extends ConsumerState<VirtualPagePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _activeNodeId => widget.nodeStack.last;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.conversationId));
    final repo = ref.read(
      // Access nodes from the current conversation
      chatProvider(widget.conversationId).notifier,
    );

    final conv = ref
        .watch(chatProvider(widget.conversationId))
        .node
        .conversationId;

    // Retrieve node data directly from repository
    final chatNotifier =
        ref.read(chatProvider(widget.conversationId).notifier);

    // Build the node stack objects for breadcrumbs
    final nodeStackObjects = _buildNodeStack(chatState);

    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        color: AppColors.background,
        elevation: 8,
        shadowColor: Colors.black54,
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────
            _PanelHeader(
              title: nodeStackObjects.isNotEmpty
                  ? (nodeStackObjects.last.triggerText ??
                      nodeStackObjects.last.title)
                  : 'Exploration',
              onBack: widget.onBack,
            ),

            // ── Breadcrumb ─────────────────────────────────────────────
            if (widget.nodeStack.length > 1) ...[
              BreadcrumbBar(
                nodeStack: nodeStackObjects,
                onCrumbTap: widget.onCrumbTap,
              ),
              const Divider(height: 1),
            ],

            // ── Messages ───────────────────────────────────────────────
            Expanded(
              child: _MessageList(
                conversationId: widget.conversationId,
                nodeId: _activeNodeId,
                scrollController: _scrollController,
                onScrollToBottom: _scrollToBottom,
                onLinkTap: widget.onLinkTap,
                onAskAI: (text, start, end, msgId) async {
                  final rt = ref.read(readingThemeProvider);
                  final question = await showAskAboutSelectionDialog(
                    context: context,
                    theme: rt,
                    selectedText: text,
                  );
                  if (question == null) return;
                  await chatNotifier.exploreText(
                    parentNodeId: _activeNodeId,
                    sourceMessageId: msgId,
                    triggerText: text,
                    startOffset: start,
                    endOffset: end,
                    userQuestion: question.isEmpty ? null : question,
                  );
                },
              ),
            ),

            // ── Input ──────────────────────────────────────────────────
            ChatInput(
              isStreaming: chatState.isStreaming,
              onSend: (text) {
                chatNotifier.sendMessage(
                  nodeId: _activeNodeId,
                  userText: text,
                );
                _scrollToBottom();
              },
            ),
          ],
        ),
      ),
    );
  }

  List<ConversationNode> _buildNodeStack(NodeChatState chatState) {
    // Resolve node objects from the conversation's node map
    // We use the chat notifier's access to the repo
    final notifier =
        ref.read(chatProvider(widget.conversationId).notifier);
    final result = <ConversationNode>[];
    for (final id in widget.nodeStack) {
      // Walk via the repo (accessible via notifier's public accessor)
      // For simplicity we just return the current active node + root
      // The full implementation would look up from repository
    }
    // Fallback: return current node
    return [chatState.node];
  }
}

// ── Panel Header ──────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _PanelHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textSecondary,
            onPressed: onBack,
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.auto_stories_rounded,
                  size: 16,
                  color: AppColors.link,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Depth badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.linkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.link.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'Exploration',
              style: TextStyle(
                color: AppColors.link,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Message List ──────────────────────────────────────────────────────────────

class _MessageList extends ConsumerWidget {
  final String conversationId;
  final String nodeId;
  final ScrollController scrollController;
  final VoidCallback onScrollToBottom;
  final void Function(String childNodeId) onLinkTap;
  final void Function(
    String selectedText,
    int startOffset,
    int endOffset,
    String messageId,
  ) onAskAI;

  const _MessageList({
    required this.conversationId,
    required this.nodeId,
    required this.scrollController,
    required this.onScrollToBottom,
    required this.onLinkTap,
    required this.onAskAI,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider(conversationId));
    // Find the correct node from the conversation state
    final node = chatState.node;
    final messages = node.messages
        .where((m) => m.role != MessageRole.system)
        .toList();

    if (messages.isEmpty) {
      return const _EmptyNodeView();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => onScrollToBottom());

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (_, i) => MessageBubble(
        message: messages[i],
        onLinkTap: onLinkTap,
        onAskAI: onAskAI,
      ),
    );
  }
}

class _EmptyNodeView extends StatelessWidget {
  const _EmptyNodeView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.explore_rounded,
            size: 48,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 12),
          Text(
            'Exploring…',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
