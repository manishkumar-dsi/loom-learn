import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/reading_theme.dart';
import '../../data/models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/reading_settings_provider.dart';
import 'ask_about_dialog.dart';
import 'reading_layout/reading_message_view.dart';
import 'theme_aware_chat_input.dart';

/// Kindle X-Ray-inspired bottom sheet for virtual page exploration.
///
/// Displayed as a draggable panel that peeks at ~45 % of screen height and
/// can be dragged to full screen. The panel renders the active child
/// [ConversationNode]'s messages in the same reading layout as the main chat.
///
/// Navigation:
/// - Drag handle at top for resize
/// - Back arrow in header to `popVirtualPage()`
/// - Breadcrumb trail showing exploration depth
/// - "Exploring: X" context strip shows the trigger phrase
class ExplorationBottomSheet extends ConsumerStatefulWidget {
  final String conversationId;
  final List<String> nodeStack;
  final void Function(String childNodeId) onLinkTap;

  const ExplorationBottomSheet({
    super.key,
    required this.conversationId,
    required this.nodeStack,
    required this.onLinkTap,
  });

  @override
  ConsumerState<ExplorationBottomSheet> createState() =>
      _ExplorationBottomSheetState();
}

class _ExplorationBottomSheetState
    extends ConsumerState<ExplorationBottomSheet>
    with SingleTickerProviderStateMixin {
  late final DraggableScrollableController _sheetController;
  final _scrollController = ScrollController();

  // Height fractions for snap points
  static const _kPeek = 0.48;
  static const _kFull = 1.0;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(ExplorationBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodeStack.last != widget.nodeStack.last) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  String get _activeNodeId => widget.nodeStack.last;

  @override
  Widget build(BuildContext context) {
    final rt = ref.watch(readingThemeProvider);
    final settings = ref.watch(readingSettingsProvider);
    final chatState = ref.watch(chatProvider(widget.conversationId));
    final chatNotifier =
        ref.read(chatProvider(widget.conversationId).notifier);

    // Resolve the active node
    final conv = ref
        .read(conversationsProvider.notifier)
        .getConversation(widget.conversationId);
    final activeNode = conv?.nodes[_activeNodeId];
    final messages = activeNode?.messages
            .where((m) => m.role != MessageRole.system)
            .toList() ??
        [];

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _kPeek,
      minChildSize: _kPeek,
      maxChildSize: _kFull,
      snap: true,
      snapSizes: const [_kPeek, _kFull],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: rt.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                spreadRadius: -8,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              GestureDetector(
                onVerticalDragUpdate: (_) {},
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag pip
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: rt.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // ── Header ─────────────────────────────────────────
                      _SheetHeader(
                        activeNode: activeNode,
                        nodeStack: widget.nodeStack,
                        conversationId: widget.conversationId,
                        theme: rt,
                        onBack: () {
                          if (widget.nodeStack.length <= 2) {
                            // Back to root — close sheet
                            chatNotifier.popVirtualPage();
                          } else {
                            chatNotifier.popVirtualPage();
                          }
                        },
                      ),

                      // ── Context strip (trigger phrase) ─────────────────
                      if (activeNode?.triggerText != null)
                        _ContextStrip(
                          triggerText: activeNode!.triggerText!,
                          theme: rt,
                        ),
                    ],
                  ),
                ),
              ),

              Divider(height: 1, color: rt.border),

              // ── Messages ─────────────────────────────────────────────────
              Expanded(
                child: messages.isEmpty
                    ? _EmptyExploration(theme: rt)
                    : SingleChildScrollView(
                        controller: _scrollController,
                        child: ReadingMessageView(
                          messages: messages,
                          settings: settings,
                          theme: rt,
                          onLinkTap: widget.onLinkTap,
                          onAskAI: (text, start, end, msgId) async {
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
                          onHighlight: (text, start, end, msgId, color) async {
                            await chatNotifier.addHighlight(
                              nodeId: _activeNodeId,
                              messageId: msgId,
                              selectedText: text,
                              startOffset: start,
                              endOffset: end,
                              color: color,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Highlighted in ${color.label}'),
                                duration: const Duration(milliseconds: 900),
                                backgroundColor: rt.surfaceElevated,
                              ),
                            );
                          },
                        ),
                      ),
              ),

              // ── Input ─────────────────────────────────────────────────────
              ThemeAwareChatInput(
                theme: rt,
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
        );
      },
    );
  }
}

// ── Sheet Header ──────────────────────────────────────────────────────────────

class _SheetHeader extends ConsumerWidget {
  final dynamic activeNode;
  final List<String> nodeStack;
  final String conversationId;
  final ReadingThemeData theme;
  final VoidCallback onBack;

  const _SheetHeader({
    required this.activeNode,
    required this.nodeStack,
    required this.conversationId,
    required this.theme,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = activeNode?.triggerText ?? activeNode?.title ?? 'Exploring';
    final depth = nodeStack.length - 1; // 0 = root, 1 = first exploration

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
            color: theme.textSecondary,
            onPressed: onBack,
            tooltip: 'Close exploration',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),

          // Book icon
          Icon(
            Icons.auto_stories_rounded,
            size: 15,
            color: theme.link,
          ),
          const SizedBox(width: 8),

          // Title
          Expanded(
            child: Text(
              title.length > 40 ? '${title.substring(0, 39)}…' : title,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Depth badge
          if (depth > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: theme.linkSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.link.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List.generate(
                    depth.clamp(0, 4),
                    (_) => Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.link,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'Level $depth',
                    style: TextStyle(
                      color: theme.link,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Context strip ─────────────────────────────────────────────────────────────

class _ContextStrip extends StatelessWidget {
  final String triggerText;
  final ReadingThemeData theme;

  const _ContextStrip({required this.triggerText, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.linkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.link.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, size: 14, color: theme.link),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: 'Exploring: ',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                TextSpan(
                  text: triggerText.length > 80
                      ? '${triggerText.substring(0, 79)}…'
                      : triggerText,
                  style: TextStyle(
                    color: theme.link,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyExploration extends StatelessWidget {
  final ReadingThemeData theme;

  const _EmptyExploration({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_outlined,
            size: 40,
            color: theme.textDisabled,
          ),
          const SizedBox(height: 10),
          Text(
            'Exploring…',
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
