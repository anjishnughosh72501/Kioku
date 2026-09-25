import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/design_system/kioku_layout.dart';

/// Displays a standardized floating Kioku SnackBar positioned above the persistent
/// bottom navigation bar when [aboveBottomNav] is true.
void showKiokuSnackBar(
  BuildContext context,
  String message, {
  bool aboveBottomNav = false,
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
  IconData? icon,
}) {
  final colors = context.kiokuColors;
  final bottomMargin = KiokuLayout.floatingSnackBarBottomMargin(
    context,
    aboveBottomNav: aboveBottomNav,
  );

  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
      backgroundColor: colors.surfaceContainerHigh,
      elevation: 6,
      duration: duration,
      action: action,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.divider, width: 0.8),
      ),
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: colors.primary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
