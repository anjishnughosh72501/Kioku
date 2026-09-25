import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Centralized layout metrics and geometry calculations for Kioku UI components.
/// Ensures consistent clearance above persistent surfaces like FloatingBottomDock.
abstract final class KiokuLayout {
  /// Height of the persistent FloatingBottomDock.
  static const double bottomDockHeight = 64.0;

  /// Bottom margin of the persistent FloatingBottomDock.
  static const double bottomDockMarginBottom = 14.0;

  /// Total clearance required to position an overlay or content cleanly above
  /// the persistent FloatingBottomDock, including system gesture/safe-area insets.
  static double bottomDockClearance(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return bottomDockHeight + bottomDockMarginBottom + bottomInset;
  }

  /// Calculates the appropriate bottom margin for floating SnackBars so they
  /// never collide with or touch the persistent bottom navigation dock.
  static double floatingSnackBarBottomMargin(
    BuildContext context, {
    bool aboveBottomNav = true,
  }) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    if (aboveBottomNav) {
      return bottomDockClearance(context) + 12.0;
    }
    return math.max(bottomInset, 16.0) + 8.0;
  }

  /// Default max height factor for standard bottom sheets.
  static const double bottomSheetMaxHeightFactor = 0.88;

  /// Standard border radius for bottom sheet top corners.
  static const double bottomSheetTopRadius = 28.0;

  /// Standard border radius for modal dialogs.
  static const double dialogRadius = 24.0;
}
