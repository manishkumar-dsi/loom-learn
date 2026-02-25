import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../providers/api_key_provider.dart';
import '../providers/conversations_provider.dart';
import '../widgets/app_sidebar.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

/// Root screen of the app. Uses an adaptive layout:
/// - Narrow (< 700 dp): sidebar is a [Drawer].
/// - Wide  (≥ 700 dp): sidebar is always visible in a [Row].
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 700;

    void openSettings() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    }

    final state = ref.watch(conversationsProvider);
    final notifier = ref.read(conversationsProvider.notifier);
    final settings = ref.watch(settingsProvider);

    // Auto-create first conversation if list is empty
    if (state.conversations.isEmpty && state.activeConversationId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.newConversation();
      });
    }

    final sidebar = AppSidebar(onSettingsTap: openSettings);

    Widget body;
    if (state.activeConversationId == null) {
      body = const _LoadingView();
    } else {
      body = ChatScreen(conversationId: state.activeConversationId!);
    }

    if (isWide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            sidebar,
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        width: 280,
        child: sidebar,
      ),
      body: !settings.hasApiKey
          ? _NoKeyBanner(onSetup: openSettings, body: body)
          : body,
    );
  }
}

// ── No API key banner ─────────────────────────────────────────────────────────

class _NoKeyBanner extends StatelessWidget {
  final VoidCallback onSetup;
  final Widget body;

  const _NoKeyBanner({required this.onSetup, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Persistent top banner prompting user to add their key
        GestureDetector(
          onTap: onSetup,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: AppColors.accentGradient,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.vpn_key_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Add your OpenAI API key to start chatting  →',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.accent,
        strokeWidth: 2,
      ),
    );
  }
}
