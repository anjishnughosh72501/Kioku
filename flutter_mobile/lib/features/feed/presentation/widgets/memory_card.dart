import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';
import 'package:flutter_mobile/shared/widgets/drive_thumb.dart';

class MemoryCard extends StatelessWidget {
  const MemoryCard({
    super.key,
    required this.item,
    required this.colors,
    required this.typography,
  });

  final KiokuMemory item;
  final AppColors colors;
  final TextTheme typography;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      variant: ClayVariant.defaultCard,
      padding: EdgeInsets.zero,
      onTap: () => context.push('/media/${item.id}', extra: item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
              child: DriveThumb(memory: item),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.accentSoft,
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Text(
                        item.uploaderLabel,
                        style: typography.bodySmall?.copyWith(
                          color: colors.accentDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.postmarkDate,
                      style: typography.bodySmall?.copyWith(color: colors.inkMuted, fontSize: 11),
                    ),
                  ],
                ),
                if (item.caption != null && item.caption!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.headlineSmall?.copyWith(fontSize: 15, color: colors.ink),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
