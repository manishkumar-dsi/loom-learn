import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/conversations_provider.dart';
import '../providers/highlight_jump_provider.dart';
import '../providers/highlights_provider.dart';
import '../providers/reading_settings_provider.dart';

class HighlightsScreen extends ConsumerWidget {
  const HighlightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rt = ref.watch(readingThemeProvider);
    final items = ref.watch(globalHighlightsProvider);

    return Scaffold(
      backgroundColor: rt.background,
      appBar: AppBar(
        title: const Text('Highlights'),
        backgroundColor: rt.surface,
      ),
      body: items.isEmpty
          ? Center(
              child: Text(
                'No highlights yet.',
                style: TextStyle(color: rt.textMuted),
              ),
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: rt.borderSubtle),
              itemBuilder: (_, i) {
                final item = items[i];
                final bg = rt.highlightColor(item.highlight.color);
                return ListTile(
                  onTap: () {
                    ref
                        .read(conversationsProvider.notifier)
                        .selectConversation(item.conversationId);
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
                    height: 34,
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
                    '${item.conversationTitle} • ${item.highlight.color.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: rt.textMuted, fontSize: 11),
                  ),
                );
              },
            ),
    );
  }
}
