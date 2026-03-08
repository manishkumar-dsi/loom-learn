import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/message.dart';
import 'linked_text_widget.dart';
import 'typing_indicator.dart';

/// Renders a single [Message] in the chat view.
///
/// - User messages: right-aligned bubble with a distinct background.
/// - Assistant messages: left-aligned, full-width, rendered as markdown with
///   selectable text and "Ask AI" context-menu support.
class MessageBubble extends StatelessWidget {
  final Message message;
  final void Function(String childNodeId)? onLinkTap;
  final void Function(
    String selectedText,
    int startOffset,
    int endOffset,
    String messageId,
  )? onAskAI;

  const MessageBubble({
    super.key,
    required this.message,
    this.onLinkTap,
    this.onAskAI,
  });

  @override
  Widget build(BuildContext context) {
    return switch (message.role) {
      MessageRole.user => _UserBubble(message: message),
      MessageRole.assistant => _AssistantBubble(
          message: message,
          onLinkTap: onLinkTap,
          onAskAI: onAskAI,
        ),
      MessageRole.system => const SizedBox.shrink(),
    };
  }
}

// ── User Bubble ──────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final Message message;

  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.userBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: AppColors.userBubbleBorder),
              ),
              child: SelectableText(
                message.content,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Avatar(isUser: true),
        ],
      ),
    );
  }
}

// ── Assistant Bubble ─────────────────────────────────────────────────────────

class _AssistantBubble extends StatelessWidget {
  final Message message;
  final void Function(String childNodeId)? onLinkTap;
  final void Function(
    String selectedText,
    int startOffset,
    int endOffset,
    String messageId,
  )? onAskAI;

  const _AssistantBubble({
    required this.message,
    this.onLinkTap,
    this.onAskAI,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(isUser: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                if (message.isStreaming && message.content.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: TypingIndicator(),
                  )
                else if (message.links.isEmpty)
                  // Pure markdown when no links (faster render)
                  _MarkdownContent(message: message, onAskAI: onAskAI)
                else
                  // Rich text with tappable link spans
                  LinkedTextWidget(
                    message: message,
                    onLinkTap: onLinkTap,
                    onAskAI: onAskAI,
                  ),
                if (message.links.isNotEmpty)
                  _ExplorationChips(
                    links: message.links,
                    onTap: (nodeId) => onLinkTap?.call(nodeId),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownContent extends StatelessWidget {
  final Message message;
  final void Function(
    String selectedText,
    int startOffset,
    int endOffset,
    String messageId,
  )? onAskAI;

  const _MarkdownContent({required this.message, this.onAskAI});

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      contextMenuBuilder: (ctx, selectableRegionState) {
        final selectedText =
            selectableRegionState.contextMenuAnchors.primaryAnchor.toString();

        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: [
            ...selectableRegionState.contextMenuButtonItems,
            ContextMenuButtonItem(
              label: 'Ask AI',
              onPressed: () {
                ContextMenuController.removeAny();
                // For markdown we pass offsets as 0/-1 (unknown from SelectionArea)
                onAskAI?.call(selectedText, 0, -1, message.id);
              },
            ),
          ],
        );
      },
      child: MarkdownBody(
        data: message.content,
        styleSheet: _markdownStyle(context),
        selectable: false, // SelectionArea handles it
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final base = Theme.of(context).textTheme;
    return MarkdownStyleSheet(
      p: base.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
        height: 1.65,
        fontSize: 15,
      ),
      h1: base.titleLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      h2: base.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      h3: base.titleSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      code: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: AppColors.linkLight,
        backgroundColor: AppColors.surfaceElevated,
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      listBullet: base.bodyMedium?.copyWith(color: AppColors.accent),
      strong: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      em: const TextStyle(
        fontStyle: FontStyle.italic,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Small chips showing existing explorations branching off this message.
class _ExplorationChips extends StatelessWidget {
  final List links;
  final void Function(String nodeId) onTap;

  const _ExplorationChips({required this.links, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: links.map((link) {
          return GestureDetector(
            onTap: () => onTap(link.childNodeId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.linkSurface,
                border: Border.all(color: AppColors.link.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_stories_rounded,
                    size: 12,
                    color: AppColors.link,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    link.triggerText.length > 28
                        ? '${link.triggerText.substring(0, 27)}…'
                        : link.triggerText,
                    style: const TextStyle(
                      color: AppColors.link,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final bool isUser;

  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.accentSurface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: const Icon(Icons.auto_awesome_rounded,
          size: 16, color: AppColors.accentLight),
    );
  }
}

// Expose for use in _MarkdownContent
const surfaceElevated = AppColors.surfaceElevated;
