import 'package:flutter/material.dart';

import '../../core/theme/reading_theme.dart';

/// Shows a dialog letting the user type a question about the selected text.
/// Returns the question string, or null if cancelled.
/// Returns empty string if user taps Ask with no input (caller can use default prompt).
Future<String?> showAskAboutSelectionDialog({
  required BuildContext context,
  required ReadingThemeData theme,
  required String selectedText,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _AskAboutDialogBody(
      theme: theme,
      selectedText: selectedText,
    ),
  );
}

class _AskAboutDialogBody extends StatefulWidget {
  final ReadingThemeData theme;
  final String selectedText;

  const _AskAboutDialogBody({
    required this.theme,
    required this.selectedText,
  });

  @override
  State<_AskAboutDialogBody> createState() => _AskAboutDialogBodyState();
}

class _AskAboutDialogBodyState extends State<_AskAboutDialogBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return AlertDialog(
      backgroundColor: theme.surface,
      title: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: theme.accent, size: 22),
          const SizedBox(width: 8),
          Text(
            'Ask AI',
            style: TextStyle(color: theme.textPrimary, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected text:',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52, maxHeight: 120),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.border),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.selectedText.length > 500
                        ? '${widget.selectedText.substring(0, 500)}…'
                        : widget.selectedText,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            style: TextStyle(color: theme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ask anything about this…',
              hintStyle: TextStyle(color: theme.textMuted),
              filled: true,
              fillColor: theme.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.accent, width: 1.5),
              ),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text('Cancel', style: TextStyle(color: theme.textMuted)),
        ),
        FilledButton.icon(
          onPressed: () {
            final q = _controller.text.trim();
            Navigator.of(context).pop(q.isEmpty ? '' : q);
          },
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Ask'),
          style: FilledButton.styleFrom(backgroundColor: theme.accent),
        ),
      ],
    );
  }
}
