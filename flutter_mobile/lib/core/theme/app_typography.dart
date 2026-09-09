/// Kioku typography system — Fraunces (display/serif) + Inter/NotoSansJP (body)
/// Built from AppColors for dynamic theming
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

@immutable
class AppTypography {
  const AppTypography({
    required this.display,
    required this.displayMobile,
    required this.heading,
    required this.subheading,
    required this.editorialQuote,
    required this.body,
    required this.bodyMedium,
    required this.bodySemiBold,
    required this.bodyBold,
    required this.bodySmall,
    required this.caption,
    required this.content,
    required this.label,
    required this.kanjiTitle,
    required this.button,
    required this.buttonSmall,
  });

  // Display styles
  final TextStyle display;
  final TextStyle displayMobile;
  final TextStyle heading;
  final TextStyle subheading;
  final TextStyle editorialQuote;

  // Body styles
  final TextStyle body;
  final TextStyle bodyMedium;
  final TextStyle bodySemiBold;
  final TextStyle bodyBold;
  final TextStyle bodySmall;
  final TextStyle caption;
  final TextStyle content;

  // UI styles
  final TextStyle label;
  final TextStyle kanjiTitle;
  final TextStyle button;
  final TextStyle buttonSmall;

  /// Builds the complete typography scale from colors
  static AppTypography fromColors(AppColors colors) {
    // Fraunces for display/serif (warm, editorial)
    final displayFont = GoogleFonts.frauncesTextTheme().displayLarge!;
    final displayMediumFont = GoogleFonts.frauncesTextTheme().displayMedium!;
    final headlineFont = GoogleFonts.frauncesTextTheme().headlineLarge!;
    final titleFont = GoogleFonts.frauncesTextTheme().titleLarge!;
    final bodyFont = GoogleFonts.frauncesTextTheme().bodyLarge!;

    // Inter for body/UI (clean, legible)
    final interTextTheme = GoogleFonts.interTextTheme();

    return AppTypography(
      // Display — Fraunces SemiBold, large
      display: displayFont.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: colors.ink,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      // Mobile display — slightly smaller
      displayMobile: displayMediumFont.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w500,
        color: colors.ink,
        letterSpacing: -0.3,
        height: 1.25,
      ),
      // Heading — Fraunces SemiBold
      heading: headlineFont.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: colors.ink,
        letterSpacing: -0.2,
        height: 1.3,
      ),
      // Subheading — Fraunces Medium
      subheading: titleFont.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: colors.ink,
        letterSpacing: -0.1,
        height: 1.4,
      ),
      // Editorial quote — Fraunces Italic
      editorialQuote: bodyFont.copyWith(
        fontSize: 15,
        fontStyle: FontStyle.italic,
        color: colors.ink,
        height: 1.6,
        letterSpacing: 0,
      ),
      // Body — Inter Regular
      body: interTextTheme.bodyLarge!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.ink,
        height: 1.57,
        letterSpacing: 0,
      ),
      // Body Medium — Inter Medium
      bodyMedium: interTextTheme.bodyLarge!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.ink,
        height: 1.57,
        letterSpacing: 0,
      ),
      // Body SemiBold — Inter SemiBold
      bodySemiBold: interTextTheme.bodyLarge!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colors.ink,
        height: 1.57,
        letterSpacing: 0,
      ),
      // Body Bold — Inter Bold
      bodyBold: interTextTheme.bodyLarge!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: colors.ink,
        height: 1.57,
        letterSpacing: 0,
      ),
      // Body Small — Inter Regular small
      bodySmall: interTextTheme.bodySmall!.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.ink,
        height: 1.42,
        letterSpacing: 0,
      ),
      // Caption — Inter Regular, muted
      caption: interTextTheme.bodySmall!.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.inkMuted,
        height: 1.33,
        letterSpacing: 0,
      ),
      // Content — Inter Medium, readable
      content: interTextTheme.bodyLarge!.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: colors.ink,
        height: 1.6,
        letterSpacing: 0,
      ),
      // Label — Inter SemiBold, uppercase, tight tracking
      label: interTextTheme.labelSmall!.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: colors.inkMuted,
        letterSpacing: 1.2,
        height: 1.2,
      ),
      // Kanji/Japanese titles — Fraunces Regular, accent color
      kanjiTitle: bodyFont.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: colors.accent,
        height: 1.4,
        letterSpacing: 0,
      ),
      // Button text — Inter Medium
      button: interTextTheme.labelLarge!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        height: 1.2,
      ),
      // Small button text
      buttonSmall: interTextTheme.labelSmall!.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.2,
      ),
    );
  }

  /// Lerp for smooth theme transitions
  static AppTypography lerp(AppTypography a, AppTypography b, double t) {
    return AppTypography(
      display: TextStyle.lerp(a.display, b.display, t)!,
      displayMobile: TextStyle.lerp(a.displayMobile, b.displayMobile, t)!,
      heading: TextStyle.lerp(a.heading, b.heading, t)!,
      subheading: TextStyle.lerp(a.subheading, b.subheading, t)!,
      editorialQuote: TextStyle.lerp(a.editorialQuote, b.editorialQuote, t)!,
      body: TextStyle.lerp(a.body, b.body, t)!,
      bodyMedium: TextStyle.lerp(a.bodyMedium, b.bodyMedium, t)!,
      bodySemiBold: TextStyle.lerp(a.bodySemiBold, b.bodySemiBold, t)!,
      bodyBold: TextStyle.lerp(a.bodyBold, b.bodyBold, t)!,
      bodySmall: TextStyle.lerp(a.bodySmall, b.bodySmall, t)!,
      caption: TextStyle.lerp(a.caption, b.caption, t)!,
      content: TextStyle.lerp(a.content, b.content, t)!,
      label: TextStyle.lerp(a.label, b.label, t)!,
      kanjiTitle: TextStyle.lerp(a.kanjiTitle, b.kanjiTitle, t)!,
      button: TextStyle.lerp(a.button, b.button, t)!,
      buttonSmall: TextStyle.lerp(a.buttonSmall, b.buttonSmall, t)!,
    );
  }
}