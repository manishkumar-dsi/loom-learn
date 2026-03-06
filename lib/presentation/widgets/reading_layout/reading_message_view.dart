import 'package:flutter/material.dart';

import '../../../core/theme/reading_theme.dart';
import '../../../data/models/message.dart';
import '../../../data/models/reading_settings.dart';
import '../../../data/models/text_highlight.dart';
import 'question_card.dart';
import 'reading_response_view.dart';

/// Converts a flat list of [Message]s into the Kindle-style reading layout.
///
/// Groups messages into (user question → assistant response) pairs and
/// renders them as contiguous prose separated by ornamental dividers,
/// rather than individual chat bubbles.
///
/// Unpaired trailing user messages (while awaiting response) are still shown.
class ReadingMessageView extends StatelessWidget {
  final List<Message> messages;
  final ReadingSettings settings;
  final ReadingThemeData theme;

  final void Function(String childNodeId)? onLinkTap;
  final void Function(
    String selectedText,
    int startOffset,
    int endOffset,
    String messageId,
  )? onAskAI;
  final void Function(
    String selectedText,
    int startOffset,
    int endOffset,
    String messageId,
    HighlightColor color,
  )? onHighlight;
  final GlobalKey Function(String messageId)? keyForMessageId;
  final String? flashHighlightId;

  const ReadingMessageView({
    super.key,
    required this.messages,
    required this.settings,
    required this.theme,
    this.onLinkTap,
    this.onAskAI,
    this.onHighlight,
    this.keyForMessageId,
    this.flashHighlightId,
  });

  @override
  Widget build(BuildContext context) {
    final visible = messages.where((m) => m.role != MessageRole.system).toList();
    final margin = settings.margin.horizontal;

    return ListView.builder(
      // Let parent scroll controller own this list
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.only(top: 8, bottom: 24),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final msg = visible[i];

        final child = switch (msg.role) {
          MessageRole.user => QuestionCard(
              text: msg.content,
              theme: theme,
              horizontalMargin: margin,
            ),
          MessageRole.assistant => ReadingResponseView(
              message: msg,
              settings: settings,
              theme: theme,
              horizontalMargin: margin,
              onLinkTap: onLinkTap,
              onAskAI: onAskAI,
              onHighlight: onHighlight,
              flashHighlightId: flashHighlightId,
            ),
          MessageRole.system => const SizedBox.shrink(),
        };
        final key = keyForMessageId?.call(msg.id);
        if (key == null) return child;
        return KeyedSubtree(key: key, child: child);
      },
    );
  }
}
