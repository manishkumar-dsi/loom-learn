import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/conversation.dart';
import '../../data/models/message.dart';
import '../../data/repositories/conversation_repository.dart';
import 'storage_provider.dart';

// ── Repository provider ────────────────────────────────────────────────────

final conversationRepositoryProvider =
    Provider<ConversationRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final repo = ConversationRepository(storage);
  repo.init();
  return repo;
});

// ── Conversations list state ───────────────────────────────────────────────

class ConversationsState {
  final List<Conversation> conversations;
  final String? activeConversationId;

  const ConversationsState({
    this.conversations = const [],
    this.activeConversationId,
  });

  Conversation? get activeConversation => activeConversationId == null
      ? null
      : conversations.where((c) => c.id == activeConversationId).firstOrNull;

  ConversationsState copyWith({
    List<Conversation>? conversations,
    String? activeConversationId,
    bool clearActive = false,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      activeConversationId:
          clearActive ? null : activeConversationId ?? this.activeConversationId,
    );
  }
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  final ConversationRepository _repo;

  ConversationsNotifier(this._repo)
      : super(ConversationsState(conversations: _repo.conversations));

  void _sync() {
    state = state.copyWith(conversations: _repo.conversations);
  }

  Future<Conversation> newConversation() async {
    final conv = await _repo.createConversation();
    _sync();
    state = state.copyWith(activeConversationId: conv.id);
    return conv;
  }

  void selectConversation(String id) {
    state = state.copyWith(activeConversationId: id);
  }

  Future<void> deleteConversation(String id) async {
    await _repo.deleteConversation(id);
    _sync();
    if (state.activeConversationId == id) {
      final next =
          state.conversations.isNotEmpty ? state.conversations.first.id : null;
      state = state.copyWith(
        activeConversationId: next,
        clearActive: next == null,
      );
    }
  }

  Future<void> renameConversation(String id, String title) async {
    await _repo.renameConversation(id, title);
    _sync();
  }

  /// Refreshes state after a chat provider mutates the repository directly.
  void refresh() => _sync();

  Conversation? getConversation(String id) => _repo.getConversation(id);
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
  final repo = ref.watch(conversationRepositoryProvider);
  return ConversationsNotifier(repo);
});
