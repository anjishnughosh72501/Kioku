import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/create_album_dialog.dart';
import 'package:share_plus/share_plus.dart';

/// Compact album switcher shown in the feed header.
class AlbumDropdown extends ConsumerWidget {
  const AlbumDropdown({
    super.key,
    required this.albums,
    required this.activeAlbumId,
    required this.colors,
    required this.typography,
  });

  final List<Album> albums;
  final String? activeAlbumId;
  final AppColors colors;
  final TextTheme typography;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAll = activeAlbumId == null || activeAlbumId == 'all' || activeAlbumId!.isEmpty;
    final current = isAll ? null : albums.where((a) => a.id == activeAlbumId).firstOrNull;
    final effectiveColors = (!isAll && activeAlbumId != null)
        ? colors.withAlbumTint(activeAlbumId!)
        : colors;

    return InkWell(
      onTap: () => _showPicker(context, ref),
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
        decoration: BoxDecoration(
          color: effectiveColors.accentSoft,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: effectiveColors.primary.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                isAll ? 'All updates' : (current?.title ?? 'Pick an album'),
                overflow: TextOverflow.ellipsis,
                style: typography.bodySmall?.copyWith(
                  color: effectiveColors.primaryDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: effectiveColors.primaryDark),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    final isAll = activeAlbumId == null || activeAlbumId == 'all' || activeAlbumId!.isEmpty;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Text(
                'Filter Feed',
                style: typography.headlineSmall?.copyWith(color: colors.ink),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.dynamic_feed_outlined,
                color: isAll ? colors.primaryDark : colors.inkMuted,
              ),
              title: Text(
                'All updates',
                style: typography.bodyMedium?.copyWith(
                  color: colors.ink,
                  fontWeight: isAll ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              trailing: isAll
                  ? Icon(Icons.check_circle, color: colors.primaryDark, size: 20)
                  : null,
              onTap: () {
                ref.read(activeAlbumProvider.notifier).set(null);
                Navigator.of(sheetContext).pop();
              },
            ),
            ...albums.map((album) {
              final selected = album.id == activeAlbumId;
              final rowColors = colors.withAlbumTint(album.id);
              return ListTile(
                title: Text(
                  album.title,
                  style: typography.bodyMedium?.copyWith(
                    color: colors.ink,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: selected ? rowColors.accentSoft : colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    selected ? Icons.folder_special : Icons.folder_outlined,
                    color: selected ? rowColors.primaryDark : colors.inkMuted,
                    size: 20,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.share_outlined, size: 18, color: colors.accentDark),
                      tooltip: 'Invite friends to album',
                      onPressed: () {
                        final userProfile = ref.read(userProfileProvider);
                        final link = 'https://kioku.app/invite?albumId=${album.id}&albumName=${Uri.encodeComponent(album.title)}&friendCode=${Uri.encodeComponent(userProfile.friendCode)}&from=${Uri.encodeComponent(userProfile.username)}';
                        final appUri = 'kioku://invite?albumId=${album.id}&albumName=${Uri.encodeComponent(album.title)}&friendCode=${Uri.encodeComponent(userProfile.friendCode)}&from=${Uri.encodeComponent(userProfile.username)}';
                        Share.share(
                          'Join my memory album "${album.title}" on Kioku!\n\n'
                          'Tap to open and join:\n$link\n\n'
                          'Or app link: $appUri',
                          subject: 'Kioku Memory Album: ${album.title}',
                        );
                      },
                    ),
                    if (selected) Icon(Icons.check_circle, color: rowColors.primaryDark, size: 20),
                  ],
                ),
                onTap: () {
                  ref.read(activeAlbumProvider.notifier).set(album.id);
                  Navigator.of(sheetContext).pop();
                },
              );
            }),
            ListTile(
              leading: Icon(Icons.create_new_folder_outlined, color: colors.accent),
              title: Text('New album…', style: typography.bodyMedium?.copyWith(color: colors.accentDark)),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final name = await CreateAlbumDialog.show(context);
                if (name != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Album "$name" created')),
                  );
                }
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),
          ],
        ),
      ),
    );
  }
}
