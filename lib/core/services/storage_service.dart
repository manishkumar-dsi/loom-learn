import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/conversation.dart';

const _kApiKeyStorageKey = 'openai_api_key';
const _kModelKey = 'selected_model';
const _kConversationsKey = 'conversations';
const _kDefaultModel = 'gpt-4o-mini';

/// Handles all client-side persistence.
///
/// - API key: stored in the OS secure enclave via [FlutterSecureStorage].
/// - Conversations: serialised as JSON in [SharedPreferences].
class StorageService {
  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;

  StorageService({
    FlutterSecureStorage? secure,
    required SharedPreferences prefs,
  })  : _secure = secure ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _prefs = prefs;

  // ── API Key ────────────────────────────────────────────────────────────────

  Future<String?> loadApiKey() => _secure.read(key: _kApiKeyStorageKey);

  Future<void> saveApiKey(String key) =>
      _secure.write(key: _kApiKeyStorageKey, value: key);

  Future<void> deleteApiKey() => _secure.delete(key: _kApiKeyStorageKey);

  // ── Model preference ───────────────────────────────────────────────────────

  String loadModel() => _prefs.getString(_kModelKey) ?? _kDefaultModel;

  Future<void> saveModel(String model) => _prefs.setString(_kModelKey, model);

  // ── Conversations ─────────────────────────────────────────────────────────

  /// Loads all conversations from SharedPreferences, sorted newest-first.
  List<Conversation> loadConversations() {
    final raw = _prefs.getString(_kConversationsKey);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Persists the full list of conversations.
  Future<void> saveConversations(List<Conversation> conversations) {
    final encoded = jsonEncode(conversations.map((c) => c.toJson()).toList());
    return _prefs.setString(_kConversationsKey, encoded);
  }

  /// Upserts a single conversation (replaces if id already exists).
  Future<void> upsertConversation(
    Conversation conversation,
    List<Conversation> current,
  ) {
    final updated = [
      conversation,
      ...current.where((c) => c.id != conversation.id),
    ];
    return saveConversations(updated);
  }

  Future<void> deleteConversation(
    String id,
    List<Conversation> current,
  ) {
    return saveConversations(current.where((c) => c.id != id).toList());
  }
}
