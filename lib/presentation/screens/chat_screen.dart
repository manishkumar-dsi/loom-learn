import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/conversations_provider.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';
import '../widgets/virtual_page_panel.dart';

/// The main chat view for a single [Conversation].
///
/// Renders the root node's messages and layers [VirtualPagePanel]s on top
/// via a [Stack] as the user explores linked text.
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.conversationId));
    final chatNotifier =
        ref.read(chatProvider(widget.conversationId).notifier);

    final rootNodeId = chatState.nodeStack.first;
    final conv = ref
        .read(conversationsProvider.notifier)
        .getConversation(widget.conversationId);

    final rootNode = conv?.nodes[rootNodeId];
    final messages = rootNode?.messages
            .where((m) => m.role != MessageRole.system)
            .toList() ??
        [];

    return Stack(
      children: [
        // ── Root chat ────────────────────────────────────────────────────
        Column(
          children: [
            // Header
            _ChatHeader(
              title: conv?.title ?? 'New Chat',
              conversationId: widget.conversationId,
            ),
            const Divider(height: 1),

            // Error banner
            if (chatState.error != null) _ErrorBanner(chatState.error!),

            // Messages
            Expanded(
              child: messages.isEmpty
                  ? _WelcomeView(
                      onSend: (text) {
                        chatNotifier.sendMessage(
                          nodeId: rootNodeId,
                          userText: text,
                        );
                      },
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (_, i) => MessageBubble(
                        message: messages[i],
                        onLinkTap: (childNodeId) {
                          chatNotifier.pushVirtualPage(childNodeId);
                        },
                        onAskAI: (text, start, end, msgId) {
                          chatNotifier.exploreText(
                            parentNodeId: rootNodeId,
                            sourceMessageId: msgId,
                            triggerText: text,
                            startOffset: start,
                            endOffset: end,
                          );
                        },
                      ),
                    ),
            ),

            // Input (only shown when no virtual page is open at root)
            if (chatState.nodeStack.length == 1)
              ChatInput(
                isStreaming: chatState.isStreaming,
                onSend: (text) {
                  chatNotifier.sendMessage(
                    nodeId: rootNodeId,
                    userText: text,
                  );
                  _scrollToBottom();
                },
              ),
          ],
        ),

        // ── Virtual page layers ─────────────────────────────────────────
        if (chatState.nodeStack.length > 1) ...[
          // Dimmed backdrop
          GestureDetector(
            onTap: chatNotifier.popVirtualPage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),

          // The virtual page panel
          Positioned.fill(
            child: VirtualPagePanel(
              conversationId: widget.conversationId,
              nodeStack: chatState.nodeStack,
              onBack: chatNotifier.popVirtualPage,
              onCrumbTap: (index) {
                // Pop back to that crumb level
                final target = chatState.nodeStack[index];
                final targetIndex = chatState.nodeStack.indexOf(target);
                for (var i = chatState.nodeStack.length - 1;
                    i > targetIndex;
                    i--) {
                  chatNotifier.popVirtualPage();
                }
              },
              onLinkTap: (childNodeId) {
                chatNotifier.pushVirtualPage(childNodeId);
              },
            ),
          ),
        ],
      ],
    );
  }
}

// ── Chat header ───────────────────────────────────────────────────────────────

class _ChatHeader extends ConsumerWidget {
  final String title;
  final String conversationId;

  const _ChatHeader({required this.title, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.surface,
      child: Row(
        children: [
          // Mobile: hamburger to open drawer
          if (MediaQuery.of(context).size.width < 700)
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 20),
              color: AppColors.textSecondary,
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),

          Expanded(
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

          // Node graph indicator
          _GraphBadge(conversationId: conversationId),
        ],
      ),
    );
  }
}

class _GraphBadge extends ConsumerWidget {
  final String conversationId;

  const _GraphBadge({required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conv = ref
        .watch(conversationsProvider)
        .conversations
        .where((c) => c.id == conversationId)
        .firstOrNull;

    final nodeCount = conv?.nodes.length ?? 1;
    if (nodeCount <= 1) return const SizedBox.shrink();

    return Tooltip(
      message: '$nodeCount exploration pages in this chat',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.linkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.link.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_tree_outlined,
              size: 12,
              color: AppColors.link,
            ),
            const SizedBox(width: 4),
            Text(
              '$nodeCount',
              style: const TextStyle(
                color: AppColors.link,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Welcome / empty state ─────────────────────────────────────────────────────

class _WelcomeView extends StatelessWidget {
  final void Function(String) onSend;

  const _WelcomeView({required this.onSend});

  static const _suggestions = [
    'Explain quantum entanglement',
    'How does the internet work?',
    'What is machine learning?',
    'Summarise the history of Rome',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo mark
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'What would you like to explore?',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask anything. Select any word or phrase in responses\nto dive deeper with linked exploration pages.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestions
                  .map((s) => _SuggestionChip(text: s, onTap: () => onSend(s)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.errorSurface,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
