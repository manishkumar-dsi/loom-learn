import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/highlight_jump_provider.dart';
import '../providers/reading_settings_provider.dart';
import '../widgets/ask_about_dialog.dart';
import '../widgets/exploration_bottom_sheet.dart';
import '../widgets/highlights_sheet.dart';
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
  final Map<String, GlobalKey> _messageKeys = {};
  bool _showFocusChrome = true;
  String? _flashHighlightId;
  String? _lastHandledJumpKey;
  Timer? _flashTimer;

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
    _flashTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyForMessage(String messageId) =>
      _messageKeys.putIfAbsent(messageId, GlobalKey.new);

  Future<void> _jumpToHighlight({
    required HighlightJumpTarget target,
    required String rootNodeId,
    required ChatNotifier chatNotifier,
  }) async {
    if (target.nodeId != rootNodeId) {
      chatNotifier.pushVirtualPage(target.nodeId);
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }

    final key = _messageKeys[target.messageId];
    final ctx = key?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
        alignment: 0.18,
      );
    }
    _flashTimer?.cancel();
    setState(() => _flashHighlightId = target.highlightId);
    _flashTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _flashHighlightId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rt = ref.watch(readingThemeProvider);
    final settings = ref.watch(readingSettingsProvider);
    final isFocusMode = settings.distractionFreeMode;
    final settingsNotifier = ref.read(readingSettingsProvider.notifier);
    final jumpTarget = ref.watch(highlightJumpProvider);
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

    if (jumpTarget != null && jumpTarget.conversationId == widget.conversationId) {
      final jumpKey = '${jumpTarget.conversationId}:${jumpTarget.highlightId}';
      if (_lastHandledJumpKey != jumpKey) {
        _lastHandledJumpKey = jumpKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToHighlight(
            target: jumpTarget,
            rootNodeId: rootNodeId,
            chatNotifier: chatNotifier,
          );
          ref.read(highlightJumpProvider.notifier).state = null;
        });
      }
    }

    return Container(
      color: rt.background,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          if (!isFocusMode)
            _ChatHeader(
              title: conv?.title ?? 'New Chat',
              conversationId: widget.conversationId,
              theme: rt,
              isDistractionFree: isFocusMode,
              onToggleDistractionFree: (enabled) {
                settingsNotifier.setDistractionFreeMode(enabled);
              },
              onOpenHighlights: () => showConversationHighlightsSheet(
                context,
                conversationId: widget.conversationId,
              ),
            ),

          if (!isFocusMode) Divider(height: 1, color: rt.border),

          // ── Error banner ─────────────────────────────────────────────────
          if (chatState.error != null && !isFocusMode)
            _ErrorBanner(message: chatState.error!, theme: rt),

          // ── Messages + exploration sheet ──────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Root messages
                hasMessages
                    ? GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: isFocusMode
                            ? () {
                                setState(() {
                                  _showFocusChrome = !_showFocusChrome;
                                });
                              }
                            : null,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: MediaQuery.of(context).size.height,
                                maxWidth: isFocusMode ? 740 : 860,
                              ),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: isFocusMode ? 22 : 0,
                                  bottom: isFocusMode ? 32 : 0,
                                ),
                                child: ReadingMessageView(
                                  messages: messages,
                                  settings: settings,
                                  theme: rt,
                                  onLinkTap: chatNotifier.pushVirtualPage,
                                  onAskAI: (text, start, end, msgId) async {
                                    final question =
                                        await showAskAboutSelectionDialog(
                                      context: context,
                                      theme: rt,
                                      selectedText: text,
                                    );
                                    if (question == null) return;
                                    await chatNotifier.exploreText(
                                      parentNodeId: rootNodeId,
                                      sourceMessageId: msgId,
                                      triggerText: text,
                                      startOffset: start,
                                      endOffset: end,
                                      userQuestion:
                                          question.isEmpty ? null : question,
                                    );
                                    _scrollToBottom();
                                  },
                                  onHighlight: (text, start, end, msgId, color) async {
                                    await chatNotifier.addHighlight(
                                      nodeId: rootNodeId,
                                      messageId: msgId,
                                      selectedText: text,
                                      startOffset: start,
                                      endOffset: end,
                                      color: color,
                                    );
                                    if (!mounted) return;
                                    _scrollToBottom();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Highlighted in ${color.label}',
                                        ),
                                        duration: const Duration(milliseconds: 900),
                                        backgroundColor: rt.surfaceElevated,
                                      ),
                                    );
                                  },
                                  keyForMessageId: _keyForMessage,
                                  flashHighlightId: _flashHighlightId,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : (isFocusMode
                        ? _FocusEmptyView(theme: rt)
                        : _WelcomeView(
                            theme: rt,
                            onSend: (text) {
                              chatNotifier.sendMessage(
                                nodeId: rootNodeId,
                                userText: text,
                              );
                            },
                          )),

                if (isFocusMode && _showFocusChrome && !explorationOpen)
                  Positioned(
                    right: 14,
                    top: 12,
                    child: _FocusModeControls(
                      theme: rt,
                      onOpenSettings: () => showReadingToolbar(context),
                      onOpenHighlights: () => showConversationHighlightsSheet(
                        context,
                        conversationId: widget.conversationId,
                      ),
                      onExit: () => settingsNotifier.setDistractionFreeMode(false),
                    ),
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
          if (!explorationOpen && !isFocusMode)
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
  final bool isDistractionFree;
  final void Function(bool enabled) onToggleDistractionFree;
  final VoidCallback onOpenHighlights;

  const _ChatHeader({
    required this.title,
    required this.conversationId,
    required this.theme,
    required this.isDistractionFree,
    required this.onToggleDistractionFree,
    required this.onOpenHighlights,
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
          IconButton(
            tooltip: 'Highlights',
            icon: Icon(
              Icons.highlight_alt_rounded,
              size: 19,
              color: rt.textSecondary,
            ),
            onPressed: onOpenHighlights,
          ),
          IconButton(
            tooltip: isDistractionFree
                ? 'Exit focus mode'
                : 'Enter focus mode',
            icon: Icon(
              isDistractionFree
                  ? Icons.fullscreen_exit_rounded
                  : Icons.menu_book_rounded,
              size: 20,
              color: rt.textSecondary,
            ),
            onPressed: () => onToggleDistractionFree(!isDistractionFree),
          ),
        ],
      ),
    );
  }
}

class _FocusModeControls extends StatelessWidget {
  final dynamic theme;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHighlights;
  final VoidCallback onExit;

  const _FocusModeControls({
    required this.theme,
    required this.onOpenSettings,
    required this.onOpenHighlights,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final rt = theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: rt.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rt.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Reading settings',
            icon: Text(
              'Aa',
              style: TextStyle(
                color: rt.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onOpenSettings,
          ),
          IconButton(
            tooltip: 'Highlights',
            icon: Icon(
              Icons.highlight_alt_rounded,
              size: 17,
              color: rt.textSecondary,
            ),
            onPressed: onOpenHighlights,
          ),
          IconButton(
            tooltip: 'Exit focus mode',
            icon: Icon(
              Icons.fullscreen_exit_rounded,
              size: 18,
              color: rt.textSecondary,
            ),
            onPressed: onExit,
          ),
        ],
      ),
    );
  }
}

class _FocusEmptyView extends StatelessWidget {
  final dynamic theme;

  const _FocusEmptyView({required this.theme});

  @override
  Widget build(BuildContext context) {
    final rt = theme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          'Distraction-free mode is on.\nAsk a question to start reading.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: rt.textMuted,
            fontSize: 14,
            height: 1.6,
          ),
        ),
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
