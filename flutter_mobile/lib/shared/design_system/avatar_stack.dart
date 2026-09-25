import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme/index.dart';

class AvatarItem {
  final String? name;
  final String? email;
  final String? imageUrl;

  const AvatarItem({this.name, this.email, this.imageUrl});

  String get initials {
    if (name != null && name!.trim().isNotEmpty) {
      final parts = name!.trim().split(' ');
      if (parts.length > 1) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    if (email != null && email!.trim().isNotEmpty) {
      return email!.substring(0, 1).toUpperCase();
    }
    return '?';
  }
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.avatars,
    this.size = 28,
    this.maxVisible = 4,
    this.overlap = 9,
    this.borderWidth = 2,
    this.borderColor,
    this.onTap,
  });

  final List<AvatarItem> avatars;
  final double size;
  final int maxVisible;
  final double overlap;
  final double borderWidth;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final effectiveBorderColor = borderColor ?? colors.surfaceContainerLow;

    if (avatars.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleCount = avatars.length > maxVisible
        ? maxVisible - 1
        : avatars.length;
    final remainingCount = avatars.length - visibleCount;

    final itemsToRender = avatars.take(visibleCount).toList();

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: size,
        width:
            size +
            (itemsToRender.length - 1 + (remainingCount > 0 ? 1 : 0)) *
                (size - overlap),
        child: Stack(
          children: [
            for (int i = 0; i < itemsToRender.length; i++)
              Positioned(
                left: i * (size - overlap),
                child: _buildAvatar(
                  context,
                  itemsToRender[i],
                  colors,
                  effectiveBorderColor,
                ),
              ),
            if (remainingCount > 0)
              Positioned(
                left: visibleCount * (size - overlap),
                child: _buildOverflow(
                  context,
                  remainingCount,
                  colors,
                  effectiveBorderColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    AvatarItem avatar,
    AppColors colors,
    Color effBorderColor,
  ) {
    // Generate a consistent warm tint based on avatar identity
    final hash = (avatar.name ?? avatar.email ?? 'avatar').hashCode.abs();
    final backgroundPalette = [
      colors.primary.withValues(alpha: 0.25),
      colors.accent.withValues(alpha: 0.25),
      colors.sage.withValues(alpha: 0.25),
      colors.amber.withValues(alpha: 0.25),
      colors.washiTapeMatcha.withValues(alpha: 0.35),
    ];
    final bgColor = backgroundPalette[hash % backgroundPalette.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(color: effBorderColor, width: borderWidth),
      ),
      alignment: Alignment.center,
      child: avatar.imageUrl != null && avatar.imageUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                avatar.imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildInitialsText(avatar.initials, colors),
              ),
            )
          : _buildInitialsText(avatar.initials, colors),
    );
  }

  Widget _buildInitialsText(String initials, AppColors colors) {
    return Text(
      initials,
      style: TextStyle(
        color: colors.ink,
        fontSize: size * 0.40,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
  }

  Widget _buildOverflow(
    BuildContext context,
    int count,
    AppColors colors,
    Color effBorderColor,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceContainerHighest,
        border: Border.all(color: effBorderColor, width: borderWidth),
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: TextStyle(
          color: colors.primary,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
