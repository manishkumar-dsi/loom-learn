import 'package:flutter/material.dart';

/// Loom Learn colour system — a refined dark palette with violet/cyan accents.
abstract final class AppColors {
  // ── Backgrounds ────────────────────────────────────────────────────────
  static const background = Color(0xFF0D0D0D);
  static const surface = Color(0xFF171717);
  static const surfaceElevated = Color(0xFF1E1E1E);
  static const surfaceHighest = Color(0xFF2A2A2A);

  // ── Borders / Dividers ─────────────────────────────────────────────────
  static const border = Color(0xFF2D2D2D);
  static const borderSubtle = Color(0xFF1F1F1F);

  // ── Text ───────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFECECEC);
  static const textSecondary = Color(0xFFA0A0A0);
  static const textMuted = Color(0xFF6B6B6B);
  static const textDisabled = Color(0xFF404040);

  // ── Accent — violet (primary) ──────────────────────────────────────────
  static const accent = Color(0xFF7C3AED);
  static const accentLight = Color(0xFF9F67F5);
  static const accentDim = Color(0xFF4C1D95);
  static const accentSurface = Color(0xFF1A0B35);

  // ── Accent — cyan (links / exploration) ───────────────────────────────
  static const link = Color(0xFF22D3EE);
  static const linkLight = Color(0xFF67E8F9);
  static const linkSurface = Color(0xFF082832);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFF2A0A0A);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);

  // ── User message bubble ────────────────────────────────────────────────
  static const userBubble = Color(0xFF2D2D2D);
  static const userBubbleBorder = Color(0xFF3F3F3F);

  // ── Gradients ──────────────────────────────────────────────────────────
  static const accentGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF22D3EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const sidebarGradient = LinearGradient(
    colors: [Color(0xFF171717), Color(0xFF111111)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
