import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingSm,
        AppTheme.spacingMd,
        AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionTile(
              label: 'Add Photo',
              icon: Icons.add_a_photo_outlined,
              isPrimary: true,
              colors: colors,
              typography: typography,
              onTap: () => context.push('/upload'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionTile(
              label: 'Albums',
              icon: Icons.photo_library_outlined,
              colors: colors,
              typography: typography,
              onTap: () => context.go('/albums'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionTile(
              label: 'Flashbacks',
              icon: Icons.auto_awesome_outlined,
              colors: colors,
              typography: typography,
              onTap: () => context.go('/flashbacks'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionTile(
              label: 'Profile',
              icon: Icons.person_outline,
              colors: colors,
              typography: typography,
              onTap: () => context.go('/profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    this.isPrimary = false,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isPrimary;
  final AppColors colors;
  final TextTheme typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      variant: isPrimary ? ClayVariant.defaultCard : ClayVariant.subtle,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: isPrimary ? colors.primaryDark : colors.inkMuted,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
              color: isPrimary ? colors.primaryDark : colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
