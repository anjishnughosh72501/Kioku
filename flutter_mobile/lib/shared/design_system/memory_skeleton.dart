import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme/index.dart';

class MemorySkeleton extends StatefulWidget {
  const MemorySkeleton({super.key, this.isHero = false});

  final bool isHero;

  @override
  State<MemorySkeleton> createState() => _MemorySkeletonState();
}

class _MemorySkeletonState extends State<MemorySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final baseColor = colors.surfaceContainerLow;
    final highlightColor = colors.surfaceContainerHighest.withValues(
      alpha: 0.6,
    );

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        final shimmerGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [
            (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
            _shimmerAnimation.value.clamp(0.0, 1.0),
            (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
          ],
          colors: [baseColor, highlightColor, baseColor],
        );

        if (widget.isHero) {
          return Container(
            height: 380,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: shimmerGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(
                color: colors.divider.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: colors.divider.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: shimmerGradient,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusCard),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 80,
                          height: 18,
                          decoration: BoxDecoration(
                            gradient: shimmerGradient,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 14,
                          decoration: BoxDecoration(
                            gradient: shimmerGradient,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 140,
                      height: 14,
                      decoration: BoxDecoration(
                        gradient: shimmerGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: shimmerGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
