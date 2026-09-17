/// KiokuBottomNavBar — Custom curved navigation bar with floating capture FAB
/// Features clay shadows, spring animations, and haptic feedback
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_mobile/core/theme/index.dart';

class KiokuBottomNavBar extends StatelessWidget {
  const KiokuBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onCapturePressed,
    this.items = const [],
    this.backgroundColor,
    this.captureIcon,
    this.captureSize = 56,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onCapturePressed;
  final List<BottomNavItem> items;
  final Color? backgroundColor;
  final Widget? captureIcon;
  final double captureSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final clayShadows = context.clayShadows;

    final effectiveBg = backgroundColor ?? colors.surface;

    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: 58,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 14),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusNavigation),
          border: Border.all(color: colors.divider, width: 1),
          boxShadow: clayShadows.floating,
        ),
        child: Row(
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isActive = index == currentIndex;

            return Expanded(
              child: _NavBarItem(
                item: item,
                isActive: isActive,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(index);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final BottomNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusNavigation),
        splashColor: colors.primary.withValues(alpha: 0.1),
        highlightColor: colors.primary.withValues(alpha: 0.05),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive
                  ? colors.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Tooltip(
              message: item.label,
              child: AnimatedScale(
                scale: isActive ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: IconTheme(
                  data: IconThemeData(
                    color: isActive ? colors.accentDark : colors.inkMuted,
                    size: 24,
                  ),
                  child: (isActive && item.activeIcon != null)
                      ? item.activeIcon!
                      : item.icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation item definition
class BottomNavItem {
  const BottomNavItem({
    required this.label,
    required this.icon,
    this.activeIcon,
  });

  final String label;
  final Widget icon;
  final Widget? activeIcon;
}

/// Predefined navigation items for Kioku
class KiokuNavItems {
  static List<BottomNavItem> standard() {
    return [
      BottomNavItem(
        label: 'Feed',
        icon: const Icon(Icons.auto_stories_outlined),
        activeIcon: const Icon(Icons.auto_stories),
      ),
      BottomNavItem(
        label: 'Albums',
        icon: const Icon(Icons.photo_library_outlined),
        activeIcon: const Icon(Icons.photo_library),
      ),
      BottomNavItem(
        label: 'Flashbacks',
        icon: const Icon(Icons.auto_awesome_outlined),
        activeIcon: const Icon(Icons.auto_awesome),
      ),
      BottomNavItem(
        label: 'Profile',
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person),
      ),
    ];
  }
}