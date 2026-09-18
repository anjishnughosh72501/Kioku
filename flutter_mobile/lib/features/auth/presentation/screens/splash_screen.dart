/// SplashScreen — warm logo animation and initialization check on cold start.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/features/auth/presentation/controllers/auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkNextDestination();
  }

  Future<void> _checkNextDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final hasStartedBefore = prefs.getBool('first_startup_completed') ?? false;

    // Show splash animation for at least 1.0s for a polished launch experience
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    if (hasStartedBefore) {
      // Later startup: ALWAYS go directly to main feed!
      // NEVER prompt for Google sign-in or username.
      if (mounted) context.go('/');
      return;
    }

    // First startup flow:
    final onboardingDone = prefs.getBool('kioku_onboarding_done') ?? false;
    if (!onboardingDone) {
      if (mounted) context.go('/onboarding');
      return;
    }

    final authState = ref.read(authControllerProvider);
    if (authState.isAuthenticated) {
      if (mounted) context.go('/');
    } else {
      if (mounted) context.go('/join');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.18),
                    offset: const Offset(0, 8),
                    blurRadius: 20,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/kiokulogo.jpg',
                fit: BoxFit.cover,
              ),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'Kioku · 記憶',
              style: typography.headlineMedium?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Private memories shared with close friends',
              style: typography.bodyMedium?.copyWith(
                color: colors.inkMuted,
                fontStyle: FontStyle.italic,
              ),
            ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
            const SizedBox(height: 48),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ).animate().fadeIn(delay: 500.ms, duration: 300.ms),
          ],
        ),
      ),
    );
  }
}
