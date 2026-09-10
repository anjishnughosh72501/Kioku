/// Kioku color palette — Forest Dark (default) & Coffee Light themes
/// Matches the tactile Japanese scrapbook aesthetic
library;

import 'package:flutter/material.dart';

@immutable
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.accentDark,
    required this.accentSoft,
    required this.accentContainer,
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.divider,
    required this.dividerLight,
    required this.overlay,
    required this.glassBorder,
    required this.danger,
    required this.success,
    required this.shadow,
    required this.shadowDark,
    required this.washiTape,
    required this.washiTapeMatcha,
    required this.washiTapePeach,
    required this.hankoRed,
    required this.sage,
    required this.sageDark,
    required this.sageLight,
    required this.sageBackground,
    required this.sageBorder,
    required this.amber,
    required this.amberContainer,
  });

  // Core surfaces
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;

  // Primary accent
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color accentDark;
  final Color accentSoft;
  final Color accentContainer;

  // Text
  final Color ink;
  final Color inkMuted;
  final Color inkSubtle;

  // Structural
  final Color divider;
  final Color dividerLight;

  // Overlay / Glass
  final Color overlay;
  final Color glassBorder;

  // Status
  final Color danger;
  final Color success;

  // Shadows
  final Color shadow;
  final Color shadowDark;

  // Washi tape variants
  final Color washiTape;
  final Color washiTapeMatcha;
  final Color washiTapePeach;

  // Hanko stamp
  final Color hankoRed;

  // Sage variants (legacy alias support)
  final Color sage;
  final Color sageDark;
  final Color sageLight;
  final Color sageBackground;
  final Color sageBorder;

  // Amber variants
  final Color amber;
  final Color amberContainer;

  // Theme mode for StatusBar / system UI
  Brightness get brightness => background.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark;

  // Espresso Dark (default) — deep coffee beans, warm mocha surfaces, golden caramel crema
  static const AppColors forestDark = AppColors(
    background: Color(0xFF140E0A), // Deep roasted bean background
    surface: Color(0xFF1E1611),    // Warm dark mocha
    surfaceElevated: Color(0xFF281E17), // Rich coffee crema card
    surfaceContainerLowest: Color(0xFF0D0906), // Extra dark espresso
    surfaceContainerLow: Color(0xFF18110D),
    surfaceContainer: Color(0xFF221913),
    surfaceContainerHigh: Color(0xFF2D221A),
    surfaceContainerHighest: Color(0xFF382B21),
    primary: Color(0xFFDCA468),     // Golden caramel crema accent
    primaryDark: Color(0xFFB87F44), // Cinnamon roast
    accent: Color(0xFFE8BD8A),      // Warm froth latte accent
    accentDark: Color(0xFFC78F56),  // Hazelnut brown
    accentSoft: Color(0xFF382518),  // Subtle roasted brown container
    accentContainer: Color(0xFF422C1D),
    ink: Color(0xFFFAF6F0),         // Steamed milk white text
    inkMuted: Color(0xFFA8988C),    // Soft warm oat grey
    inkSubtle: Color(0xFF9E907A),   // Muted roasted taupe (WCAG AA compliant)
    divider: Color(0xFF33251B),     // Subtle roast border
    dividerLight: Color(0xFF3F2F24),
    overlay: Color(0xCC140E0A),     // rgba(20, 14, 10, 0.80)
    glassBorder: Color(0x2BDCA468), // rgba(220, 164, 104, 0.17)
    danger: Color(0xFFDE7468),      // Terracotta red
    success: Color(0xFF7CB883),     // Matcha / green bean
    shadow: Color(0x80000000),      // rgba(0, 0, 0, 0.50)
    shadowDark: Color(0xB3000000),  // rgba(0, 0, 0, 0.70)
    washiTape: Color(0xB33D2A1C),   // Rich mocha washi tape
    washiTapeMatcha: Color(0x995C402B),
    washiTapePeach: Color(0x99572C20),
    hankoRed: Color(0xFFC95B48),
    sage: Color(0xFFDCA468),        // Map to caramel crema
    sageDark: Color(0xFFB87F44),
    sageLight: Color(0xFF382518),
    sageBackground: Color(0xFF1E1611),
    sageBorder: Color(0xFF3F2F24),
    amber: Color(0xFFE5B358),
    amberContainer: Color(0xFF3B2A10),
  );

  // Latte Light — warm parchment, frothed milk, rich espresso typography
  static const AppColors coffeeLight = AppColors(
    background: Color(0xFFFBF7F0), // Warm steamed milk / ivory parchment
    surface: Color(0xFFF3ECE0),    // Light oat froth
    surfaceElevated: Color(0xFFFFFFFF), // Crisp paper card
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF8F3EA),
    surfaceContainer: Color(0xFFEEE5D5),
    surfaceContainerHigh: Color(0xFFE4D7C3),
    surfaceContainerHighest: Color(0xFFD9C9B1),
    primary: Color(0xFF683D21),     // Bold brewed espresso primary
    primaryDark: Color(0xFF4C2B16), // Dark roast
    accent: Color(0xFF8B532C),      // Cinnamon latte
    accentDark: Color(0xFF683D21),
    accentSoft: Color(0xFFF0DFC8),  // Light caramel froth
    accentContainer: Color(0xFFEAD4B9),
    ink: Color(0xFF281810),         // Dark roast coffee ink
    inkMuted: Color(0xFF7A6455),    // Cocoa brown text
    inkSubtle: Color(0xFFA59284),   // Subtle oat brown
    divider: Color(0xFFE3D4C0),     // Soft biscuit divider
    dividerLight: Color(0xFFEBE0D0),
    overlay: Color(0xE6FBF7F0),     // rgba(251, 247, 240, 0.90)
    glassBorder: Color(0x1F683D21), // rgba(104, 61, 33, 0.12)
    danger: Color(0xFFBA4736),
    success: Color(0xFF488252),
    shadow: Color(0x1F301C10),      // rgba(48, 28, 16, 0.12)
    shadowDark: Color(0x38301C10),  // rgba(48, 28, 16, 0.22)
    washiTape: Color(0xD9E8D9C2),
    washiTapeMatcha: Color(0xBFDFCDB6),
    washiTapePeach: Color(0xBFF0D2C0),
    hankoRed: Color(0xFFB84435),
    sage: Color(0xFF8B532C),
    sageDark: Color(0xFF683D21),
    sageLight: Color(0xFFF0DFC8),
    sageBackground: Color(0xFFF3ECE0),
    sageBorder: Color(0xFFDCC8B0),
    amber: Color(0xFFBF8826),
    amberContainer: Color(0xFFF5E4BE),
  );

  // Lerp for smooth theme transitions
  static AppColors lerp(AppColors a, AppColors b, double t) {
    return AppColors(
      background: Color.lerp(a.background, b.background, t)!,
      surface: Color.lerp(a.surface, b.surface, t)!,
      surfaceElevated: Color.lerp(a.surfaceElevated, b.surfaceElevated, t)!,
      surfaceContainerLowest: Color.lerp(a.surfaceContainerLowest, b.surfaceContainerLowest, t)!,
      surfaceContainerLow: Color.lerp(a.surfaceContainerLow, b.surfaceContainerLow, t)!,
      surfaceContainer: Color.lerp(a.surfaceContainer, b.surfaceContainer, t)!,
      surfaceContainerHigh: Color.lerp(a.surfaceContainerHigh, b.surfaceContainerHigh, t)!,
      surfaceContainerHighest: Color.lerp(a.surfaceContainerHighest, b.surfaceContainerHighest, t)!,
      primary: Color.lerp(a.primary, b.primary, t)!,
      primaryDark: Color.lerp(a.primaryDark, b.primaryDark, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
      accentDark: Color.lerp(a.accentDark, b.accentDark, t)!,
      accentSoft: Color.lerp(a.accentSoft, b.accentSoft, t)!,
      accentContainer: Color.lerp(a.accentContainer, b.accentContainer, t)!,
      ink: Color.lerp(a.ink, b.ink, t)!,
      inkMuted: Color.lerp(a.inkMuted, b.inkMuted, t)!,
      inkSubtle: Color.lerp(a.inkSubtle, b.inkSubtle, t)!,
      divider: Color.lerp(a.divider, b.divider, t)!,
      dividerLight: Color.lerp(a.dividerLight, b.dividerLight, t)!,
      overlay: Color.lerp(a.overlay, b.overlay, t)!,
      glassBorder: Color.lerp(a.glassBorder, b.glassBorder, t)!,
      danger: Color.lerp(a.danger, b.danger, t)!,
      success: Color.lerp(a.success, b.success, t)!,
      shadow: Color.lerp(a.shadow, b.shadow, t)!,
      shadowDark: Color.lerp(a.shadowDark, b.shadowDark, t)!,
      washiTape: Color.lerp(a.washiTape, b.washiTape, t)!,
      washiTapeMatcha: Color.lerp(a.washiTapeMatcha, b.washiTapeMatcha, t)!,
      washiTapePeach: Color.lerp(a.washiTapePeach, b.washiTapePeach, t)!,
      hankoRed: Color.lerp(a.hankoRed, b.hankoRed, t)!,
      sage: Color.lerp(a.sage, b.sage, t)!,
      sageDark: Color.lerp(a.sageDark, b.sageDark, t)!,
      sageLight: Color.lerp(a.sageLight, b.sageLight, t)!,
      sageBackground: Color.lerp(a.sageBackground, b.sageBackground, t)!,
      sageBorder: Color.lerp(a.sageBorder, b.sageBorder, t)!,
      amber: Color.lerp(a.amber, b.amber, t)!,
      amberContainer: Color.lerp(a.amberContainer, b.amberContainer, t)!,
    );
  }
}