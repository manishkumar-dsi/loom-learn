import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/storage_service.dart';

/// Provides a [SharedPreferences] instance that must be initialised before
/// [runApp] by calling [SharedPreferences.getInstance()].
///
/// Override this in tests with a fake implementation.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden before use. '
    'Call ProviderScope(overrides: [...]) with the resolved instance.',
  );
});

final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StorageService(prefs: prefs);
});
