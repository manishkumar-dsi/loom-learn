import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/highlight_jump_provider.dart';
import '../providers/highlights_provider.dart';
import '../providers/reading_settings_provider.dart';

void showConversationHighlightsSheet(
  BuildContext context, {
  required String conversationId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ConversationHighlightsSheet(conversationId: conversationId),
  );
}

class _ConversationHighlightsSheet extends ConsumerWidget {
  final String conversationId;

  const _ConversationHighlightsSheet({required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rt = ref.watch(readingThemeProvider);
    final highlights = ref.watch(conversationHighlightsProvider(conversationId));

    return Container(
      decoration: BoxDecoration(
        color: rt.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: rt.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  Text(
                    'Highlights',
                    style: TextStyle(
                      color: rt.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${highlights.length}',
                    style: TextStyle(color: rt.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: rt.border),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: highlights.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No highlights yet.',
                        style: TextStyle(color: rt.textMuted),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: highlights.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: rt.borderSubtle,
                      ),
                      itemBuilder: (_, i) {
                        final item = highlights[i];
                        final bg = rt.highlightColor(item.highlight.color);
                        return ListTile(
                          onTap: () {
                            ref.read(highlightJumpProvider.notifier).state =
                                HighlightJumpTarget(
                              conversationId: item.conversationId,
                              nodeId: item.nodeId,
                              messageId: item.messageId,
                              highlightId: item.highlight.id,
                            );
                            Navigator.pop(context);
                          },
                          leading: Container(
                            width: 8,
                            height: 28,
                            decoration: BoxDecoration(
                              color: bg.withValues(alpha: rt.isDark ? 0.75 : 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          title: Text(
                            item.highlight.selectedText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: rt.textPrimary,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                          subtitle: Text(
                            item.highlight.color.label,
                            style: TextStyle(color: rt.textMuted, fontSize: 11),
                          ),
                          dense: true,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
