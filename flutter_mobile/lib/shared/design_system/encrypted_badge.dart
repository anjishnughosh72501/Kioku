import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme/index.dart';

enum EncryptedBadgeVariant { compact, standard, prominent }

class EncryptedBadge extends StatefulWidget {
  const EncryptedBadge({
    super.key,
    this.variant = EncryptedBadgeVariant.compact,
    this.label = 'End-to-End Encrypted',
    this.animateOnMount = true,
  });

  final EncryptedBadgeVariant variant;
  final String label;
  final bool animateOnMount;

  @override
  State<EncryptedBadge> createState() => _EncryptedBadgeState();
}

class _EncryptedBadgeState extends State<EncryptedBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.animateOnMount) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    Widget content;
    switch (widget.variant) {
      case EncryptedBadgeVariant.compact:
        content = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 11, color: colors.primary),
              const SizedBox(width: 4),
              Text(
                'E2EE',
                style: typography.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        );
        break;

      case EncryptedBadgeVariant.standard:
        content = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 13, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: typography.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
        break;

      case EncryptedBadgeVariant.prominent:
        content = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Zero-Knowledge Encrypted',
                    style: typography.labelMedium?.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Only you and your circle hold the keys',
                    style: typography.bodySmall?.copyWith(
                      color: colors.inkMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        break;
    }

    return FadeTransition(
      opacity: _opacityAnimation,
      child: ScaleTransition(scale: _scaleAnimation, child: content),
    );
  }
}
