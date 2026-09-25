import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/design_system/kioku_layout.dart';

/// Shows a standardized Kioku modal dialog on the root navigator.
Future<T?> showKiokuDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => builder(ctx),
  );
}

/// Standardized dialog surface for Kioku.
class KiokuDialog extends StatelessWidget {
  const KiokuDialog({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.icon,
    this.maxWidth = 420.0,
  });

  final Widget child;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? icon;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KiokuLayout.dialogRadius),
        side: BorderSide(color: colors.divider, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Center(child: icon!),
                const SizedBox(height: AppTheme.spacingMd),
              ],
              if (title != null) ...[
                DefaultTextStyle(
                  style:
                      typography.titleLarge?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w700,
                      ) ??
                      const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: icon != null ? TextAlign.center : TextAlign.start,
                  child: title!,
                ),
                const SizedBox(height: AppTheme.spacingMd),
              ],
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: child,
                ),
              ),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
