/// WashiTape — Tactile Japanese washi tape strip with fiber grain and semi-transparent pastel colors
/// Used on photos, polaroids, and notes throughout the app
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter_mobile/core/theme/index.dart';

class WashiTape extends StatelessWidget {
  const WashiTape({
    super.key,
    this.angle = -2.0,
    this.width = 64,
    this.height = 16,
    this.color,
    this.variant = WashiVariant.defaultTape,
    this.animateIn = false,
  });

  final double angle; // degrees
  final double width;
  final double height;
  final Color? color;
  final WashiVariant variant;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final tapeColor = color ?? _variantColor(colors);

    final widget = Transform.rotate(
      angle: angle * 3.14159 / 180,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: tapeColor,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1F241913), // rgba(36, 25, 19, 0.12)
              offset: const Offset(0, 1),
              blurRadius: 2,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Fiber grain streak
            Positioned.fill(
              child: Center(
                child: Container(
                  width: double.infinity,
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.45),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Subtle texture dots
            Positioned.fill(
              child: CustomPaint(
                painter: _WashiTexturePainter(tapeColor),
              ),
            ),
          ],
        ),
      ),
    );

    if (animateIn) {
      return ExcludeSemantics(
        child: widget
            .animate()
            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
            .slideY(begin: -0.2, end: 0, duration: 300.ms, curve: Curves.easeOut),
      );
    }
    return ExcludeSemantics(child: widget);
  }

  Color _variantColor(AppColors colors) {
    switch (variant) {
      case WashiVariant.defaultTape:
        return colors.washiTape;
      case WashiVariant.matcha:
        return colors.washiTapeMatcha;
      case WashiVariant.peach:
        return colors.washiTapePeach;
      case WashiVariant.amber:
        return colors.amber.withValues(alpha: 0.6);
      case WashiVariant.sage:
        return colors.sage.withValues(alpha: 0.5);
    }
  }
}

enum WashiVariant {
  defaultTape,
  matcha,
  peach,
  amber,
  sage,
}

/// Custom painter for subtle washi paper texture
class _WashiTexturePainter extends CustomPainter {
  _WashiTexturePainter(this.tapeColor);

  final Color tapeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    // Draw subtle random dots for paper fiber texture
    const dotCount = 12;
    for (int i = 0; i < dotCount; i++) {
      final x = (i * size.width / dotCount) + (i.isEven ? 2.0 : -2.0);
      final y = size.height * (i.isEven ? 0.3 : 0.7);
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}