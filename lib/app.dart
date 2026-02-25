import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/providers/reading_settings_provider.dart';
import 'presentation/screens/home_screen.dart';

/// Root widget. Watches [readingThemeProvider] so the entire MaterialApp
/// re-themes instantly whenever the user changes reading mode in the Aa panel.
class LoomLearnApp extends ConsumerWidget {
  const LoomLearnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingTheme = ref.watch(readingThemeProvider);
    final materialTheme = readingTheme.toMaterialTheme();

    return MaterialApp(
      title: 'Loom Learn',
      debugShowCheckedModeBanner: false,
      theme: materialTheme,
      darkTheme: materialTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
