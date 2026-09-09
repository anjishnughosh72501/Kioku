/// Kioku AppTheme — Material 3 theme with claymorphism shadows and custom tokens
/// Provides both Forest Dark (default) and Coffee Light variants
library;

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

@immutable
class AppTheme {
  const AppTheme._();

  // Clay-specific shadow definitions
  static const List<BoxShadow> _clayCardShadowsDark = [
    // Outer shadow
    BoxShadow(
      color: Color(0x59000000), // rgba(0,0,0,0.35)
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
    // Inner highlight (simulated with lighter shadow)
    BoxShadow(
      color: Color(0x1AFFFFFF), // rgba(255,255,255,0.1)
      offset: Offset(0, -2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _clayCardShadowsLight = [
    BoxShadow(
      color: Color(0x1A1A2E14), // rgba(26,46,20,0.10)
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x1AFFFFFF),
      offset: Offset(0, -2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _clayPressedShadowsDark = [
    BoxShadow(
      color: Color(0x66000000), // rgba(0,0,0,0.4)
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _clayPressedShadowsLight = [
    BoxShadow(
      color: Color(0x331A2E14), // rgba(26,46,20,0.20)
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _clayFloatingShadowsDark = [
    BoxShadow(
      color: Color(0x66000000), // rgba(0,0,0,0.4)
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _clayFloatingShadowsLight = [
    BoxShadow(
      color: Color(0x331A2E14), // rgba(26,46,20,0.20)
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _claySubtleShadowsDark = [
    BoxShadow(
      color: Color(0x33000000), // rgba(0,0,0,0.2)
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> _claySubtleShadowsLight = [
    BoxShadow(
      color: Color(0x1A1A2E14), // rgba(26,46,20,0.10)
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> _cardShadows(AppColors colors) =>
      colors.brightness == Brightness.dark ? _clayCardShadowsDark : _clayCardShadowsLight;

  static List<BoxShadow> _pressedShadows(AppColors colors) =>
      colors.brightness == Brightness.dark ? _clayPressedShadowsDark : _clayPressedShadowsLight;

  static List<BoxShadow> _floatingShadows(AppColors colors) =>
      colors.brightness == Brightness.dark ? _clayFloatingShadowsDark : _clayFloatingShadowsLight;

  static List<BoxShadow> _subtleShadows(AppColors colors) =>
      colors.brightness == Brightness.dark ? _claySubtleShadowsDark : _claySubtleShadowsLight;

  // Radius tokens matching the design spec
  static const double radiusXs = 3;
  static const double radiusPhoto = 6;
  static const double radiusCard = 30;
  static const double radiusButton = 24;
  static const double radiusInput = 20;
  static const double radiusModal = 26;
  static const double radiusNavigation = 34;
  static const double radiusPill = 9999;

  // Spacing scale (8pt base)
  static const double spacingXxs = 2;
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 20;
  static const double spacingXxl = 28;
  static const double spacingXxxl = 36;

  /// Builds the complete ThemeData for a given color scheme
  static ThemeData build(AppColors colors, AppTypography typography) {
    final brightness = colors.brightness;
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.primary,
        onPrimary: isDark ? const Color(0xFF140E0A) : Colors.white,
        primaryContainer: colors.accentContainer,
        onPrimaryContainer: colors.ink,
        secondary: colors.accent,
        onSecondary: isDark ? const Color(0xFF140E0A) : Colors.white,
        secondaryContainer: colors.accentSoft,
        onSecondaryContainer: colors.ink,
        tertiary: colors.sage,
        onTertiary: Colors.white,
        tertiaryContainer: colors.sageLight,
        onTertiaryContainer: colors.ink,
        error: colors.danger,
        onError: Colors.white,
        errorContainer: colors.danger.withValues(alpha: 0.15),
        onErrorContainer: colors.danger,
        surface: colors.surface,
        onSurface: colors.ink,
        surfaceContainerLowest: colors.surfaceContainerLowest,
        surfaceContainerLow: colors.surfaceContainerLow,
        surfaceContainer: colors.surfaceContainer,
        surfaceContainerHigh: colors.surfaceContainerHigh,
        surfaceContainerHighest: colors.surfaceContainerHighest,
        onSurfaceVariant: colors.inkMuted,
        outline: colors.divider,
        outlineVariant: colors.dividerLight,
        shadow: colors.shadow,
        scrim: colors.overlay,
        inverseSurface: isDark ? colors.surfaceContainerHighest : colors.surfaceContainerLowest,
        onInverseSurface: isDark ? colors.inkMuted : colors.ink,
        inversePrimary: isDark ? colors.primaryDark : colors.primary,
      ),

      // Typography
      textTheme: TextTheme(
        displayLarge: typography.display,
        displayMedium: typography.displayMobile,
        displaySmall: typography.heading,
        headlineLarge: typography.heading,
        headlineMedium: typography.subheading,
        headlineSmall: typography.subheading.copyWith(fontSize: 18),
        titleLarge: typography.heading.copyWith(fontSize: 18),
        titleMedium: typography.bodyMedium.copyWith(fontSize: 16),
        titleSmall: typography.bodySemiBold.copyWith(fontSize: 14),
        bodyLarge: typography.content,
        bodyMedium: typography.body,
        bodySmall: typography.bodySmall,
        labelLarge: typography.button,
        labelMedium: typography.buttonSmall,
        labelSmall: typography.label,
      ).apply(
        bodyColor: colors.ink,
        displayColor: colors.ink,
      ),

      // Scaffold
      scaffoldBackgroundColor: colors.background,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surfaceElevated,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: typography.heading,
        toolbarTextStyle: typography.bodyMedium,
        iconTheme: IconThemeData(color: colors.ink, size: 24),
        actionsIconTheme: IconThemeData(color: colors.ink, size: 24),
      ),

      // Card
      cardTheme: CardThemeData(
        color: colors.surfaceContainerLow,
        elevation: 0,
        shadowColor: colors.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: colors.divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ElevatedButton (primary clay button)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: isDark ? const Color(0xFF140E0A) : Colors.white,
          disabledBackgroundColor: colors.primary.withValues(alpha: 0.5),
          disabledForegroundColor: (isDark ? const Color(0xFF140E0A) : Colors.white).withValues(alpha: 0.5),
          elevation: 0,
          shadowColor: colors.shadowDark,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: typography.button,
          minimumSize: const Size(88, 48),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return (isDark ? Colors.white : colors.ink).withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return (isDark ? Colors.white : colors.ink).withValues(alpha: 0.08);
            }
            return null;
          }),
        ),
      ),

      // FilledButton (secondary clay button)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.surface,
          foregroundColor: colors.ink,
          disabledBackgroundColor: colors.surface.withValues(alpha: 0.5),
          disabledForegroundColor: colors.ink.withValues(alpha: 0.5),
          elevation: 0,
          shadowColor: colors.shadow,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
            side: BorderSide(color: colors.divider, width: 1),
          ),
          textStyle: typography.button,
          minimumSize: const Size(88, 48),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          disabledForegroundColor: colors.inkMuted,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          side: BorderSide(color: colors.divider, width: 1),
          textStyle: typography.button,
          minimumSize: const Size(88, 48),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          disabledForegroundColor: colors.inkMuted,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: typography.button,
          minimumSize: const Size(64, 40),
        ),
      ),

      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        labelStyle: typography.bodyMedium.copyWith(color: colors.inkMuted),
        hintStyle: typography.body.copyWith(color: colors.inkSubtle),
        floatingLabelStyle: typography.bodyMedium.copyWith(color: colors.accent),
        errorStyle: typography.caption.copyWith(color: colors.danger),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: colors.divider, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: colors.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: colors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: colors.danger, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: colors.divider.withValues(alpha: 0.5), width: 1),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
        indent: 0,
        endIndent: 0,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceContainer,
        disabledColor: colors.surfaceContainer.withValues(alpha: 0.5),
        selectedColor: colors.primary,
        secondarySelectedColor: colors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        labelStyle: typography.bodyMedium.copyWith(color: colors.inkMuted),
        secondaryLabelStyle: typography.bodySemiBold.copyWith(color: isDark ? const Color(0xFF140E0A) : Colors.white),
        brightness: brightness,
        elevation: 0,
        pressElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
          side: BorderSide(color: colors.divider, width: 1),
        ),
        selectedShadowColor: Colors.transparent,
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.accentDark,
        unselectedItemColor: colors.inkMuted,
        selectedLabelStyle: typography.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
        unselectedLabelStyle: typography.caption.copyWith(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
      ),

      // NavigationBar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return typography.caption.copyWith(fontSize: 11, color: colors.accentDark, fontWeight: FontWeight.w500);
          }
          return typography.caption.copyWith(fontSize: 11, color: colors.inkMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.accentDark, size: 22);
          }
          return IconThemeData(color: colors.inkMuted, size: 22);
        }),
        height: 60,
        surfaceTintColor: Colors.transparent,
        shadowColor: colors.shadow,
        elevation: 8,
      ),

      // FloatingActionButton
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: isDark ? const Color(0xFF140E0A) : Colors.white,
        elevation: 8,
        focusElevation: 8,
        hoverElevation: 10,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: colors.shadowDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusModal),
        ),
        titleTextStyle: typography.heading,
        contentTextStyle: typography.body,
        alignment: Alignment.center,
      ),

      // BottomSheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: colors.shadowDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusModal)),
        ),
        modalBackgroundColor: colors.surfaceElevated,
        dragHandleColor: colors.divider,
        showDragHandle: true,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        contentTextStyle: typography.bodyMedium,
        actionTextColor: colors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        elevation: 4,
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        labelColor: colors.accentDark,
        unselectedLabelColor: colors.inkMuted,
        labelStyle: typography.label,
        unselectedLabelStyle: typography.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: colors.primary, width: 3),
          insets: const EdgeInsets.symmetric(horizontal: 16),
        ),
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return colors.primary.withValues(alpha: 0.1);
            }
          return null;
        }),
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.divider,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.15),
        valueIndicatorColor: colors.primary,
        valueIndicatorTextStyle: typography.caption.copyWith(color: isDark ? const Color(0xFF140E0A) : Colors.white),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),

      // ProgressIndicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.divider,
        circularTrackColor: colors.divider,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return colors.inkMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary.withValues(alpha: 0.5);
          }
          return colors.divider;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return colors.divider;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(isDark ? const Color(0xFF140E0A) : Colors.white),
        side: BorderSide(color: colors.divider, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return colors.inkMuted;
        }),
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(radiusInput),
          border: Border.all(color: colors.divider, width: 0.5),
          boxShadow: _subtleShadows(colors),
        ),
        textStyle: typography.bodySmall.copyWith(color: colors.ink),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        preferBelow: true,
        verticalOffset: 8,
      ),

      // Extensions for clay shadows and custom tokens
      extensions: <ThemeExtension<dynamic>>[
        ClayShadowsExtension(
          card: _cardShadows(colors),
          pressed: _pressedShadows(colors),
          floating: _floatingShadows(colors),
          subtle: _subtleShadows(colors),
        ),
        AppColorSchemeExtension(colors: colors),
      ],
    );
  }

  /// Pre-built Forest Dark theme
  static ThemeData forestDark() {
    const colors = AppColors.forestDark;
    final typography = AppTypography.fromColors(colors);
    return build(colors, typography);
  }

  /// Pre-built Coffee Light theme
  static ThemeData coffeeLight() {
    const colors = AppColors.coffeeLight;
    final typography = AppTypography.fromColors(colors);
    return build(colors, typography);
  }
}

/// ThemeExtension for clay shadows — access via `Theme.of(context).extension<ClayShadows>()`
class ClayShadowsExtension extends ThemeExtension<ClayShadowsExtension> {
  const ClayShadowsExtension({
    required this.card,
    required this.pressed,
    required this.floating,
    required this.subtle,
  });

  final List<BoxShadow> card;
  final List<BoxShadow> pressed;
  final List<BoxShadow> floating;
  final List<BoxShadow> subtle;

  @override
  ClayShadowsExtension copyWith({
    List<BoxShadow>? card,
    List<BoxShadow>? pressed,
    List<BoxShadow>? floating,
    List<BoxShadow>? subtle,
  }) {
    return ClayShadowsExtension(
      card: card ?? this.card,
      pressed: pressed ?? this.pressed,
      floating: floating ?? this.floating,
      subtle: subtle ?? this.subtle,
    );
  }

  @override
  ClayShadowsExtension lerp(ThemeExtension<ClayShadowsExtension>? other, double t) {
    if (other is! ClayShadowsExtension) return this;
    return ClayShadowsExtension(
      card: _lerpShadowList(card, other.card, t),
      pressed: _lerpShadowList(pressed, other.pressed, t),
      floating: _lerpShadowList(floating, other.floating, t),
      subtle: _lerpShadowList(subtle, other.subtle, t),
    );
  }

  static List<BoxShadow> _lerpShadowList(List<BoxShadow> a, List<BoxShadow> b, double t) {
    if (a.length != b.length) return a;
    return List.generate(a.length, (i) => BoxShadow.lerp(a[i], b[i], t)!);
  }
}

/// ThemeExtension for direct AppColors access — access via `Theme.of(context).extension<AppColorScheme>()`
class AppColorSchemeExtension extends ThemeExtension<AppColorSchemeExtension> {
  const AppColorSchemeExtension({required this.colors});

  final AppColors colors;

  @override
  AppColorSchemeExtension copyWith({AppColors? colors}) {
    return AppColorSchemeExtension(colors: colors ?? this.colors);
  }

  @override
  AppColorSchemeExtension lerp(ThemeExtension<AppColorSchemeExtension>? other, double t) {
    if (other is! AppColorSchemeExtension) return this;
    return AppColorSchemeExtension(colors: AppColors.lerp(colors, other.colors, t));
  }
}

/// Convenience extensions on BuildContext
extension KiokuTheme on BuildContext {
  AppColors get kiokuColors => Theme.of(this).extension<AppColorSchemeExtension>()!.colors;
  ClayShadowsExtension get clayShadows => Theme.of(this).extension<ClayShadowsExtension>()!;
  AppTypography get kiokuTypography => AppTypography.fromColors(kiokuColors);
}