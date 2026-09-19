/// KiokuShell — Main app shell with bottom navigation and floating capture button
/// Used as the shell for StatefulShellRoute.indexedStack
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mobile/shared/design_system/floating_bottom_dock.dart';


class KiokuShell extends StatelessWidget {
  const KiokuShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const List<FloatingBottomDockItem> _dockItems = [
    FloatingBottomDockItem(
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories_rounded,
      label: 'Home',
    ),
    FloatingBottomDockItem(
      icon: Icons.photo_library_outlined,
      activeIcon: Icons.photo_library_rounded,
      label: 'Albums',
    ),
    FloatingBottomDockItem(
      icon: Icons.add_rounded,
      activeIcon: Icons.add_rounded,
      label: 'Capture',
    ),
    FloatingBottomDockItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Friends',
    ),
    FloatingBottomDockItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  int _mapBranchToDock(int branchIndex) {
    switch (branchIndex) {
      case 0:
        return 0; // Home
      case 1:
        return 1; // Albums
      case 2:
        return 3; // Friends
      case 3:
        return 4; // Profile
      default:
        return 0;
    }
  }

  void _onDockTap(int dockIndex, BuildContext context) {
    switch (dockIndex) {
      case 0:
        navigationShell.goBranch(0, initialLocation: navigationShell.currentIndex == 0);
        break;
      case 1:
        navigationShell.goBranch(1, initialLocation: navigationShell.currentIndex == 1);
        break;
      case 2:
        context.push('/upload');
        break;
      case 3:
        navigationShell.goBranch(2, initialLocation: navigationShell.currentIndex == 2);
        break;
      case 4:
        navigationShell.goBranch(3, initialLocation: navigationShell.currentIndex == 3);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.015, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(navigationShell.currentIndex),
          child: navigationShell,
        ),
      ),
      bottomNavigationBar: FloatingBottomDock(
        currentIndex: _mapBranchToDock(navigationShell.currentIndex),
        onTap: (dockIndex) => _onDockTap(dockIndex, context),
        onCaptureTap: () => context.push('/upload'),
        items: _dockItems,
      ),
    );
  }
}