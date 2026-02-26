import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme/reading_theme.dart';
import '../../../data/models/message.dart';
import '../../../data/models/reading_settings.dart';
import '../../../data/models/text_link.dart';
import '../typing_indicator.dart';

/// Renders an assistant response in the Kindle reading layout.
///
/// Parsing strategy:
/// - Content is split into **prose segments** and **code-block segments**.
/// - Prose segments use [MarkdownBody] for full formatting (headings, lists,
///   tables, blockquotes, inline code, bold/italic, etc.).
/// - Code-block segments use [_CodeBlock] for a rich display: language badge,
///   one-click copy, horizontal scroll, and always-dark background.
class ReadingResponseView extends StatelessWidget {
  final Message message;
  final ReadingSettings settings;
  final ReadingThemeData theme;
  final double horizontalMargin;

  final void Function(String childNodeId)? onLinkTap;
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
        // ── "Loom Learn" label ─────────────────────────────────────────────
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

        // ── Response body ──────────────────────────────────────────────────
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

        // ── Exploration chips ──────────────────────────────────────────────
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

// ── Segment model ─────────────────────────────────────────────────────────────

sealed class _Segment {}

class _ProseSegment extends _Segment {
  final String markdown;
  _ProseSegment(this.markdown);
}

class _CodeSegment extends _Segment {
  final String code;
  final String language;
  _CodeSegment(this.code, this.language);
}

/// Splits markdown [content] into alternating prose and code-fence segments.
///
/// Handles fenced code blocks (``` ``` and ~~~ ~~~). Unclosed blocks at the
/// end of the string (e.g. during streaming) are emitted as code segments.
List<_Segment> _parseSegments(String content) {
  final segments = <_Segment>[];
  final lines = content.split('\n');

  bool inFence = false;
  String fenceLang = '';
  String fenceChar = '';
  final List<String> codeLines = [];
  final List<String> textLines = [];

  for (final line in lines) {
    if (!inFence) {
      final m = RegExp(r'^(```|~~~)(\w*)').firstMatch(line);
      if (m != null) {
        if (textLines.isNotEmpty) {
          segments.add(_ProseSegment(textLines.join('\n')));
          textLines.clear();
        }
        inFence = true;
        fenceChar = m.group(1)!;
        fenceLang = m.group(2) ?? '';
      } else {
        textLines.add(line);
      }
    } else {
      // Closing fence: same characters, optional trailing whitespace
      if (line.trim() == fenceChar || line.trim() == '```' || line.trim() == '~~~') {
        segments.add(_CodeSegment(codeLines.join('\n'), fenceLang));
        codeLines.clear();
        inFence = false;
        fenceLang = '';
        fenceChar = '';
      } else {
        codeLines.add(line);
      }
    }
  }

  // Flush remaining content
  if (textLines.isNotEmpty) segments.add(_ProseSegment(textLines.join('\n')));
  if (inFence && codeLines.isNotEmpty) {
    // Streaming: unclosed fence — still show as code
    segments.add(_CodeSegment(codeLines.join('\n'), fenceLang));
  }

  return segments;
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
    final segments = _parseSegments(message.content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((seg) {
        return switch (seg) {
          _ProseSegment(:final markdown) => _ProseBlock(
              markdown: markdown,
              settings: settings,
              theme: theme,
              horizontalMargin: horizontalMargin,
              messageId: message.id,
              onAskAI: onAskAI,
            ),
          _CodeSegment(:final code, :final language) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalMargin,
                vertical: 4,
              ),
              child: _CodeBlock(
                code: code,
                language: language,
                theme: theme,
                fontSize: settings.fontSize,
              ),
            ),
        };
      }).toList(),
    );
  }
}

// ── Prose block ───────────────────────────────────────────────────────────────

class _ProseBlock extends StatelessWidget {
  final String markdown;
  final ReadingSettings settings;
  final ReadingThemeData theme;
  final double horizontalMargin;
  final String messageId;
  final void Function(String, int, int, String)? onAskAI;

  const _ProseBlock({
    super.key,
    required this.markdown,
    required this.settings,
    required this.theme,
    required this.horizontalMargin,
    required this.messageId,
    this.onAskAI,
  });

  @override
  Widget build(BuildContext context) {
    if (markdown.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
      child: SelectionArea(
        contextMenuBuilder: (ctx, state) => _KindleContextMenu(
          anchors: state.contextMenuAnchors,
          defaultItems: state.contextMenuButtonItems,
          theme: theme,
          onAskAI: () {
            final selected = state.selectedContent?.plainText ?? '';
            if (selected.trim().isNotEmpty) {
              ContextMenuController.removeAny();
              onAskAI?.call(selected.trim(), 0, -1, messageId);
            }
          },
        ),
        child: MarkdownBody(
          data: markdown,
          selectable: false,
          styleSheet: _buildStyleSheet(),
          onTapLink: (text, href, title) {
            if (href != null) {
              Clipboard.setData(ClipboardData(text: href));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Link copied: $href'),
                  backgroundColor: theme.surfaceElevated,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildStyleSheet() {
    final fontFamily = settings.fontFamily == ReadingFontFamily.sansSerif
        ? null
        : settings.fontFamily.fontFamily;

    final base = TextStyle(
      color: theme.textPrimary,
      fontSize: settings.fontSize,
      height: settings.lineSpacing.lineHeight,
      fontFamily: fontFamily,
      letterSpacing: 0.1,
    );

    return MarkdownStyleSheet(
      // ── Paragraph ────────────────────────────────────────────────────────
      p: base,
      pPadding: EdgeInsets.only(bottom: settings.fontSize * 0.8),

      // ── Headings ─────────────────────────────────────────────────────────
      h1: base.copyWith(
        fontSize: settings.fontSize * 1.65,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: -0.6,
        color: theme.textPrimary,
      ),
      h1Padding: EdgeInsets.only(
        top: settings.fontSize * 1.5,
        bottom: settings.fontSize * 0.6,
      ),

      h2: base.copyWith(
        fontSize: settings.fontSize * 1.35,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.3,
      ),
      h2Padding: EdgeInsets.only(
        top: settings.fontSize * 1.2,
        bottom: settings.fontSize * 0.4,
      ),

      h3: base.copyWith(
        fontSize: settings.fontSize * 1.15,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: -0.1,
      ),
      h3Padding: EdgeInsets.only(
        top: settings.fontSize * 1.0,
        bottom: settings.fontSize * 0.3,
      ),

      h4: base.copyWith(
        fontSize: settings.fontSize * 1.05,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      h4Padding: EdgeInsets.only(
        top: settings.fontSize * 0.8,
        bottom: settings.fontSize * 0.2,
      ),

      h5: base.copyWith(
        fontSize: settings.fontSize,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: theme.textSecondary,
      ),
      h5Padding: EdgeInsets.only(
        top: settings.fontSize * 0.6,
        bottom: settings.fontSize * 0.2,
      ),

      h6: base.copyWith(
        fontSize: settings.fontSize * 0.9,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: theme.textMuted,
      ),
      h6Padding: EdgeInsets.only(
        top: settings.fontSize * 0.4,
        bottom: settings.fontSize * 0.2,
      ),

      // ── Inline emphasis ───────────────────────────────────────────────────
      em: base.copyWith(fontStyle: FontStyle.italic),
      strong: base.copyWith(fontWeight: FontWeight.w700),
      del: base.copyWith(
        decoration: TextDecoration.lineThrough,
        color: theme.textMuted,
      ),

      // ── Inline code ───────────────────────────────────────────────────────
      // Fenced code blocks are handled by _CodeBlock; this is for `inline`.
      code: TextStyle(
        fontFamily: 'Courier New',
        fontSize: settings.fontSize * 0.875,
        color: theme.link,
        backgroundColor: theme.linkSurface,
      ),

      // ── Block code (fallback — normally overridden by _CodeBlock) ─────────
      codeblockDecoration: BoxDecoration(
        color: theme.isDark
            ? const Color(0xFF1E1E2E)
            : const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border.withValues(alpha: 0.4)),
      ),
      codeblockPadding: const EdgeInsets.all(16),

      // ── Blockquote ────────────────────────────────────────────────────────
      blockquote: base.copyWith(
        color: theme.textSecondary,
        fontStyle: FontStyle.italic,
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      blockquoteDecoration: BoxDecoration(
        color: theme.accentSurface,
        border: Border(
          left: BorderSide(color: theme.accent, width: 3.5),
        ),
      ),

      // ── Lists ─────────────────────────────────────────────────────────────
      listBullet: base.copyWith(color: theme.accent),
      listIndent: 24.0,
      listBulletPadding: const EdgeInsets.only(right: 8),

      // ── Horizontal rule ───────────────────────────────────────────────────
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.sectionDivider, width: 1.5),
        ),
      ),

      // ── Tables ───────────────────────────────────────────────────────────
      tableHead: base.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.textPrimary,
      ),
      tableBody: base.copyWith(
        color: theme.textSecondary,
        height: 1.5,
      ),
      tableBorder: TableBorder.all(
        color: theme.border,
        width: 0.75,
      ),
      tableHeadAlign: TextAlign.left,
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
    );
  }
}

// ── Code block ────────────────────────────────────────────────────────────────

/// Renders a fenced code block with:
/// - Language badge (top-left)
/// - One-click copy button (top-right) with animated confirmation
/// - Horizontally scrollable body for wide content
/// - Always-dark background for visual consistency across reading themes
class _CodeBlock extends StatefulWidget {
  final String code;
  final String language;
  final ReadingThemeData theme;
  final double fontSize;

  const _CodeBlock({
    required this.code,
    required this.language,
    required this.theme,
    required this.fontSize,
  });

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    // Code blocks always use a near-dark background regardless of reading theme
    // so that syntax is always readable and they stand out as "code" visually.
    const codeBg = Color(0xFF1E1E2E);    // Catppuccin Mocha base
    const headerBg = Color(0xFF181825);  // Catppuccin Mocha crust
    const codeText = Color(0xFFCDD6F4);  // Catppuccin Mocha text
    const borderCol = Color(0xFF45475A); // Catppuccin Mocha surface1

    final rt = widget.theme;

    return Container(
      margin: EdgeInsets.symmetric(vertical: widget.fontSize * 0.5),
      decoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol, width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header bar: language + copy ──────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
            decoration: const BoxDecoration(
              color: headerBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                bottom: BorderSide(color: borderCol, width: 0.75),
              ),
            ),
            child: Row(
              children: [
                // Language badge
                if (widget.language.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: rt.accentDim.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.language.toLowerCase(),
                      style: TextStyle(
                        color: rt.accentLight,
                        fontSize: 10,
                        fontFamily: 'Courier New',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  const Text(
                    'code',
                    style: TextStyle(
                      color: Color(0xFF585B70),
                      fontSize: 10,
                      fontFamily: 'Courier New',
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                const Spacer(),

                // Copy button
                GestureDetector(
                  onTap: _copy,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _copied
                        ? const _CopyBadge(
                            key: ValueKey('copied'),
                            label: 'Copied',
                            icon: Icons.check_rounded,
                            color: Color(0xFFA6E3A1), // Catppuccin green
                          )
                        : const _CopyBadge(
                            key: ValueKey('copy'),
                            label: 'Copy',
                            icon: Icons.content_copy_rounded,
                            color: Color(0xFF6C7086), // Catppuccin overlay0
                          ),
                  ),
                ),
              ],
            ),
          ),

          // ── Code body ────────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.code,
              style: TextStyle(
                fontFamily: 'Courier New',
                fontSize: widget.fontSize * 0.875,
                color: codeText,
                height: 1.65,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _CopyBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        Positioned(
          left: (anchor.dx - 120).clamp(8.0, screenWidth - 260),
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
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24,
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
                      _MenuAction(
                        label: 'Ask AI',
                        icon: Icons.auto_awesome_rounded,
                        isPrimary: true,
                        theme: theme,
                        onTap: onAskAI,
                      ),
                      VerticalDivider(width: 1, color: theme.border),
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
            item.type == ContextMenuButtonType.copy || item.label == 'Copy')
        .firstOrNull;

    if (copyItem == null) return [];

    return [
      _MenuAction(
        label: 'Copy',
        icon: Icons.copy_rounded,
        isPrimary: false,
        theme: theme,
        onTap: () => copyItem.onPressed?.call(),
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
                      Icon(Icons.auto_stories_rounded,
                          size: 11, color: theme.link),
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
