import 'package:flutter/material.dart';

/// Medsafe brand palette — semantic colors with light + dark variants.
/// Access via: AppColors.of(context).primary
class AppColors extends ThemeExtension<AppColors> {
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color accent;

  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color error;
  final Color errorBg;

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color card;
  final Color divider;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnPrimary;

  final Color shadow;

  const AppColors({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.accent,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.error,
    required this.errorBg,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnPrimary,
    required this.shadow,
  });

  // ── LIGHT ────────────────────────────────
  static const light = AppColors(
    primary:        Color(0xFF3B82F6),
    primaryLight:   Color(0xFFDCEAFE),
    primaryDark:    Color(0xFF2563EB),
    accent:         Color(0xFF7C3AED),

    success:        Color(0xFF4DB6AC),
    successBg:      Color(0xFFE8F5F2),
    warning:        Color(0xFFFFA726),
    warningBg:      Color(0xFFFFF8E8),
    error:          Color(0xFFE57373),
    errorBg:        Color(0xFFFCECEC),

    background:     Color(0xFFF1F5F9),
    surface:        Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF8FAFC),
    card:           Color(0xFFFFFFFF),
    divider:        Color(0xFFE8ECF1),

    textPrimary:    Color(0xFF0F172A),
    textSecondary:  Color(0xFF475569),
    textTertiary:   Color(0xFF94A3B8),
    textOnPrimary:  Color(0xFFFFFFFF),

    shadow:         Color(0x08000000),
  );

  // ── DARK ─────────────────────────────────
  static const dark = AppColors(
    primary:        Color(0xFF60A5FA),
    primaryLight:   Color(0xFF1E3A5F),
    primaryDark:    Color(0xFF93C5FD),
    accent:         Color(0xFFA78BFA),

    success:        Color(0xFF80CBC4),
    successBg:      Color(0xFF0D3B35),
    warning:        Color(0xFFFFCC80),
    warningBg:      Color(0xFF5C3A10),
    error:          Color(0xFFEF9A9A),
    errorBg:        Color(0xFF5C1A1A),

    background:     Color(0xFF0F172A),
    surface:        Color(0xFF1E293B),
    surfaceVariant: Color(0xFF334155),
    card:           Color(0xFF1E293B),
    divider:        Color(0xFF334155),

    textPrimary:    Color(0xFFF1F5F9),
    textSecondary:  Color(0xFF94A3B8),
    textTertiary:   Color(0xFF64748B),
    textOnPrimary:  Color(0xFF0F172A),

    shadow:         Color(0x30000000),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? light;
  }

  @override
  ThemeExtension<AppColors> copyWith() => this;

  @override
  ThemeExtension<AppColors> lerp(covariant ThemeExtension<AppColors>? other, double t) => this;
}
