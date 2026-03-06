/// All user-configurable reading preferences.
/// Persisted to SharedPreferences as JSON.
library;

// ── Enumerations ──────────────────────────────────────────────────────────────

enum ReadingThemeMode {
  /// Bright white — ideal for daylight / well-lit rooms.
  white,

  /// Warm paper tone — easier on the eyes for long sessions.
  sepia,

  /// Deep charcoal — comfortable in dim light.
  dark,

  /// Pure OLED black — battery-saving, zero-light reading.
  night;

  String get label => switch (this) {
        white => 'White',
        sepia => 'Sepia',
        dark => 'Dark',
        night => 'Night',
      };
}

enum ReadingFontFamily {
  sansSerif,
  serif,
  monospace;

  String get label => switch (this) {
        sansSerif => 'Sans',
        serif => 'Serif',
        monospace => 'Mono',
      };

  /// Resolved font family string passed to Flutter text style.
  String get fontFamily => switch (this) {
        sansSerif => 'System',
        serif => 'Georgia',
        monospace => 'Courier New',
      };
}

enum ReadingLineSpacing {
  compact,
  normal,
  wide;

  String get label => switch (this) {
        compact => 'Compact',
        normal => 'Normal',
        wide => 'Wide',
      };

  double get lineHeight => switch (this) {
        compact => 1.45,
        normal => 1.70,
        wide => 2.05,
      };
}

enum ReadingMargin {
  narrow,
  normal,
  wide;

  double get horizontal => switch (this) {
        narrow => 16.0,
        normal => 24.0,
        wide => 40.0,
      };
}

// ── Model ─────────────────────────────────────────────────────────────────────

class ReadingSettings {
  final ReadingThemeMode theme;
  final ReadingFontFamily fontFamily;
  final ReadingLineSpacing lineSpacing;
  final ReadingMargin margin;
  final bool distractionFreeMode;

  /// Body font size in logical pixels. Range: 13–24.
  final double fontSize;

  const ReadingSettings({
    this.theme = ReadingThemeMode.dark,
    this.fontFamily = ReadingFontFamily.sansSerif,
    this.lineSpacing = ReadingLineSpacing.normal,
    this.margin = ReadingMargin.normal,
    this.distractionFreeMode = false,
    this.fontSize = 16.0,
  });

  static const _kDefaultFontSize = 16.0;

  ReadingSettings copyWith({
    ReadingThemeMode? theme,
    ReadingFontFamily? fontFamily,
    ReadingLineSpacing? lineSpacing,
    ReadingMargin? margin,
    bool? distractionFreeMode,
    double? fontSize,
  }) {
    return ReadingSettings(
      theme: theme ?? this.theme,
      fontFamily: fontFamily ?? this.fontFamily,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      margin: margin ?? this.margin,
      distractionFreeMode: distractionFreeMode ?? this.distractionFreeMode,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'fontFamily': fontFamily.name,
        'lineSpacing': lineSpacing.name,
        'margin': margin.name,
        'distractionFreeMode': distractionFreeMode,
        'fontSize': fontSize,
      };

  factory ReadingSettings.fromJson(Map<String, dynamic> json) {
    return ReadingSettings(
      theme: ReadingThemeMode.values.byName(
        json['theme'] as String? ?? ReadingThemeMode.dark.name,
      ),
      fontFamily: ReadingFontFamily.values.byName(
        json['fontFamily'] as String? ?? ReadingFontFamily.sansSerif.name,
      ),
      lineSpacing: ReadingLineSpacing.values.byName(
        json['lineSpacing'] as String? ?? ReadingLineSpacing.normal.name,
      ),
      margin: ReadingMargin.values.byName(
        json['margin'] as String? ?? ReadingMargin.normal.name,
      ),
      distractionFreeMode: json['distractionFreeMode'] as bool? ?? false,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? _kDefaultFontSize,
    );
  }
}
