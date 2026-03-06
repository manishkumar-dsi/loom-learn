import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_key_provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/reading_settings_provider.dart';
import '../widgets/app_sidebar.dart';
import 'chat_screen.dart';
import 'highlights_screen.dart';
import 'settings_screen.dart';

/// Root screen. Adaptive layout: drawer on mobile, sidebar on wide screens.
/// Uses [readingThemeProvider] for all background/surface colors.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rt = ref.watch(readingThemeProvider);
    final isWide = MediaQuery.of(context).size.width >= 700;

    void openSettings() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    }

    void openHighlights() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HighlightsScreen()),
      );
    }

    final convState = ref.watch(conversationsProvider);
    final convNotifier = ref.read(conversationsProvider.notifier);
    // Only watch hasApiKey to avoid rebuilding when model changes.
    final hasApiKey = ref.watch(settingsProvider.select((s) => s.hasApiKey));

    // Auto-create first conversation synchronously so we never block on storage
    if (convState.conversations.isEmpty &&
        convState.activeConversationId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        convNotifier.ensureFirstConversation();
      });
    }

    final sidebar = AppSidebar(
      onSettingsTap: openSettings,
      onHighlightsTap: openHighlights,
    );

    Widget body = convState.activeConversationId == null
        ? _LoadingView(theme: rt)
        : ChatScreen(conversationId: convState.activeConversationId!);

    if (!hasApiKey) {
      body = _NoKeyBanner(
        theme: rt,
        onSetup: openSettings,
        body: body,
      );
    }

    if (isWide) {
      return Scaffold(
        backgroundColor: rt.background,
        body: SafeArea(
          child: Row(
            children: [
              sidebar,
              VerticalDivider(width: 1, color: rt.border),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: rt.background,
      drawer: Drawer(
        backgroundColor: rt.surface,
        width: 280,
        child: sidebar,
      ),
      body: SafeArea(child: body),
    );
  }
}

// ── No API key banner ─────────────────────────────────────────────────────────

class _NoKeyBanner extends StatelessWidget {
  final dynamic theme;
  final VoidCallback onSetup;
  final Widget body;

  const _NoKeyBanner({
    required this.theme,
    required this.onSetup,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onSetup,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(gradient: theme.accentGradient),
            child: const Row(
              children: [
                Icon(Icons.vpn_key_rounded, size: 14, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add your OpenAI API key to start reading  →',
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
  final dynamic theme;

  const _LoadingView({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: theme.accent,
        strokeWidth: 2,
      ),
    );
  }
}
