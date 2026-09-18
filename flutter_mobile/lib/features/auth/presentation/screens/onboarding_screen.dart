/// OnboardingScreen — 3-step walkthrough introducing privacy, circles, and memories.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kioku_onboarding_done', true);
    if (mounted) {
      context.go('/join');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    final pages = [
      _OnboardingPageData(
        icon: Icons.shield_outlined,
        title: 'Zero-Knowledge Privacy',
        subtitle:
            'Your photos and videos are encrypted on your device using libsodium. Only you and friends you explicitly invite can unlock them.',
        pill: 'Hardware Keystore Security',
      ),
      _OnboardingPageData(
        icon: Icons.people_outline_rounded,
        title: 'Close Friend Circles',
        subtitle:
            'Connect using mutual friend codes and two-way requests. No algorithmic feeds or public vanity metrics — just genuine connections.',
        pill: 'Private Mutual Sharing',
      ),
      _OnboardingPageData(
        icon: Icons.auto_awesome_outlined,
        title: 'Your Memories, Forever Yours',
        subtitle:
            'Memories live directly in your personal Google Drive or local storage. You keep 100% data ownership with zero corporate lock-in.',
        pill: 'Decentralized Storage',
      ),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLg,
            vertical: AppTheme.spacingMd,
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip',
                    style: typography.bodyMedium?.copyWith(
                      color: colors.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemBuilder: (context, index) {
                    final item = pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd,
                        vertical: AppTheme.spacingLg,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(item.icon, size: 48, color: colors.primary),
                          )
                              .animate()
                              .scale(duration: 400.ms, curve: Curves.easeOutBack),
                          const SizedBox(height: AppTheme.spacingLg),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                              border: Border.all(color: colors.divider),
                            ),
                            child: Text(
                              item.pill,
                              style: typography.bodySmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: typography.headlineSmall?.copyWith(
                              color: colors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          Text(
                            item.subtitle,
                            textAlign: TextAlign.center,
                            style: typography.bodyMedium?.copyWith(
                              color: colors.inkMuted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SmoothPageIndicator(
                controller: _pageController,
                count: pages.length,
                effect: ExpandingDotsEffect(
                  dotWidth: 8,
                  dotHeight: 8,
                  activeDotColor: colors.primary,
                  dotColor: colors.divider,
                  expansionFactor: 3,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXl),
              SizedBox(
                width: double.infinity,
                child: ClayButton(
                  label: _currentPage == pages.length - 1 ? 'Get Started' : 'Continue',
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  onPressed: () {
                    if (_currentPage < pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _completeOnboarding();
                    }
                  },
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String pill;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pill,
  });
}
