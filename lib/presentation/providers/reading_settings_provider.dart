import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/reading_theme.dart';
import '../../data/models/reading_settings.dart';
import 'storage_provider.dart';

const _kReadingSettingsKey = 'reading_settings';

// ── Notifier ──────────────────────────────────────────────────────────────────

class ReadingSettingsNotifier extends StateNotifier<ReadingSettings> {
  final _StorageProxy _storage;

  ReadingSettingsNotifier(this._storage) : super(_load(_storage));

  static ReadingSettings _load(_StorageProxy storage) {
    final raw = storage.getString(_kReadingSettingsKey);
    if (raw == null) return const ReadingSettings();
    try {
      return ReadingSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const ReadingSettings();
    }
  }

  Future<void> _persist() async {
    await _storage.setString(
      _kReadingSettingsKey,
      jsonEncode(state.toJson()),
    );
  }

  Future<void> setTheme(ReadingThemeMode theme) async {
    state = state.copyWith(theme: theme);
    await _persist();
  }

  Future<void> setFontFamily(ReadingFontFamily family) async {
    state = state.copyWith(fontFamily: family);
    await _persist();
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(fontSize: size.clamp(13.0, 24.0));
    await _persist();
  }

  Future<void> setLineSpacing(ReadingLineSpacing spacing) async {
    state = state.copyWith(lineSpacing: spacing);
    await _persist();
  }

  Future<void> setMargin(ReadingMargin margin) async {
    state = state.copyWith(margin: margin);
    await _persist();
  }

  Future<void> setDistractionFreeMode(bool enabled) async {
    state = state.copyWith(distractionFreeMode: enabled);
    await _persist();
  }
}

// ── Thin wrapper to avoid direct SharedPreferences dependency in notifier ─────

class _StorageProxy {
  final dynamic _prefs;
  _StorageProxy(this._prefs);

  String? getString(String key) => _prefs.getString(key) as String?;

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}

// ── Providers ─────────────────────────────────────────────────────────────────

final readingSettingsProvider =
    StateNotifierProvider<ReadingSettingsNotifier, ReadingSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ReadingSettingsNotifier(_StorageProxy(prefs));
});

/// Derived provider that resolves the current [ReadingThemeData].
/// Widgets should watch this to react to theme changes.
final readingThemeProvider = Provider<ReadingThemeData>((ref) {
  final settings = ref.watch(readingSettingsProvider);
  return ReadingThemeData.forMode(settings.theme);
});
