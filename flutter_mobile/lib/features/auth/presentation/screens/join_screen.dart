/// JoinScreen — one-tap Google Sign-In. Your Google account is your identity;
/// memories are stored in your own Google Drive.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/washi_tape.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';
import 'package:flutter_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_mobile/features/auth/presentation/widgets/username_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JoinScreen extends ConsumerWidget {
  const JoinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WashiTape(variant: WashiVariant.sage, angle: -2.5, width: 80)
                      .animate()
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: AppTheme.spacingLg),

                  // Kioku logo mark
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow,
                          offset: const Offset(0, 6),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/kiokulogo.jpg',
                      fit: BoxFit.cover,
                    ),
                  ).animate().scale(delay: 150.ms, duration: 500.ms, curve: Curves.elasticOut),

                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'Kioku',
                    style: typography.displayLarge?.copyWith(
                      fontSize: 40,
                      color: colors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
                  Text(
                    '記憶 · a warm memory album',
                    style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
                  ).animate().fadeIn(delay: 350.ms, duration: 400.ms),

                  const SizedBox(height: AppTheme.spacingXl),

                  ClayCard(
                    variant: ClayVariant.defaultCard,
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign in with Google',
                          textAlign: TextAlign.center,
                          style: typography.headlineSmall?.copyWith(
                            fontSize: 18,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingSm),
                        Text(
                          'Your photos and videos live privately in '
                          'your own Drive. No servers, no invite codes.',
                          textAlign: TextAlign.center,
                          style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                        ),
                        const SizedBox(height: AppTheme.spacingLg),

                        if (authState.isLoading)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: CircularProgressIndicator(color: colors.primary),
                            ),
                          )
                        else ...[
                          ClayButton(
                            label: authState.isSignedIn
                                ? 'Welcome · ${authState.email?.split('@').first ?? ''}'
                                : 'Continue with Google',
                            icon: _GoogleMark(color: colors.ink),
                            variant: ClayButtonVariant.primary,
                            fullWidth: true,
                            onPressed: () =>
                                ref.read(authControllerProvider.notifier).signIn(),
                          ).animate().fadeIn(delay: 450.ms, duration: 300.ms),
                          const SizedBox(height: AppTheme.spacingMd),
                          Row(
                            children: [
                              Expanded(child: Divider(color: colors.divider)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'OR',
                                  style: typography.bodySmall?.copyWith(
                                    color: colors.inkMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: colors.divider)),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          ClayButton(
                            label: 'Continue Offline (Local)',
                            icon: Icon(Icons.offline_pin_outlined, size: 18, color: colors.ink),
                            variant: ClayButtonVariant.secondary,
                            fullWidth: true,
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              final alreadyPrompted = prefs.getBool('kioku_username_prompted') ?? false;
                              if (!alreadyPrompted && context.mounted) {
                                await showDialog<void>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => const UsernameDialog(isDismissible: false),
                                );
                              }
                              ref.read(authControllerProvider.notifier).continueAsGuest();
                            },
                          ).animate().fadeIn(delay: 500.ms, duration: 300.ms),
                        ],

                        if (authState.error != null) ...[
                          const SizedBox(height: AppTheme.spacingMd),
                          Text(
                            authState.error!,
                            textAlign: TextAlign.center,
                            style: typography.bodySmall?.copyWith(color: colors.danger),
                          ),
                        ],
                      ],
                    ),
                  ).animate().fadeIn(delay: 450.ms, duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),

                  const SizedBox(height: AppTheme.spacingLg),
                  Text(
                    'Friends can join an album you share with them from the '
                    'folder — guided from your device.',
                    textAlign: TextAlign.center,
                    style: typography.bodySmall?.copyWith(
                      color: colors.inkMuted,
                      fontSize: 11,
                    ),
                  ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A simple four-color Google "G" mark drawn with the brand colors.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      child: Text(
        'G',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}