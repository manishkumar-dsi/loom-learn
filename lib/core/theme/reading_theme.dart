import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/reading_settings.dart';
import '../../data/models/text_highlight.dart';

/// Complete visual specification for one reading mode.
///
/// Widgets access the active theme via [readingThemeDataOf] or through the
/// `readingThemeProvider` Riverpod provider. Never hardcode colors from
/// [AppColors] inside reading-view widgets — use this class instead so that
/// theme switching works automatically.
class ReadingThemeData {
  // ── Surface colors ────────────────────────────────────────────────────────
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceHighest;

  // ── Borders ───────────────────────────────────────────────────────────────
  final Color border;
  final Color borderSubtle;

  // ── Text ──────────────────────────────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;

  // ── Accent (primary interactive color) ───────────────────────────────────
  final Color accent;
  final Color accentLight;
  final Color accentDim;
  final Color accentSurface;

  // ── Link / exploration color ──────────────────────────────────────────────
  final Color link;
  final Color linkLight;
  final Color linkSurface;

  // ── Semantic ──────────────────────────────────────────────────────────────
  final Color error;
  final Color errorSurface;
  final Color success;

  // ── Reading-specific ──────────────────────────────────────────────────────
  /// Background for user question cards.
  final Color questionCardBg;

  /// Border for user question cards.
  final Color questionCardBorder;

  /// Section divider between Q&A pairs.
  final Color sectionDivider;

  /// Highlight color for text that has been explored.
  final Color exploredHighlight;
  final Color highlightYellow;
  final Color highlightGreen;
  final Color highlightPink;
  final Color highlightAqua;
  final Color highlightOrange;

  /// True for dark / night themes (affects system overlay style, icon colors).
  final bool isDark;

  /// System UI overlay style to apply while this theme is active.
  final SystemUiOverlayStyle systemOverlayStyle;

  const ReadingThemeData({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceHighest,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.accent,
    required this.accentLight,
    required this.accentDim,
    required this.accentSurface,
    required this.link,
    required this.linkLight,
    required this.linkSurface,
    required this.error,
    required this.errorSurface,
    required this.success,
    required this.questionCardBg,
    required this.questionCardBorder,
    required this.sectionDivider,
    required this.exploredHighlight,
    required this.highlightYellow,
    required this.highlightGreen,
    required this.highlightPink,
    required this.highlightAqua,
    required this.highlightOrange,
    required this.isDark,
    required this.systemOverlayStyle,
  });

  // ── Derived helpers ───────────────────────────────────────────────────────

  /// Gradient derived from accent and link colors.
  LinearGradient get accentGradient => LinearGradient(
        colors: [accent, link],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // ── Theme presets ─────────────────────────────────────────────────────────

  /// Crisp white — works like a printed page in daylight.
  static const white = ReadingThemeData(
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF2F2F7),
    surfaceHighest: Color(0xFFE5E5EA),
    border: Color(0xFFD1D1D6),
    borderSubtle: Color(0xFFE5E5EA),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF48484A),
    textMuted: Color(0xFF8E8E93),
    textDisabled: Color(0xFFC7C7CC),
    accent: Color(0xFF5856D6),
    accentLight: Color(0xFF7A79E0),
    accentDim: Color(0xFF3634A3),
    accentSurface: Color(0xFFEEEDFB),
    link: Color(0xFF007AFF),
    linkLight: Color(0xFF409CFF),
    linkSurface: Color(0xFFE1F0FF),
    error: Color(0xFFFF3B30),
    errorSurface: Color(0xFFFFEBE9),
    success: Color(0xFF34C759),
    questionCardBg: Color(0xFFF2F2F7),
    questionCardBorder: Color(0xFFD1D1D6),
    sectionDivider: Color(0xFFE5E5EA),
    exploredHighlight: Color(0xFFFFEE00),
    highlightYellow: Color(0xFFFFE07A),
    highlightGreen: Color(0xFFB9F08F),
    highlightPink: Color(0xFFF9B3E5),
    highlightAqua: Color(0xFF8BE8E0),
    highlightOrange: Color(0xFFFFBE7A),
    isDark: false,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
  );

  /// Warm sepia — mimics aged paper; reduces eye strain during long sessions.
  static const sepia = ReadingThemeData(
    background: Color(0xFFF8EDD9),
    surface: Color(0xFFF2E4C4),
    surfaceElevated: Color(0xFFEDD9AE),
    surfaceHighest: Color(0xFFE4CC96),
    border: Color(0xFFD4B896),
    borderSubtle: Color(0xFFE4CC96),
    textPrimary: Color(0xFF3D2B1F),
    textSecondary: Color(0xFF6B4C36),
    textMuted: Color(0xFF9A7560),
    textDisabled: Color(0xFFC4A882),
    accent: Color(0xFF8B5E3C),
    accentLight: Color(0xFFAA7A56),
    accentDim: Color(0xFF6D4A2F),
    accentSurface: Color(0xFFF5E0CC),
    link: Color(0xFF996633),
    linkLight: Color(0xFFBA8050),
    linkSurface: Color(0xFFF5E8D4),
    error: Color(0xFFCC3333),
    errorSurface: Color(0xFFF9E5E5),
    success: Color(0xFF4A7C59),
    questionCardBg: Color(0xFFF2E4C4),
    questionCardBorder: Color(0xFFCBAA78),
    sectionDivider: Color(0xFFD4B896),
    exploredHighlight: Color(0xFFFFDE73),
    highlightYellow: Color(0xFFF1D168),
    highlightGreen: Color(0xFFBFD67A),
    highlightPink: Color(0xFFE7AFCC),
    highlightAqua: Color(0xFF7ECAC2),
    highlightOrange: Color(0xFFE8A85E),
    isDark: false,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
  );

  /// Deep charcoal — comfortable in low light, easy on the eyes.
  static const dark = ReadingThemeData(
    background: Color(0xFF131313),
    surface: Color(0xFF1E1E1E),
    surfaceElevated: Color(0xFF2A2A2A),
    surfaceHighest: Color(0xFF363636),
    border: Color(0xFF383838),
    borderSubtle: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFE8E8E8),
    textSecondary: Color(0xFFA8A8A8),
    textMuted: Color(0xFF707070),
    textDisabled: Color(0xFF484848),
    accent: Color(0xFF7C3AED),
    accentLight: Color(0xFF9F67F5),
    accentDim: Color(0xFF4C1D95),
    accentSurface: Color(0xFF1E1035),
    link: Color(0xFF38BDF8),
    linkLight: Color(0xFF7DD3FC),
    linkSurface: Color(0xFF082032),
    error: Color(0xFFFF6B6B),
    errorSurface: Color(0xFF2D1515),
    success: Color(0xFF4ADE80),
    questionCardBg: Color(0xFF252525),
    questionCardBorder: Color(0xFF3A3A3A),
    sectionDivider: Color(0xFF2E2E2E),
    exploredHighlight: Color(0xFF7C3AED40),
    highlightYellow: Color(0xFF8A6A1F),
    highlightGreen: Color(0xFF295C34),
    highlightPink: Color(0xFF6A3358),
    highlightAqua: Color(0xFF1F6B63),
    highlightOrange: Color(0xFF8A5A1F),
    isDark: true,
    systemOverlayStyle: SystemUiOverlayStyle.light,
  );

  /// Pure OLED black — saves battery on AMOLED screens; ideal for night.
  static const night = ReadingThemeData(
    background: Color(0xFF000000),
    surface: Color(0xFF0D0D0D),
    surfaceElevated: Color(0xFF1A1A1A),
    surfaceHighest: Color(0xFF262626),
    border: Color(0xFF2A2A2A),
    borderSubtle: Color(0xFF1A1A1A),
    textPrimary: Color(0xFFB8B8B8),
    textSecondary: Color(0xFF808080),
    textMuted: Color(0xFF4D4D4D),
    textDisabled: Color(0xFF333333),
    accent: Color(0xFF9F67F5),
    accentLight: Color(0xFFB794F4),
    accentDim: Color(0xFF553C9A),
    accentSurface: Color(0xFF140C28),
    link: Color(0xFF60A5FA),
    linkLight: Color(0xFF93C5FD),
    linkSurface: Color(0xFF071628),
    error: Color(0xFFFC8181),
    errorSurface: Color(0xFF1E0E0E),
    success: Color(0xFF68D391),
    questionCardBg: Color(0xFF111111),
    questionCardBorder: Color(0xFF2A2A2A),
    sectionDivider: Color(0xFF1A1A1A),
    exploredHighlight: Color(0xFF9F67F540),
    highlightYellow: Color(0xFF6E5317),
    highlightGreen: Color(0xFF1E4A2A),
    highlightPink: Color(0xFF552947),
    highlightAqua: Color(0xFF175550),
    highlightOrange: Color(0xFF6E4517),
    isDark: true,
    systemOverlayStyle: SystemUiOverlayStyle.light,
  );

  // ── Factory ───────────────────────────────────────────────────────────────

  static ReadingThemeData forMode(ReadingThemeMode mode) => switch (mode) {
        ReadingThemeMode.white => white,
        ReadingThemeMode.sepia => sepia,
        ReadingThemeMode.dark => dark,
        ReadingThemeMode.night => night,
      };

  Color highlightColor(HighlightColor color) => switch (color) {
        HighlightColor.yellow => highlightYellow,
        HighlightColor.green => highlightGreen,
        HighlightColor.pink => highlightPink,
        HighlightColor.aqua => highlightAqua,
        HighlightColor.orange => highlightOrange,
      };

  // ── MaterialApp ThemeData bridge ──────────────────────────────────────────

  /// Produces a [ThemeData] compatible with [MaterialApp.theme] so that
  /// platform widgets (dialogs, drawers, etc.) also respect the active theme.
  ThemeData toMaterialTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: isDark ? Colors.white : Colors.white,
        secondary: link,
        onSecondary: isDark ? Colors.black : Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: error,
        onError: Colors.white,
        outline: border,
        surfaceContainerHighest: surfaceElevated,
      ),
      scaffoldBackgroundColor: background,
      cardColor: surface,
      dividerColor: border,
      fontFamily: 'System',
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: systemOverlayStyle,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textSecondary, size: 22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: const Color(0xFF3A7BD5).withValues(alpha: 0.45),
        selectionHandleColor: const Color(0xFF3A7BD5),
      ),
      dialogBackgroundColor: surfaceElevated,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(border),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(4),
      ),
    );
  }
}
