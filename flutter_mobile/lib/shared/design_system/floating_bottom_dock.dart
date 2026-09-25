import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobile/core/theme/index.dart';

class FloatingBottomDockItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const FloatingBottomDockItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class FloatingBottomDock extends StatelessWidget {
  const FloatingBottomDock({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.onCaptureTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onCaptureTap;
  final List<FloatingBottomDockItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final clayShadows = context.clayShadows;

    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: colors.divider.withValues(alpha: 0.8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
            ...clayShadows.floating,
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = index == currentIndex;
            final isCapture = item.label.toLowerCase() == 'capture';

            if (isCapture) {
              return _CaptureDockButton(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (onCaptureTap != null) {
                    onCaptureTap!();
                  } else {
                    onTap(index);
                  }
                },
              );
            }

            return _DockTabItem(
              item: item,
              isSelected: isSelected,
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(index);
              },
            );
          }),
        ),
      ),
    );
  }
}

class _DockTabItem extends StatelessWidget {
  const _DockTabItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final FloatingBottomDockItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                size: 22,
                color: isSelected ? colors.primary : colors.inkMuted,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureDockButton extends StatelessWidget {
  const _CaptureDockButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: colors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
