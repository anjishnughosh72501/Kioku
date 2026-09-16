/// HankoStamp — Interactive Japanese seal stamp with spring physics and haptic feedback
/// Used for reactions, confirmation buttons, and tactile interactions
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_mobile/core/theme/index.dart';

class HankoStamp extends StatefulWidget {
  const HankoStamp({
    super.key,
    required this.label,
    this.count = 0,
    this.isActive = false,
    this.variant = HankoVariant.hanko,
    this.color,
    this.onPressed,
    this.size = 44,
    this.showCount = true,
  });

  final String label; // Single kanji/character like "通", "好", "記"
  final int count;
  final bool isActive;
  final HankoVariant variant;
  final Color? color;
  final VoidCallback? onPressed;
  final double size;
  final bool showCount;

  @override
  State<HankoStamp> createState() => _HankoStampState();
}

class _HankoStampState extends State<HankoStamp> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isActive = false;
  int _stampCount = 0;

  @override
  void initState() {
    super.initState();
    _isActive = widget.isActive;
    _stampCount = widget.count;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant HankoStamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _isActive = widget.isActive;
    }
    if (oldWidget.count != widget.count && widget.onPressed == null) {
      // Only update count from parent if not internally managed
      _stampCount = widget.count;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();

    _controller.forward().then((_) => _controller.reverse());

    setState(() {
      _isActive = !_isActive;
      _stampCount = _isActive ? _stampCount + 1 : _stampCount - 1;
    });

    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final stampColor = widget.color ?? colors.hankoRed;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _isActive ? colors.surfaceContainerHigh : colors.surface,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: _isActive ? stampColor : colors.divider,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                offset: const Offset(0, 1),
                blurRadius: 2,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hanko seal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(color: stampColor, width: 1.4),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  widget.label,
                  style: typography.headlineSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: stampColor,
                    height: 1.2,
                  ),
                ),
              ),
              if (widget.showCount) ...[
                const SizedBox(width: 5),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                  child: Text(
                    '$_stampCount',
                    key: ValueKey(_stampCount),
                    style: typography.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: _isActive ? FontWeight.w700 : FontWeight.w500,
                      color: _isActive ? colors.ink : colors.inkMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum HankoVariant {
  hanko, // Red seal with kanji
  icon, // Emoji/icon based
}

/// Larger Hanko stamp for primary actions (like "Post" / "通")
class HankoActionStamp extends StatelessWidget {
  const HankoActionStamp({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.color,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final Widget? icon;
  final VoidCallback onPressed;
  final Color? color;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final stampColor = color ?? colors.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled && !loading ? onPressed : null,
        borderRadius: BorderRadius.circular(9999),
        splashColor: stampColor.withValues(alpha: 0.2),
        highlightColor: stampColor.withValues(alpha: 0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: enabled ? colors.surface : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: enabled ? stampColor : colors.divider,
              width: 1.4,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: colors.shadow,
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 6),
              ],
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(stampColor),
                  ),
                )
              else
                Text(
                  label,
                  style: typography.headlineSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: enabled ? stampColor : colors.inkMuted,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}