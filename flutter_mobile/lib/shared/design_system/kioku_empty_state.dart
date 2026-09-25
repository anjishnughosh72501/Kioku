import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme/index.dart';

class KiokuEmptyState extends StatelessWidget {
  const KiokuEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonPressed,
    this.icon = Icons.auto_awesome_outlined,
    this.secondaryButtonText,
    this.onSecondaryPressed,
  });

  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final IconData icon;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Decorative circular badge
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.10),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, size: 38, color: colors.primary),
            ),
            const SizedBox(height: 24),

            // Emotional title
            Text(
              title,
              textAlign: TextAlign.center,
              style: typography.headlineSmall?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),

            // Subtitle
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 290),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: typography.bodyMedium?.copyWith(
                  color: colors.inkMuted,
                  height: 1.45,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Action button
            if (buttonText != null && onButtonPressed != null)
              ElevatedButton(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.brightness == Brightness.dark
                      ? const Color(0xFF140E0A)
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  buttonText!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),

            if (secondaryButtonText != null && onSecondaryPressed != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onSecondaryPressed,
                child: Text(
                  secondaryButtonText!,
                  style: TextStyle(
                    color: colors.accentDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
