import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/design_system/kioku_layout.dart';

/// Shows a standardized Kioku bottom sheet with proper root-navigator routing,
/// surface container styling, and safe-area geometry.
Future<T?> showKiokuBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => builder(ctx),
  );
}

/// Standard surface container for Kioku bottom sheets.
/// Handles drag handles, keyboard resizing (viewInsets), system gesture clearance,
/// and surface borders/shadows matching the warm Kioku dark palette.
class KiokuBottomSheet extends StatelessWidget {
  const KiokuBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.headerLeading,
    this.headerTrailing,
    this.showDragHandle = true,
    this.maxHeightFactor,
    this.padding,
  });

  final Widget child;
  final Widget? title;
  final Widget? subtitle;
  final Widget? headerLeading;
  final Widget? headerTrailing;
  final bool showDragHandle;
  final double? maxHeightFactor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final bottomPadding =
        math.max(viewPadding.bottom, AppTheme.spacingLg) + viewInsets.bottom;
    final effectiveMaxHeightFactor =
        maxHeightFactor ?? KiokuLayout.bottomSheetMaxHeightFactor;
    final maxHeight =
        MediaQuery.sizeOf(context).height * effectiveMaxHeightFactor;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(KiokuLayout.bottomSheetTopRadius),
            ),
            border: Border.all(color: colors.divider, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            AppTheme.spacingLg,
            AppTheme.spacingMd,
            AppTheme.spacingLg,
            bottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              if (showDragHandle)
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

              // Optional Header
              if (title != null) ...[
                Row(
                  children: [
                    if (headerLeading != null) ...[
                      headerLeading!,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DefaultTextStyle(
                            style:
                                typography.headlineSmall?.copyWith(
                                  color: colors.ink,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ) ??
                                const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                            child: title!,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            DefaultTextStyle(
                              style:
                                  typography.bodySmall?.copyWith(
                                    color: colors.inkMuted,
                                    fontSize: 12,
                                  ) ??
                                  const TextStyle(fontSize: 12),
                              child: subtitle!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (headerTrailing != null)
                      headerTrailing!
                    else
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: colors.inkMuted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMd),
              ],

              // Content Body
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
