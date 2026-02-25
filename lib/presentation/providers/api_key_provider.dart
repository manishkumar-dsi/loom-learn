import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/storage_service.dart';
import 'storage_provider.dart';

// ── Settings state ─────────────────────────────────────────────────────────

class SettingsState {
  final String? apiKey;
  final String model;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.apiKey,
    this.model = 'gpt-4o-mini',
    this.isLoading = false,
    this.error,
  });

  bool get hasApiKey => apiKey != null && apiKey!.isNotEmpty;

  SettingsState copyWith({
    String? apiKey,
    String? model,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<SettingsState> {
  final StorageService _storage;

  SettingsNotifier(this._storage) : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final key = await _storage.loadApiKey();
    final model = _storage.loadModel();
    state = state.copyWith(
      apiKey: key,
      model: model,
      isLoading: false,
    );
  }

  Future<void> saveApiKey(String key) async {
    await _storage.saveApiKey(key.trim());
    state = state.copyWith(apiKey: key.trim(), error: null);
  }

  Future<void> clearApiKey() async {
    await _storage.deleteApiKey();
    state = SettingsState(model: state.model);
  }

  Future<void> setModel(String model) async {
    await _storage.saveModel(model);
    state = state.copyWith(model: model);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsNotifier(storage);
});
