import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme/reading_theme.dart';
import '../../../data/models/message.dart';
import '../../../data/models/reading_settings.dart';
import '../../../data/models/text_link.dart';
import '../typing_indicator.dart';

/// Renders an assistant response in the Kindle reading layout.
///
/// Key design choices inspired by Kindle:
/// - Full prose width (no avatar, no bubble) — text is the hero
/// - Proper typographic scale with configurable font, size, and line height
/// - Previously explored phrases shown with a subtle highlight + book icon
/// - "Ask AI" available via the selection context menu on any text span
/// - A thin ornamental divider follows each response to separate Q&A pairs
class ReadingResponseView extends StatelessWidget {
  final Message message;
  final ReadingSettings settings;
  final ReadingThemeData theme;
  final double horizontalMargin;

  /// Called when the user taps an existing exploration link.
  final void Function(String childNodeId)? onLinkTap;

  /// Called when the user selects text and taps "Ask AI".
  final void Function(
    String selectedText,
    int startOffset,
    int endOffset,
    String messageId,
  )? onAskAI;

  const ReadingResponseView({
    super.key,
    required this.message,
    required this.settings,
    required this.theme,
    required this.horizontalMargin,
    this.onLinkTap,
    this.onAskAI,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Loom Learn label ───────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(left: horizontalMargin, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.accentSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.accent.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 11,
                  color: theme.accentLight,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Loom Learn',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),

        // ── Response content ───────────────────────────────────────────────
        if (message.isStreaming && message.content.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalMargin,
              vertical: 8,
            ),
            child: const TypingIndicator(),
          )
        else
          _ResponseBody(
            message: message,
            settings: settings,
            theme: theme,
            horizontalMargin: horizontalMargin,
            onLinkTap: onLinkTap,
            onAskAI: onAskAI,
          ),

        // ── Exploration link chips ─────────────────────────────────────────
        if (message.links.isNotEmpty)
          _ExplorationChips(
            links: message.links,
            theme: theme,
            horizontalMargin: horizontalMargin,
            onTap: (nodeId) => onLinkTap?.call(nodeId),
          ),

        // ── Section divider ────────────────────────────────────────────────
        _SectionDivider(theme: theme, margin: horizontalMargin),
      ],
    );
  }
}

// ── Response Body ─────────────────────────────────────────────────────────────

class _ResponseBody extends StatelessWidget {
  final Message message;
  final ReadingSettings settings;
  final ReadingThemeData theme;
  final double horizontalMargin;
  final void Function(String childNodeId)? onLinkTap;
  final void Function(String, int, int, String)? onAskAI;

  const _ResponseBody({
    required this.message,
    required this.settings,
    required this.theme,
    required this.horizontalMargin,
    this.onLinkTap,
    this.onAskAI,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
      child: SelectionArea(
        contextMenuBuilder: (ctx, selectableRegionState) {
          return _KindleContextMenu(
            anchors: selectableRegionState.contextMenuAnchors,
            defaultItems: selectableRegionState.contextMenuButtonItems,
            onAskAI: () {
              final selected =
                  selectableRegionState.selectedContent?.plainText ?? '';
              if (selected.trim().isNotEmpty) {
                ContextMenuController.removeAny();
                onAskAI?.call(selected.trim(), 0, -1, message.id);
              }
            },
            theme: theme,
          );
        },
        child: MarkdownBody(
          data: message.content,
          selectable: false,
          styleSheet: _buildStyleSheet(context),
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    final fontFamily = settings.fontFamily == ReadingFontFamily.sansSerif
        ? null
        : settings.fontFamily.fontFamily;

    final body = TextStyle(
      color: theme.textPrimary,
      fontSize: settings.fontSize,
      height: settings.lineSpacing.lineHeight,
      fontFamily: fontFamily,
      letterSpacing: 0.1,
    );

    return MarkdownStyleSheet(
      p: body,
      h1: body.copyWith(
        fontSize: settings.fontSize * 1.5,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      h2: body.copyWith(
        fontSize: settings.fontSize * 1.3,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      h3: body.copyWith(
        fontSize: settings.fontSize * 1.15,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      em: body.copyWith(fontStyle: FontStyle.italic),
      strong: body.copyWith(fontWeight: FontWeight.w700),
      code: TextStyle(
        fontFamily: 'Courier New',
        fontSize: settings.fontSize * 0.88,
        color: theme.link,
        backgroundColor: theme.linkSurface,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      codeblockPadding: const EdgeInsets.all(14),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.accent, width: 3),
        ),
        color: theme.accentSurface,
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      blockquote: body.copyWith(
        color: theme.textSecondary,
        fontStyle: FontStyle.italic,
      ),
      listBullet: body.copyWith(color: theme.accent),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.border)),
      ),
      tableHead: body.copyWith(fontWeight: FontWeight.w600),
      tableBody: body.copyWith(color: theme.textSecondary),
      tableBorder: TableBorder.all(color: theme.border),
      tableHeadAlign: TextAlign.left,
      tableColumnWidth: const FlexColumnWidth(),
      pPadding: EdgeInsets.only(bottom: settings.fontSize * 0.75),
    );
  }
}

// ── Custom Kindle Context Menu ────────────────────────────────────────────────

class _KindleContextMenu extends StatelessWidget {
  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> defaultItems;
  final VoidCallback onAskAI;
  final ReadingThemeData theme;

  const _KindleContextMenu({
    required this.anchors,
    required this.defaultItems,
    required this.onAskAI,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final anchor = anchors.primaryAnchor;

    return Stack(
      children: [
        Positioned(
          left: (anchor.dx - 120).clamp(8.0, MediaQuery.of(context).size.width - 248),
          top: (anchor.dy - 60).clamp(8.0, double.infinity),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: theme.isDark
                    ? const Color(0xFF2A2A2A)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Primary: Ask AI
                      _MenuAction(
                        label: 'Ask AI',
                        icon: Icons.auto_awesome_rounded,
                        isPrimary: true,
                        theme: theme,
                        onTap: onAskAI,
                      ),
                      VerticalDivider(width: 1, color: theme.border),
                      // Copy
                      ..._buildDefaultActions(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDefaultActions() {
    final copyItem = defaultItems
        .where((item) =>
            item.type == ContextMenuButtonType.copy ||
            item.label == 'Copy')
        .firstOrNull;

    if (copyItem == null) return [];

    return [
      _MenuAction(
        label: 'Copy',
        icon: Icons.copy_rounded,
        isPrimary: false,
        theme: theme,
        onTap: () {
          copyItem.onPressed?.call();
        },
      ),
    ];
  }
}

class _MenuAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final ReadingThemeData theme;
  final VoidCallback onTap;

  const _MenuAction({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: isPrimary
            ? theme.accent.withValues(alpha: theme.isDark ? 0.2 : 0.1)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isPrimary ? theme.accent : theme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? theme.accent : theme.textSecondary,
                fontSize: 13,
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Exploration Chips ─────────────────────────────────────────────────────────

class _ExplorationChips extends StatelessWidget {
  final List<TextLink> links;
  final ReadingThemeData theme;
  final double horizontalMargin;
  final void Function(String nodeId) onTap;

  const _ExplorationChips({
    required this.links,
    required this.theme,
    required this.horizontalMargin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalMargin, 12, horizontalMargin, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EXPLORATIONS',
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: links.map((link) {
              return GestureDetector(
                onTap: () => onTap(link.childNodeId),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.linkSurface,
                    border: Border.all(
                      color: theme.link.withValues(alpha: 0.4),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_stories_rounded,
                        size: 11,
                        color: theme.link,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        link.triggerText.length > 30
                            ? '${link.triggerText.substring(0, 29)}…'
                            : link.triggerText,
                        style: TextStyle(
                          color: theme.link,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Section Divider ───────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  final ReadingThemeData theme;
  final double margin;

  const _SectionDivider({required this.theme, required this.margin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: margin, vertical: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.sectionDivider, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.more_horiz_rounded,
              size: 14,
              color: theme.textDisabled,
            ),
          ),
          Expanded(child: Divider(color: theme.sectionDivider, thickness: 1)),
        ],
      ),
    );
  }
}
