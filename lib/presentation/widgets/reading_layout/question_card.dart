import 'package:flutter/material.dart';

import '../../../core/theme/reading_theme.dart';

/// Renders a user question as a Kindle-style "chapter heading" card.
///
/// In the reading layout, user messages are not chat bubbles — they are styled
/// as compact question prompts that precede each AI response, similar to how
/// Kindle renders search queries or annotations.
class QuestionCard extends StatelessWidget {
  final String text;
  final ReadingThemeData theme;
  final double horizontalMargin;

  const QuestionCard({
    super.key,
    required this.text,
    required this.theme,
    required this.horizontalMargin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── "You" label ─────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  gradient: theme.accentGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'You',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Question text ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: theme.questionCardBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(color: theme.questionCardBorder),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
