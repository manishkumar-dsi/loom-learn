import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/theme/reading_theme.dart';
import '../../../data/models/message.dart';
import '../../../data/models/reading_settings.dart';
import '../../../data/models/text_highlight.dart';
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
  final void Function(
    String selectedText,
    int startOffset,
    int endOffset,
    String messageId,
    HighlightColor color,
  )? onHighlight;
  final String? flashHighlightId;

  const ReadingResponseView({
    super.key,
    required this.message,
    required this.settings,
    required this.theme,
    required this.horizontalMargin,
    this.onLinkTap,
    this.onAskAI,
    this.onHighlight,
    this.flashHighlightId,
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
            onHighlight: onHighlight,
            flashHighlightId: flashHighlightId,
          ),

        // ── Exploration chips ──────────────────────────────────────────────
        if (message.links.isNotEmpty)
          _ExplorationChips(
            links: message.links,
            theme: theme,
            horizontalMargin: horizontalMargin,
            onTap: (nodeId) => onLinkTap?.call(nodeId),
          ),

        if (message.highlights.isNotEmpty)
          _HighlightChips(
            highlights: message.highlights,
            theme: theme,
            horizontalMargin: horizontalMargin,
            flashHighlightId: flashHighlightId,
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

class _ResponseBody extends StatefulWidget {
  final Message message;
  final ReadingSettings settings;
  final ReadingThemeData theme;
  final double horizontalMargin;
  final void Function(String childNodeId)? onLinkTap;
  final void Function(String, int, int, String)? onAskAI;
  final void Function(String, int, int, String, HighlightColor)? onHighlight;
  final String? flashHighlightId;

  const _ResponseBody({
    required this.message,
    required this.settings,
    required this.theme,
    required this.horizontalMargin,
    this.onLinkTap,
    this.onAskAI,
    this.onHighlight,
    this.flashHighlightId,
  });

  @override
  State<_ResponseBody> createState() => _ResponseBodyState();
}

class _ResponseBodyState extends State<_ResponseBody> {
  List<_Segment> _cachedSegments = const [];
  String _cachedContent = '';

  @override
  Widget build(BuildContext context) {
    // Re-parse only when content actually changes (avoids re-parsing on
    // unrelated rebuilds like theme or settings changes).
    if (_cachedContent != widget.message.content) {
      _cachedContent = widget.message.content;
      _cachedSegments = _parseSegments(_cachedContent);
    }

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _cachedSegments.map((seg) {
          return switch (seg) {
            _ProseSegment(:final markdown) => _ProseBlock(
                markdown: markdown,
                settings: widget.settings,
                theme: widget.theme,
                horizontalMargin: widget.horizontalMargin,
                messageId: widget.message.id,
                onLinkTap: widget.onLinkTap,
                onAskAI: widget.onAskAI,
                onHighlight: widget.onHighlight,
                flashHighlightId: widget.flashHighlightId,
              ),
            _CodeSegment(:final code, :final language) => Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.horizontalMargin,
                  vertical: 4,
                ),
                child: _CodeBlock(
                  code: code,
                  language: language,
                  theme: widget.theme,
                  fontSize: widget.settings.fontSize,
                ),
              ),
          };
        }).toList(),
      ),
    );
  }
}

// ── Prose block ───────────────────────────────────────────────────────────────

class _ProseBlock extends StatefulWidget {
  final String markdown;
  final ReadingSettings settings;
  final ReadingThemeData theme;
  final double horizontalMargin;
  final String messageId;
  final void Function(String childNodeId)? onLinkTap;
  final void Function(String, int, int, String)? onAskAI;
  final void Function(String, int, int, String, HighlightColor)? onHighlight;
  final String? flashHighlightId;

  const _ProseBlock({
    required this.markdown,
    required this.settings,
    required this.theme,
    required this.horizontalMargin,
    required this.messageId,
    this.onLinkTap,
    this.onAskAI,
    this.onHighlight,
    this.flashHighlightId,
  });

  @override
  State<_ProseBlock> createState() => _ProseBlockState();
}

class _ProseBlockState extends State<_ProseBlock> {
  MarkdownStyleSheet? _cachedStyleSheet;
  ReadingSettings? _cachedSettings;
  ReadingThemeData? _cachedTheme;

  MarkdownStyleSheet get _styleSheet {
    // Rebuild only when settings or theme actually change.
    if (_cachedStyleSheet == null ||
        _cachedSettings != widget.settings ||
        _cachedTheme != widget.theme) {
      _cachedSettings = widget.settings;
      _cachedTheme = widget.theme;
      _cachedStyleSheet = _buildStyleSheet();
    }
    return _cachedStyleSheet!;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.markdown.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.horizontalMargin),
      child: SelectionArea(
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
        selectionControls: MaterialTextSelectionControls(),
        contextMenuBuilder: (ctx, state) {
          Future<String> readSelectedText() async {
            final value = state.textEditingValue;
            var selected = value.selection.textInside(value.text).trim();
            if (selected.isNotEmpty) return selected;

            // Fallback for SelectionArea on Android: trigger platform Copy action.
            ContextMenuButtonItem? copyItem;
            for (final item in state.contextMenuButtonItems) {
              if (item.type == ContextMenuButtonType.copy ||
                  item.label?.toLowerCase() == 'copy') {
                copyItem = item;
                break;
              }
            }
            copyItem?.onPressed?.call();
            await Future<void>.delayed(const Duration(milliseconds: 40));
            final data = await Clipboard.getData('text/plain');
            return data?.text?.trim() ?? '';
          }

          Future<void> emitHighlight(HighlightColor color) async {
            final value = state.textEditingValue;
            final selected = await readSelectedText();
            if (selected.isEmpty) return;
            ContextMenuController.removeAny();
            widget.onHighlight?.call(
              selected,
              value.selection.start,
              value.selection.end,
              widget.messageId,
              color,
            );
          }

          // Anchor position for the floating toolbar
          final anchors = state.contextMenuAnchors;
          final primaryAnchor = anchors.primaryAnchor;

          return _KindleContextMenu(
            anchor: primaryAnchor,
            theme: widget.theme,
            onAskAI: () async {
              final value = state.textEditingValue;
              final selected = await readSelectedText();
              if (selected.isNotEmpty) {
                ContextMenuController.removeAny();
                widget.onAskAI?.call(
                  selected,
                  value.selection.start,
                  value.selection.end,
                  widget.messageId,
                );
              }
            },
            onCopy: () async {
              final selected = await readSelectedText();
              if (selected.isNotEmpty) {
                await Clipboard.setData(ClipboardData(text: selected));
              }
              ContextMenuController.removeAny();
            },
            onHighlight: emitHighlight,
          );
        },
        child: MarkdownBody(
          data: widget.markdown,
          selectable: false,
          inlineSyntaxes: [_HighlightInlineSyntax()],
          builders: {
            'loomhl': _HighlightBuilder(
              theme: widget.theme,
              flashHighlightId: widget.flashHighlightId,
            ),
          },
          styleSheet: _styleSheet,
          onTapLink: (text, href, title) {
            if (href != null) {
              if (href.startsWith('loom://explore/')) {
                widget.onLinkTap?.call(href.substring('loom://explore/'.length));
                return;
              }
              Clipboard.setData(ClipboardData(text: href));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Link copied: $href'),
                  backgroundColor: widget.theme.surfaceElevated,
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
    final settings = widget.settings;
    final theme = widget.theme;
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
      textAlign: WrapAlignment.spaceBetween,

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

// ── Kindle-style Context Menu ──────────────────────────────────────────────────

/// A Kindle-inspired floating context menu with two states:
/// 1. Main toolbar: Highlight (colored dot) | Ask AI | Copy
/// 2. Color picker: ← back | Aqua | Pink | Orange | Yellow | Green
class _KindleContextMenu extends StatefulWidget {
  final Offset anchor;
  final ReadingThemeData theme;
  final VoidCallback onAskAI;
  final VoidCallback onCopy;
  final void Function(HighlightColor color) onHighlight;

  const _KindleContextMenu({
    required this.anchor,
    required this.theme,
    required this.onAskAI,
    required this.onCopy,
    required this.onHighlight,
  });

  @override
  State<_KindleContextMenu> createState() => _KindleContextMenuState();
}

class _KindleContextMenuState extends State<_KindleContextMenu>
    with SingleTickerProviderStateMixin {
  bool _showColorPicker = false;

  static const _menuHeight = 56.0;
  static const _caretHeight = 8.0;
  static const _mainMenuWidth = 280.0;
  static const _colorPickerWidth = 320.0;
  static const _menuBg = Color(0xFF2A2A2E);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final menuWidth =
        _showColorPicker ? _colorPickerWidth : _mainMenuWidth;

    // Position above the selection anchor, centered horizontally
    double left = (widget.anchor.dx - menuWidth / 2)
        .clamp(8.0, screenSize.width - menuWidth - 8);
    double top = widget.anchor.dy - _menuHeight - _caretHeight - 8;
    bool showAbove = true;
    if (top < 8) {
      top = widget.anchor.dy + 24;
      showAbove = false;
    }

    // Arrow position relative to the menu's left edge
    final arrowLeft =
        (widget.anchor.dx - left).clamp(16.0, menuWidth - 16.0);

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Upward caret when menu is below selection
                  if (!showAbove)
                    _buildCaret(arrowLeft, menuWidth, pointsUp: true),

                  // Menu body
                  Container(
                    height: _menuHeight,
                    decoration: BoxDecoration(
                      color: _menuBg,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: _showColorPicker
                            ? _buildColorPicker()
                            : _buildMainToolbar(),
                      ),
                    ),
                  ),

                  // Downward caret when menu is above selection
                  if (showAbove)
                    _buildCaret(arrowLeft, menuWidth, pointsUp: false),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Renders a small triangular caret pointing toward the selected text.
  Widget _buildCaret(double arrowLeft, double menuWidth,
      {required bool pointsUp}) {
    return SizedBox(
      width: menuWidth,
      height: _caretHeight,
      child: CustomPaint(
        painter: _CaretPainter(
          color: _menuBg,
          arrowX: arrowLeft,
          pointsUp: pointsUp,
        ),
      ),
    );
  }

  Widget _buildMainToolbar() {
    return SizedBox(
      key: const ValueKey('main'),
      width: _mainMenuWidth,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Highlight button with colored dot
          _KindleMenuButton(
            icon: Icons.circle,
            iconColor: const Color(0xFFFFBE7A), // Orange dot like Kindle
            iconSize: 18,
            label: 'Highlight',
            onTap: () => setState(() => _showColorPicker = true),
          ),
          _menuDivider(),
          // Ask AI
          _KindleMenuButton(
            icon: Icons.auto_awesome_rounded,
            iconColor: widget.theme.accentLight,
            label: 'Ask AI',
            onTap: widget.onAskAI,
          ),
          _menuDivider(),
          // Copy
          _KindleMenuButton(
            icon: Icons.content_copy_rounded,
            iconColor: const Color(0xFFAAAAAA),
            label: 'Copy',
            onTap: widget.onCopy,
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker() {
    const colors = <(HighlightColor, String, Color)>[
      (HighlightColor.aqua, 'Aqua', Color(0xFF8BE8E0)),
      (HighlightColor.pink, 'Pink', Color(0xFFF9B3E5)),
      (HighlightColor.orange, 'Orange', Color(0xFFFFBE7A)),
      (HighlightColor.yellow, 'Yellow', Color(0xFFFFE07A)),
      (HighlightColor.green, 'Green', Color(0xFFB9F08F)),
    ];

    return SizedBox(
      key: const ValueKey('colors'),
      width: _colorPickerWidth,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Back arrow
          InkWell(
            onTap: () => setState(() => _showColorPicker = false),
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: _menuHeight,
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFFAAAAAA),
                size: 20,
              ),
            ),
          ),
          // Color circles
          ...colors.map((entry) {
            final (color, label, displayColor) = entry;
            return Expanded(
              child: InkWell(
                onTap: () => widget.onHighlight(color),
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: displayColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFCCCCCC),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _menuDivider() {
    return Container(
      width: 0.5,
      height: 28,
      color: const Color(0xFF444448),
    );
  }
}

/// A single button in the Kindle context menu toolbar.
class _KindleMenuButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String label;
  final VoidCallback onTap;

  const _KindleMenuButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: _KindleContextMenuState._menuHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: iconColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFCCCCCC),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints a small triangle (caret) pointing at the selected text.
class _CaretPainter extends CustomPainter {
  final Color color;
  final double arrowX;
  final bool pointsUp;

  _CaretPainter({
    required this.color,
    required this.arrowX,
    required this.pointsUp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const halfWidth = 8.0;
    final paint = Paint()..color = color;
    final path = Path();

    if (pointsUp) {
      path.moveTo(arrowX - halfWidth, size.height);
      path.lineTo(arrowX, 0);
      path.lineTo(arrowX + halfWidth, size.height);
    } else {
      path.moveTo(arrowX - halfWidth, 0);
      path.lineTo(arrowX, size.height);
      path.lineTo(arrowX + halfWidth, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CaretPainter oldDelegate) =>
      oldDelegate.arrowX != arrowX ||
      oldDelegate.pointsUp != pointsUp ||
      oldDelegate.color != color;
}

class _HighlightInlineSyntax extends md.InlineSyntax {
  _HighlightInlineSyntax()
      : super(r'\[\[hl:(yellow|green|pink|aqua|orange):([^\]]+)\]\](.*?)\[\[/hl\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final color = match.group(1) ?? 'yellow';
    final id = match.group(2) ?? '';
    final text = match.group(3) ?? '';
    final el = md.Element.text('loomhl', text)
      ..attributes['color'] = color
      ..attributes['id'] = id;
    parser.addNode(el);
    return true;
  }
}

class _HighlightBuilder extends MarkdownElementBuilder {
  final ReadingThemeData theme;
  final String? flashHighlightId;

  _HighlightBuilder({
    required this.theme,
    required this.flashHighlightId,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final colorName = element.attributes['color'] ?? 'yellow';
    final id = element.attributes['id'] ?? '';
    final hlColor = switch (colorName) {
      'green' => theme.highlightColor(HighlightColor.green),
      'pink' => theme.highlightColor(HighlightColor.pink),
      'aqua' => theme.highlightColor(HighlightColor.aqua),
      'orange' => theme.highlightColor(HighlightColor.orange),
      _ => theme.highlightColor(HighlightColor.yellow),
    };
    final isFlashing = flashHighlightId != null && flashHighlightId == id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: hlColor.withValues(
          alpha: isFlashing
              ? (theme.isDark ? 0.92 : 0.98)
              : (theme.isDark ? 0.6 : 0.72),
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        element.textContent,
        style: (preferredStyle ?? const TextStyle()).copyWith(
          color: theme.textPrimary,
          fontWeight: isFlashing ? FontWeight.w600 : FontWeight.w500,
        ),
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
  Timer? _copyTimer;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
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

class _HighlightChips extends StatelessWidget {
  final List<TextHighlight> highlights;
  final ReadingThemeData theme;
  final double horizontalMargin;
  final String? flashHighlightId;

  const _HighlightChips({
    required this.highlights,
    required this.theme,
    required this.horizontalMargin,
    this.flashHighlightId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalMargin, 8, horizontalMargin, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HIGHLIGHTS',
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
            children: highlights.map((h) {
              final bg = theme.highlightColor(h.color);
              final isFlashing = flashHighlightId == h.id;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: bg.withValues(
                    alpha: isFlashing
                        ? (theme.isDark ? 0.85 : 0.95)
                        : (theme.isDark ? 0.55 : 0.7),
                  ),
                  borderRadius: BorderRadius.circular(isFlashing ? 10 : 14),
                  border: Border.all(
                    color: bg.withValues(alpha: isFlashing ? 1 : 0.8),
                    width: isFlashing ? 1.6 : 1,
                  ),
                ),
                child: Text(
                  h.selectedText.length > 42
                      ? '${h.selectedText.substring(0, 41)}…'
                      : h.selectedText,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
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
