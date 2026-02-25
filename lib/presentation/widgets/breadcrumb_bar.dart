import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/conversation_node.dart';

/// Navigation breadcrumb shown at the top of every virtual page.
///
/// Displays the chain of explorations from root to the current node. Tapping
/// any crumb pops the stack back to that level.
class BreadcrumbBar extends StatelessWidget {
  /// All nodes in the current navigation stack, root first.
  final List<ConversationNode> nodeStack;

  /// Called when the user taps a crumb; index is the position in [nodeStack].
  final void Function(int index) onCrumbTap;

  const BreadcrumbBar({
    super.key,
    required this.nodeStack,
    required this.onCrumbTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: AppColors.surface,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: nodeStack.length,
        separatorBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 14,
            color: AppColors.textMuted,
          ),
        ),
        itemBuilder: (context, i) {
          final node = nodeStack[i];
          final isLast = i == nodeStack.length - 1;

          return GestureDetector(
            onTap: isLast ? null : () => onCrumbTap(i),
            child: Center(
              child: Text(
                node.isRoot ? 'Chat' : _label(node.triggerText ?? node.title),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
                  color: isLast ? AppColors.link : AppColors.textSecondary,
                  decoration:
                      isLast ? null : TextDecoration.underline,
                  decorationColor: AppColors.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _label(String text) {
    const max = 24;
    return text.length <= max ? text : '${text.substring(0, max - 1)}…';
  }
}
