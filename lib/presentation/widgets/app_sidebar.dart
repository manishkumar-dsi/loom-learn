import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/reading_theme.dart';
import '../../data/models/conversation.dart';
import '../providers/conversations_provider.dart';
import '../providers/reading_settings_provider.dart';

/// Collapsible conversation list sidebar. Theme-aware via [readingThemeProvider].
class AppSidebar extends ConsumerWidget {
  final VoidCallback? onSettingsTap;

  const AppSidebar({super.key, this.onSettingsTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rt = ref.watch(readingThemeProvider);
    final state = ref.watch(conversationsProvider);
    final notifier = ref.read(conversationsProvider.notifier);

    return Container(
      width: 260,
      color: rt.surface,
      child: Column(
        children: [
          _SidebarHeader(theme: rt, onNewChat: notifier.newConversation),
          Divider(height: 1, color: rt.border),
          Expanded(
            child: state.conversations.isEmpty
                ? _EmptySidebar(theme: rt)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: state.conversations.length,
                    itemBuilder: (_, i) {
                      final conv = state.conversations[i];
                      return _ConversationTile(
                        conversation: conv,
                        isActive: conv.id == state.activeConversationId,
                        theme: rt,
                        onTap: () => notifier.selectConversation(conv.id),
                        onDelete: () => notifier.deleteConversation(conv.id),
                        onRename: (t) =>
                            notifier.renameConversation(conv.id, t),
                      );
                    },
                  ),
          ),
          Divider(height: 1, color: rt.border),
          _SidebarFooter(theme: rt, onSettingsTap: onSettingsTap),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _SidebarHeader extends StatelessWidget {
  final ReadingThemeData theme;
  final VoidCallback onNewChat;

  const _SidebarHeader({required this.theme, required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => theme.accentGradient.createShader(b),
            child: Text(
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
            icon: Icon(Icons.add_rounded, color: theme.textSecondary),
            tooltip: 'New chat',
            onPressed: onNewChat,
            style: IconButton.styleFrom(
              backgroundColor: theme.surfaceElevated,
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
  final ReadingThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final void Function(String) onRename;

  const _ConversationTile({
    required this.conversation,
    required this.isActive,
    required this.theme,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _hovering = false;

  void _rename(BuildContext context) {
    final ctrl = TextEditingController(text: widget.conversation.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: widget.theme.surfaceElevated,
        title: Text('Rename',
            style: TextStyle(color: widget.theme.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: widget.theme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: widget.theme.textMuted)),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                widget.onRename(ctrl.text.trim());
              }
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: widget.theme.accent),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rt = widget.theme;
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
                ? rt.accentSurface
                : _hovering
                    ? rt.surfaceElevated
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: widget.isActive
                ? Border.all(color: rt.accent.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 14,
                color: widget.isActive ? rt.accentLight : rt.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isActive ? rt.accentLight : rt.textSecondary,
                    fontWeight: widget.isActive
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (_hovering || widget.isActive)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _rename(context),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.edit_outlined,
                            size: 13, color: rt.textMuted),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline_rounded,
                            size: 13, color: rt.error),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _SidebarFooter extends StatelessWidget {
  final ReadingThemeData theme;
  final VoidCallback? onSettingsTap;

  const _SidebarFooter({required this.theme, this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading:
          Icon(Icons.settings_outlined, size: 18, color: theme.textMuted),
      title: Text(
        'Settings',
        style: TextStyle(color: theme.textSecondary, fontSize: 14),
      ),
      onTap: onSettingsTap,
      dense: true,
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptySidebar extends StatelessWidget {
  final ReadingThemeData theme;

  const _EmptySidebar({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 36, color: theme.textDisabled),
          const SizedBox(height: 8),
          Text('No chats yet',
              style: TextStyle(color: theme.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
