/// ClayCard — Soft clay-elevation container with press feedback and depth shadows
/// The primary card component for the Kioku tactile UI
library;

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import 'package:flutter_mobile/core/theme/index.dart';

class ClayCard extends StatefulWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.variant = ClayVariant.defaultCard,
    this.radius,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.animateIn = false,
    this.borderColor,
  });

  final Widget child;
  final ClayVariant variant;
  final double? radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool animateIn;
  final Color? borderColor;

  @override
  State<ClayCard> createState() => _ClayCardState();
}

class _ClayCardState extends State<ClayCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 320),
      vsync: this,
      lowerBound: 0.98,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
      _pressController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _pressController.reverse();
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      _pressController.reverse();
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final clayShadows = context.clayShadows;

    final effectiveRadius = widget.radius ?? AppTheme.radiusCard;
    final effectivePadding = widget.padding ?? EdgeInsets.zero;
    final effectiveMargin = widget.margin ?? EdgeInsets.zero;

    List<BoxShadow> shadows;
    Color bgColor;
    Color effectiveBorderColor = widget.borderColor ?? colors.glassBorder;

    switch (widget.variant) {
      case ClayVariant.defaultCard:
        bgColor = colors.surfaceElevated;
        shadows = _isPressed ? clayShadows.pressed : clayShadows.card;
        break;
      case ClayVariant.pressed:
        bgColor = colors.surfaceContainer;
        shadows = clayShadows.pressed;
        break;
      case ClayVariant.elevated:
        bgColor = colors.surfaceElevated;
        shadows = clayShadows.floating;
        break;
      case ClayVariant.subtle:
        bgColor = colors.surfaceContainerLow;
        shadows = clayShadows.subtle;
        effectiveBorderColor = colors.divider;
        break;
      case ClayVariant.outlined:
        bgColor = colors.surfaceContainerLowest;
        shadows = clayShadows.subtle;
        effectiveBorderColor = colors.divider;
        break;
    }

    final card = AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: effectiveMargin,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(effectiveRadius),
          border: Border.all(color: effectiveBorderColor, width: 1),
          boxShadow: shadows,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(effectiveRadius),
          child: Padding(
            padding: effectivePadding,
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: card,
      );
    }

    return card;
  }
}

enum ClayVariant {
  defaultCard, // Standard clay card
  pressed, // Pressed/active state
  elevated, // Floating elevated card
  subtle, // Subtle low-elevation card
  outlined, // Outlined card with no fill elevation
}

/// ClayButton — Pill-shaped button with clay press effect and haptic feedback
/// Primary and secondary variants with loading states

class ClayButton extends StatefulWidget {
  const ClayButton({
    super.key,
    required this.label,
    this.icon,
    this.variant = ClayButtonVariant.primary,
    this.onPressed,
    this.disabled = false,
    this.loading = false,
    this.fullWidth = false,
    this.padding,
    this.radius,
    this.size = ClayButtonSize.medium,
  });

  final String label;
  final Widget? icon;
  final ClayButtonVariant variant;
  final VoidCallback? onPressed;
  final bool disabled;
  final bool loading;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final ClayButtonSize size;

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 280),
      vsync: this,
      lowerBound: 0.98,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (!widget.disabled && !widget.loading && widget.onPressed != null) {
      _pressController.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  void _handleTap() {
    if (widget.disabled || widget.loading || widget.onPressed == null) return;
    Vibration.vibrate(duration: 25);
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final clayShadows = context.clayShadows;

    final effectiveRadius = widget.radius ?? AppTheme.radiusButton;
    final effectivePadding = widget.padding ??
        (widget.size == ClayButtonSize.small
            ? const EdgeInsets.symmetric(vertical: 10, horizontal: 16)
            : const EdgeInsets.symmetric(vertical: 14, horizontal: 24));

    Color bgColor;
    Color fgColor;
    List<BoxShadow> shadows;
    BoxBorder? border;

    final isDisabled = widget.disabled || widget.loading;

    switch (widget.variant) {
      case ClayButtonVariant.primary:
        bgColor = isDisabled ? colors.primary.withValues(alpha: 0.5) : colors.primary;
        fgColor = isDisabled
            ? (colors.brightness == Brightness.dark ? const Color(0xFF140E0A) : Colors.white).withValues(alpha: 0.5)
            : (colors.brightness == Brightness.dark ? const Color(0xFF140E0A) : Colors.white);
        shadows = isDisabled ? clayShadows.subtle : clayShadows.card;
        border = null;
      case ClayButtonVariant.danger:
        bgColor = isDisabled ? colors.danger.withValues(alpha: 0.5) : colors.danger;
        fgColor = Colors.white;
        shadows = isDisabled ? clayShadows.subtle : clayShadows.card;
        border = null;
      case ClayButtonVariant.secondary:
        bgColor = isDisabled ? colors.surface.withValues(alpha: 0.5) : colors.surface;
        fgColor = isDisabled ? colors.inkMuted : colors.ink;
        shadows = isDisabled ? clayShadows.subtle : clayShadows.card;
        border = Border.all(color: isDisabled ? colors.divider.withValues(alpha: 0.5) : colors.divider, width: 1);
    }

    final button = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: widget.fullWidth ? double.infinity : null,
        padding: effectivePadding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(effectiveRadius),
          border: border,
          boxShadow: shadows,
        ),
        child: Center(
          child: widget.loading
              ? SizedBox(
                  width: widget.size == ClayButtonSize.small ? 16 : 20,
                  height: widget.size == ClayButtonSize.small ? 16 : 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(fgColor),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      widget.icon!,
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: typography.labelLarge?.copyWith(
                          fontSize: widget.size == ClayButtonSize.small ? 12 : 14,
                          fontWeight: FontWeight.w500,
                          color: fgColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: button,
    );
  }
}

enum ClayButtonVariant {
  primary, // Filled with primary color
  secondary, // Outlined with surface color
  danger, // Destructive action
}

enum ClayButtonSize {
  small,
  medium,
  large,
}

/// ClayIconButton — Small circular icon button with clay press feedback
class ClayIconButton extends StatefulWidget {
  const ClayIconButton({
    super.key,
    required this.icon,
    this.size = 44,
    this.onPressed,
    this.disabled = false,
    this.variant = ClayIconVariant.defaultIcon,
    this.tooltip,
  });

  final Widget icon;
  final double size;
  final VoidCallback? onPressed;
  final bool disabled;
  final ClayIconVariant variant;
  final String? tooltip;

  @override
  State<ClayIconButton> createState() => _ClayIconButtonState();
}

class _ClayIconButtonState extends State<ClayIconButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 60),
      vsync: this,
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (!widget.disabled && widget.onPressed != null) {
      _pressController.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  void _handleTap() {
    if (widget.disabled || widget.onPressed == null) return;
    Vibration.vibrate(duration: 15);
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final clayShadows = context.clayShadows;

    Color bgColor;
    List<BoxShadow> shadows;

    switch (widget.variant) {
      case ClayIconVariant.defaultIcon:
        bgColor = widget.disabled ? colors.surface.withValues(alpha: 0.5) : colors.surface;
        shadows = widget.disabled ? [] : clayShadows.subtle;
        break;
      case ClayIconVariant.primary:
        bgColor = widget.disabled ? colors.primary.withValues(alpha: 0.5) : colors.primary;
        shadows = widget.disabled ? [] : clayShadows.card;
        break;
      case ClayIconVariant.subtle:
        bgColor = widget.disabled ? colors.surfaceContainer.withValues(alpha: 0.5) : colors.surfaceContainer;
        shadows = widget.disabled ? [] : clayShadows.subtle;
        break;
    }

    final button = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(widget.size / 2),
          border: widget.variant == ClayIconVariant.defaultIcon
              ? Border.all(color: colors.divider, width: 1)
              : null,
          boxShadow: shadows,
        ),
        child: Center(
          child: IconTheme.merge(
            data: IconThemeData(
              color: widget.disabled
                  ? colors.inkMuted
                  : (widget.variant == ClayIconVariant.primary
                      ? (colors.brightness == Brightness.dark ? const Color(0xFF0D1E15) : Colors.white)
                      : colors.ink),
              size: widget.size * 0.5,
            ),
            child: widget.icon,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: _handleTap,
          child: button,
        ),
      );
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: button,
    );
  }
}

enum ClayIconVariant {
  defaultIcon,
  primary,
  subtle,
}