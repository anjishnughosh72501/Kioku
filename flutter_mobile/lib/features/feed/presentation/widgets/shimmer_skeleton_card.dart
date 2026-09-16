/// ShimmerSkeletonCard — Tactile skeleton card with animated shimmer
/// Replaces plain spinners during feed loading states.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';

class ShimmerSkeletonCard extends StatelessWidget {
  const ShimmerSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final disableAnims = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget buildPlaceholder({
      required double width,
      required double height,
      double radius = 6,
      EdgeInsetsGeometry? margin,
    }) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    Widget content = ClayCard(
      variant: ClayVariant.defaultCard,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusCard),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 40,
                  color: colors.inkSubtle.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    buildPlaceholder(width: 70, height: 18, radius: AppTheme.radiusPill),
                    const Spacer(),
                    buildPlaceholder(width: 60, height: 12, radius: 4),
                  ],
                ),
                const SizedBox(height: 12),
                buildPlaceholder(width: double.infinity, height: 14, radius: 4),
                const SizedBox(height: 6),
                buildPlaceholder(width: 140, height: 14, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );

    if (disableAnims) {
      return content;
    }

    return content
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 1200.ms,
          color: colors.surfaceElevated.withValues(alpha: 0.6),
          blendMode: BlendMode.srcATop,
        );
  }
}