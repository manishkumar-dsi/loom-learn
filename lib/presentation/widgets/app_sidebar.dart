import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/conversation.dart';
import '../providers/conversations_provider.dart';

/// Collapsible left sidebar showing all conversation threads.
///
/// On mobile the sidebar is presented as a [Drawer]; on wider screens it is
/// always visible (responsive layout handled by [HomeScreen]).
class AppSidebar extends ConsumerWidget {
  final VoidCallback? onSettingsTap;

  const AppSidebar({super.key, this.onSettingsTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationsProvider);
    final notifier = ref.read(conversationsProvider.notifier);

    return Container(
      width: 260,
      color: AppColors.surface,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          _SidebarHeader(
            onNewChat: () => notifier.newConversation(),
          ),

          const Divider(height: 1),

          // ── Conversation list ─────────────────────────────────────────
          Expanded(
            child: state.conversations.isEmpty
                ? const _EmptySidebar()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: state.conversations.length,
                    itemBuilder: (_, i) {
                      final conv = state.conversations[i];
                      return _ConversationTile(
                        conversation: conv,
                        isActive: conv.id == state.activeConversationId,
                        onTap: () => notifier.selectConversation(conv.id),
                        onDelete: () => notifier.deleteConversation(conv.id),
                        onRename: (title) =>
                            notifier.renameConversation(conv.id, title),
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // ── Footer ────────────────────────────────────────────────────
          _SidebarFooter(onSettingsTap: onSettingsTap),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _SidebarHeader extends StatelessWidget {
  final VoidCallback onNewChat;

  const _SidebarHeader({required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(
        children: [
          // Logo / wordmark
          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.accentGradient.createShader(bounds),
            child: const Text(
              'Loom Learn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            color: AppColors.textSecondary,
            tooltip: 'New chat',
            onPressed: onNewChat,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(32, 32),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Conversation tile ─────────────────────────────────────────────────────────

class _ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final void Function(String title) onRename;

  const _ConversationTile({
    required this.conversation,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _hovering = false;

  void _showRenameDialog(BuildContext context) {
    final controller =
        TextEditingController(text: widget.conversation.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          'Rename chat',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Chat title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                widget.onRename(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.accentSurface
                : _hovering
                    ? AppColors.surfaceElevated
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: widget.isActive
                ? Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 14,
                color: widget.isActive
                    ? AppColors.accentLight
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isActive
                        ? AppColors.accentLight
                        : AppColors.textSecondary,
                    fontWeight: widget.isActive
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (_hovering || widget.isActive)
                _TileActions(
                  onRename: () => _showRenameDialog(context),
                  onDelete: widget.onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileActions extends StatelessWidget {
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _TileActions({required this.onRename, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionIcon(
          icon: Icons.edit_outlined,
          onTap: onRename,
          tooltip: 'Rename',
        ),
        const SizedBox(width: 2),
        _ActionIcon(
          icon: Icons.delete_outline_rounded,
          onTap: onDelete,
          tooltip: 'Delete',
          color: AppColors.error,
        ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;

  const _ActionIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color = AppColors.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _SidebarFooter extends StatelessWidget {
  final VoidCallback? onSettingsTap;

  const _SidebarFooter({this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(
        Icons.settings_outlined,
        size: 18,
        color: AppColors.textMuted,
      ),
      title: const Text(
        'Settings',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),
      onTap: onSettingsTap,
      dense: true,
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptySidebar extends StatelessWidget {
  const _EmptySidebar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.forum_outlined,
            size: 36,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 8),
          Text(
            'No chats yet',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
