import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/reading_theme.dart';

/// Theme-aware version of the chat input bar.
/// Uses [ReadingThemeData] instead of hardcoded [AppColors].
class ThemeAwareChatInput extends StatefulWidget {
  final ReadingThemeData theme;
  final bool isStreaming;
  final void Function(String text) onSend;
  final String? hintText;

  const ThemeAwareChatInput({
    super.key,
    required this.theme,
    required this.isStreaming,
    required this.onSend,
    this.hintText,
  });

  @override
  State<ThemeAwareChatInput> createState() => _ThemeAwareChatInputState();
}

class _ThemeAwareChatInputState extends State<ThemeAwareChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _keyboardFocusNode = FocusNode();

  /// Tracks whether the text field has content. Updated only when the
  /// empty/non-empty state actually changes, avoiding per-keystroke rebuilds.
  final ValueNotifier<bool> _hasText = ValueNotifier(false);

  void _onTextChanged() {
    final hasContent = _controller.text.trim().isNotEmpty;
    if (_hasText.value != hasContent) {
      _hasText.value = hasContent;
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isStreaming) return;
    _controller.clear();
    _hasText.value = false;
    widget.onSend(text);
    _focusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _keyboardFocusNode.dispose();
    _hasText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rt = widget.theme;

    return Container(
      decoration: BoxDecoration(
        color: rt.surface,
        border: Border(top: BorderSide(color: rt.border)),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: 10 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: rt.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: rt.border),
              ),
              child: KeyboardListener(
                focusNode: _keyboardFocusNode,
                onKeyEvent: (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter &&
                      !HardwareKeyboard.instance.isShiftPressed) {
                    _send();
                  }
                },
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: 5,
                  minLines: 1,
                  enabled: !widget.isStreaming,
                  style: TextStyle(
                    color: rt.textPrimary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.isStreaming
                        ? 'Thinking…'
                        : (widget.hintText ?? 'Message…'),
                    hintStyle: TextStyle(color: rt.textMuted, fontSize: 15),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Only rebuild send button when hasText or isStreaming changes.
          ValueListenableBuilder<bool>(
            valueListenable: _hasText,
            builder: (context, hasText, _) => _SendButton(
              enabled: !widget.isStreaming && hasText,
              isStreaming: widget.isStreaming,
              theme: rt,
              onTap: _send,
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool isStreaming;
  final ReadingThemeData theme;
  final VoidCallback onTap;

  const _SendButton({
    required this.enabled,
    required this.isStreaming,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isStreaming) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.error.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: theme.error.withValues(alpha: 0.3)),
        ),
        child: Icon(Icons.stop_rounded, color: theme.error, size: 18),
      );
    }

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: enabled ? theme.accentGradient : null,
          color: enabled ? null : theme.surfaceHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          color: enabled ? Colors.white : theme.textDisabled,
          size: 18,
        ),
      ),
    );
  }
}
