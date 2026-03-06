import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/reading_theme.dart';
import '../../data/models/reading_settings.dart';
import '../providers/reading_settings_provider.dart';

/// Opens the Kindle-style "Aa" typography bottom sheet.
void showReadingToolbar(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ReadingToolbarSheet(),
  );
}

class _ReadingToolbarSheet extends ConsumerWidget {
  const _ReadingToolbarSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(readingThemeProvider);
    final settings = ref.watch(readingSettingsProvider);
    final notifier = ref.read(readingSettingsProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Text(
                    'Reading Settings',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: theme.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: theme.border),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Font Size ──────────────────────────────────────────
                  _SectionLabel(label: 'Font Size', theme: theme),
                  const SizedBox(height: 10),
                  _FontSizeControl(
                    value: settings.fontSize,
                    theme: theme,
                    onChanged: notifier.setFontSize,
                  ),

                  const SizedBox(height: 24),

                  // ── Font Family ────────────────────────────────────────
                  _SectionLabel(label: 'Typeface', theme: theme),
                  const SizedBox(height: 10),
                  _FontFamilyPicker(
                    selected: settings.fontFamily,
                    theme: theme,
                    onChanged: notifier.setFontFamily,
                  ),

                  const SizedBox(height: 24),

                  // ── Line Spacing ───────────────────────────────────────
                  _SectionLabel(label: 'Line Spacing', theme: theme),
                  const SizedBox(height: 10),
                  _TriStateToggle<ReadingLineSpacing>(
                    values: ReadingLineSpacing.values,
                    selected: settings.lineSpacing,
                    label: (v) => v.label,
                    theme: theme,
                    onChanged: notifier.setLineSpacing,
                  ),

                  const SizedBox(height: 24),

                  // ── Margins ────────────────────────────────────────────
                  _SectionLabel(label: 'Margins', theme: theme),
                  const SizedBox(height: 10),
                  _TriStateToggle<ReadingMargin>(
                    values: ReadingMargin.values,
                    selected: settings.margin,
                    label: (v) => v.name.capitalize(),
                    theme: theme,
                    onChanged: notifier.setMargin,
                  ),

                  const SizedBox(height: 24),

                  // ── Theme ──────────────────────────────────────────────
                  _SectionLabel(label: 'Theme', theme: theme),
                  const SizedBox(height: 12),
                  _ThemePicker(
                    selected: settings.theme,
                    onChanged: notifier.setTheme,
                  ),

                  const SizedBox(height: 24),

                  _SectionLabel(label: 'Reading Mode', theme: theme),
                  const SizedBox(height: 10),
                  _ModeToggle(
                    enabled: settings.distractionFreeMode,
                    theme: theme,
                    onChanged: notifier.setDistractionFreeMode,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Font Size ─────────────────────────────────────────────────────────────────

class _FontSizeControl extends StatelessWidget {
  final double value;
  final ReadingThemeData theme;
  final void Function(double) onChanged;

  const _FontSizeControl({
    required this.value,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'A',
          style: TextStyle(
            color: theme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: theme.accent,
              inactiveTrackColor: theme.border,
              thumbColor: theme.accent,
              overlayColor: theme.accent.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: value,
              min: 13,
              max: 24,
              divisions: 11,
              onChanged: onChanged,
            ),
          ),
        ),
        Text(
          'A',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.border),
          ),
          child: Text(
            '${value.round()}',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Font Family ───────────────────────────────────────────────────────────────

class _FontFamilyPicker extends StatelessWidget {
  final ReadingFontFamily selected;
  final ReadingThemeData theme;
  final void Function(ReadingFontFamily) onChanged;

  const _FontFamilyPicker({
    required this.selected,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ReadingFontFamily.values.map((family) {
        final isSelected = family == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(family),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? theme.accentSurface : theme.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? theme.accent.withValues(alpha: 0.6)
                      : theme.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Ag',
                    style: TextStyle(
                      fontFamily: family == ReadingFontFamily.sansSerif
                          ? null
                          : family.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? theme.accentLight : theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    family.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? theme.accent : theme.textMuted,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Tri-state toggle (line spacing, margins) ──────────────────────────────────

class _TriStateToggle<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ReadingThemeData theme;
  final void Function(T) onChanged;

  const _TriStateToggle({
    required this.values,
    required this.selected,
    required this.label,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: values.map((v) {
          final isSelected = v == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? theme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  label(v),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : theme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Theme Picker ──────────────────────────────────────────────────────────────

class _ThemePicker extends StatelessWidget {
  final ReadingThemeMode selected;
  final void Function(ReadingThemeMode) onChanged;

  const _ThemePicker({required this.selected, required this.onChanged});

  static const _themes = [
    (
      mode: ReadingThemeMode.white,
      bg: Color(0xFFFAFAFA),
      text: Color(0xFF1C1C1E),
      accent: Color(0xFF5856D6),
    ),
    (
      mode: ReadingThemeMode.sepia,
      bg: Color(0xFFF8EDD9),
      text: Color(0xFF3D2B1F),
      accent: Color(0xFF8B5E3C),
    ),
    (
      mode: ReadingThemeMode.dark,
      bg: Color(0xFF131313),
      text: Color(0xFFE8E8E8),
      accent: Color(0xFF7C3AED),
    ),
    (
      mode: ReadingThemeMode.night,
      bg: Color(0xFF000000),
      text: Color(0xFFB8B8B8),
      accent: Color(0xFF9F67F5),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _themes.map((t) {
        final isSelected = t.mode == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(t.mode),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  // Theme preview swatch
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 52,
                    decoration: BoxDecoration(
                      color: t.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? t.accent : const Color(0xFF555555),
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Aa',
                        style: TextStyle(
                          color: t.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.mode.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? t.accent : const Color(0xFF888888),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: t.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final ReadingThemeData theme;

  const _SectionLabel({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: theme.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool enabled;
  final ReadingThemeData theme;
  final void Function(bool) onChanged;

  const _ModeToggle({
    required this.enabled,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book_rounded, size: 18, color: theme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distraction-free mode',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hide chat chrome and read like a book.',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: theme.accent,
          ),
        ],
      ),
    );
  }
}

extension _StringExt on String {
  String capitalize() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;
}
