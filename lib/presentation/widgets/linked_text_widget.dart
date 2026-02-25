import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/message.dart';
import '../../data/models/text_link.dart';

/// Renders a [Message]'s content as selectable rich text.
///
/// Any [TextLink]s embedded in the message are displayed as tappable cyan
/// underlines. Tapping a link triggers [onLinkTap] with the child node id.
///
/// Non-linked text segments are fully selectable so users can create new
/// explorations via the custom "Ask AI" toolbar button.
class LinkedTextWidget extends StatelessWidget {
  final Message message;
  final TextStyle? textStyle;

  /// Called when the user taps an existing link (navigate to that node).
  final void Function(String childNodeId)? onLinkTap;

  /// Called when the user selects plain text and taps "Ask AI".
  final void Function(
    String selectedText,
    int startOffset,
    int endOffset,
    String messageId,
  )? onAskAI;

  const LinkedTextWidget({
    super.key,
    required this.message,
    this.textStyle,
    this.onLinkTap,
    this.onAskAI,
  });

  @override
  Widget build(BuildContext context) {
    final content = message.content;
    final links = List<TextLink>.from(message.links)
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    if (links.isEmpty) {
      return _buildSelectable(context, content, 0);
    }

    // Split content into plain segments and link segments
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final link in links) {
      final start = link.startOffset.clamp(0, content.length);
      final end = link.endOffset.clamp(0, content.length);
      if (start >= end) continue;

      // Plain text before this link
      if (cursor < start) {
        spans.add(
          _plainSpan(context, content.substring(cursor, start), cursor),
        );
      }

      // Link span
      spans.add(_linkSpan(content.substring(start, end), link));
      cursor = end;
    }

    // Remaining plain text after last link
    if (cursor < content.length) {
      spans.add(_plainSpan(context, content.substring(cursor), cursor));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: _baseStyle(context),
      contextMenuBuilder: (ctx, editableTextState) =>
          _buildContextMenu(ctx, editableTextState, content),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildSelectable(
    BuildContext context,
    String text,
    int baseOffset,
  ) {
    return SelectableText(
      text,
      style: _baseStyle(context),
      contextMenuBuilder: (ctx, editableTextState) =>
          _buildContextMenu(ctx, editableTextState, text, baseOffset: baseOffset),
    );
  }

  TextSpan _plainSpan(BuildContext context, String text, int baseOffset) {
    return TextSpan(text: text, style: _baseStyle(context));
  }

  TextSpan _linkSpan(String text, TextLink link) {
    return TextSpan(
      text: text,
      style: const TextStyle(
        color: AppColors.link,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.link,
        decorationStyle: TextDecorationStyle.solid,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () => onLinkTap?.call(link.childNodeId),
    );
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
    String fullText, {
    int baseOffset = 0,
  }) {
    final selection = editableTextState.textEditingValue.selection;
    final selectedText = selection.isValid && !selection.isCollapsed
        ? fullText.substring(
            selection.start.clamp(0, fullText.length),
            selection.end.clamp(0, fullText.length),
          )
        : '';

    final defaultItems = editableTextState.contextMenuButtonItems;

    final askItem = selectedText.trim().isNotEmpty
        ? ContextMenuButtonItem(
            label: 'Ask AI',
            onPressed: () {
              ContextMenuController.removeAny();
              onAskAI?.call(
                selectedText,
                baseOffset + selection.start,
                baseOffset + selection.end,
                message.id,
              );
            },
          )
        : null;

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [
        ...defaultItems,
        if (askItem != null) askItem,
      ],
    );
  }

  TextStyle _baseStyle(BuildContext context) {
    return (textStyle ?? Theme.of(context).textTheme.bodyMedium!).copyWith(
      color: AppColors.textPrimary,
      height: 1.65,
    );
  }
}
