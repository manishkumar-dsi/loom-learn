import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/reading_settings_provider.dart';
import '../widgets/exploration_bottom_sheet.dart';
import '../widgets/reading_layout/reading_message_view.dart';
import '../widgets/reading_toolbar_sheet.dart';
import '../widgets/theme_aware_chat_input.dart';

/// Main chat view for a single [Conversation].
///
/// Redesigned with Kindle-inspired UX:
/// - Reading layout replaces chat bubbles (prose-style, full-width responses)
/// - "Aa" button in the header opens the typography settings panel
/// - Virtual page explorations appear as a Kindle X-Ray-style bottom sheet
///   instead of a full-screen overlay
/// - Dynamic theme applied from [readingThemeProvider]
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
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
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
    final rt = ref.watch(readingThemeProvider);
    final settings = ref.watch(readingSettingsProvider);
    final chatState = ref.watch(chatProvider(widget.conversationId));
    final chatNotifier =
        ref.read(chatProvider(widget.conversationId).notifier);

    final rootNodeId = chatState.nodeStack.first;
    final conv = ref
        .read(conversationsProvider.notifier)
        .getConversation(widget.conversationId);

    final rootNode = conv?.nodes[rootNodeId];
    final messages = rootNode?.messages ?? [];
    final hasMessages =
        messages.any((m) => m.role != MessageRole.system);

    // The bottom sheet exploration is open when nodeStack has depth > 1
    final explorationOpen = chatState.nodeStack.length > 1;

    return Container(
      color: rt.background,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          _ChatHeader(
            title: conv?.title ?? 'New Chat',
            conversationId: widget.conversationId,
            theme: rt,
          ),

          Divider(height: 1, color: rt.border),

          // ── Error banner ─────────────────────────────────────────────────
          if (chatState.error != null)
            _ErrorBanner(message: chatState.error!, theme: rt),

          // ── Messages + exploration sheet ──────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Root messages
                hasMessages
                    ? SingleChildScrollView(
                        controller: _scrollController,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.of(context).size.height,
                            maxWidth: 860,
                          ),
                          child: ReadingMessageView(
                            messages: messages,
                            settings: settings,
                            theme: rt,
                            onLinkTap: chatNotifier.pushVirtualPage,
                            onAskAI: (text, start, end, msgId) {
                              chatNotifier.exploreText(
                                parentNodeId: rootNodeId,
                                sourceMessageId: msgId,
                                triggerText: text,
                                startOffset: start,
                                endOffset: end,
                              );
                              _scrollToBottom();
                            },
                          ),
                        ),
                      )
                    : _WelcomeView(
                        theme: rt,
                        onSend: (text) {
                          chatNotifier.sendMessage(
                            nodeId: rootNodeId,
                            userText: text,
                          );
                        },
                      ),

                // Exploration bottom sheet overlay
                if (explorationOpen) ...[
                  // Scrim (dim the reading area behind the sheet)
                  GestureDetector(
                    onTap: chatNotifier.popVirtualPage,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),

                  // The Kindle X-Ray bottom sheet
                  ExplorationBottomSheet(
                    conversationId: widget.conversationId,
                    nodeStack: chatState.nodeStack,
                    onLinkTap: chatNotifier.pushVirtualPage,
                  ),
                ],
              ],
            ),
          ),

          // ── Chat input (only visible when no exploration sheet is open) ──
          if (!explorationOpen)
            ThemeAwareChatInput(
              theme: rt,
              isStreaming: chatState.isStreaming,
              hintText: 'Ask anything to start reading…',
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
    );
  }
}

// ── Chat Header ───────────────────────────────────────────────────────────────

class _ChatHeader extends ConsumerWidget {
  final String title;
  final String conversationId;
  final dynamic theme; // ReadingThemeData

  const _ChatHeader({
    required this.title,
    required this.conversationId,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rt = theme;
    final conv = ref
        .watch(conversationsProvider)
        .conversations
        .where((c) => c.id == conversationId)
        .firstOrNull;
    final nodeCount = conv?.nodes.length ?? 1;

    return Container(
      height: 56,
      color: rt.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Drawer / sidebar toggle on mobile
          if (MediaQuery.of(context).size.width < 700)
            IconButton(
              icon: Icon(Icons.menu_rounded, size: 20, color: rt.textSecondary),
              onPressed: () => Scaffold.of(context).openDrawer(),
            )
          else
            const SizedBox(width: 8),

          // Conversation title
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: rt.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Exploration graph badge (node count)
          if (nodeCount > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: '$nodeCount exploration pages',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rt.linkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: rt.link.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_outlined,
                          size: 11, color: rt.link),
                      const SizedBox(width: 4),
                      Text(
                        '$nodeCount',
                        style: TextStyle(
                          color: rt.link,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Aa — Reading settings
          IconButton(
            tooltip: 'Reading settings',
            icon: Text(
              'Aa',
              style: TextStyle(
                color: rt.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            onPressed: () => showReadingToolbar(context),
          ),
        ],
      ),
    );
  }
}

// ── Welcome View ──────────────────────────────────────────────────────────────

class _WelcomeView extends StatelessWidget {
  final dynamic theme; // ReadingThemeData
  final void Function(String) onSend;

  const _WelcomeView({required this.theme, required this.onSend});

  static const _suggestions = [
    ('Explain quantum entanglement', Icons.science_outlined),
    ('How does the internet work?', Icons.lan_outlined),
    ('What is machine learning?', Icons.psychology_outlined),
    ('Summarise the history of Rome', Icons.history_edu_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final rt = theme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Logo ────────────────────────────────────────────────────
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: rt.accentGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: rt.accent.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'What would you like to explore?',
              style: TextStyle(
                color: rt.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            Text(
              'Ask anything. Select words in responses to dive deeper\nwith linked exploration pages — like Kindle X-Ray.',
              style: TextStyle(
                color: rt.textMuted,
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 36),

            // ── Suggestion cards ─────────────────────────────────────────
            Column(
              children: _suggestions.map((s) {
                final (text, icon) = s;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => onSend(text),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 480),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: rt.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: rt.border),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, size: 18, color: rt.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              text,
                              style: TextStyle(
                                color: rt.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: rt.textDisabled,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error Banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final dynamic theme; // ReadingThemeData

  const _ErrorBanner({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    final rt = theme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: rt.errorSurface,
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: rt.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: rt.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
