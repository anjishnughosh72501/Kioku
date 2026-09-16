import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';
import 'package:flutter_mobile/shared/widgets/create_album_dialog.dart';

class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final albumsAsync = ref.watch(albumsProvider);
    final albums = albumsAsync.value ?? <Album>[];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Albums',
          style: typography.displayLarge?.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Create New Album',
            icon: Icon(Icons.add_circle_outline, color: colors.primary, size: 26),
            onPressed: () async {
              final name = await CreateAlbumDialog.show(context);
              if (name != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Album "$name" created')),
                  );
 }
 },
 ),
 const SizedBox(width: 8),
 ],
 ),
 body: SafeArea(
 child: RefreshIndicator(
 color: colors.primary,
 onRefresh: () async {
 await ref.read(albumsProvider.notifier).refresh();
 },
 child: albumsAsync.isLoading && albums.isEmpty
 ? Center(child: CircularProgressIndicator(color: colors.primary))
 : albums.isEmpty
 ? _buildEmptyState(context, colors, typography)
 : _buildAlbumGrid(context, ref, albums, colors, typography),
 ),
 ),
 );
 }

 Widget _buildEmptyState(
 BuildContext context,
 AppColors colors,
 TextTheme typography,
 ) {
 return ListView(
 physics: const AlwaysScrollableScrollPhysics(),
 children: [
 const SizedBox(height: 100),
 Center(
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(
 Icons.photo_library_outlined,
 size: 64,
 color: colors.inkMuted.withValues(alpha: 0.6),
 ),
 const SizedBox(height: AppTheme.spacingLg),
 Text(
 'No albums yet',
 style: typography.headlineSmall?.copyWith(
 color: colors.ink,
 fontSize: 20,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: AppTheme.spacingSm),
 Text(
 'Create an album to organize your photos and share with close friends.',
 textAlign: TextAlign.center,
 style: typography.bodyMedium?.copyWith(
 color: colors.inkMuted,
 ),
 ),
 const SizedBox(height: AppTheme.spacingLg),
 ClayButton(
 label: 'Create First Album',
 icon: const Icon(Icons.add, size: 18),
 variant: ClayButtonVariant.primary,
 onPressed: () => CreateAlbumDialog.show(context),
 ),
 ],
 ),
 ),
 ),
 ],
 );
 }

 Widget _buildAlbumGrid(
 BuildContext context,
 WidgetRef ref,
 List<Album> albums,
 AppColors colors,
 TextTheme typography,
 ) {
 return GridView.builder(
 physics: const AlwaysScrollableScrollPhysics(),
 padding: const EdgeInsets.all(AppTheme.spacingMd),
 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
 crossAxisCount: 2,
 crossAxisSpacing: 14,
 mainAxisSpacing: 14,
 childAspectRatio: 0.88,
 ),
 itemCount: albums.length,
 itemBuilder: (context, index) {
 final album = albums[index];
 return _buildAlbumTile(context, ref, album, colors, typography);
 },
 );
 }

 Widget _buildAlbumTile(
 BuildContext context,
 WidgetRef ref,
 Album album,
 AppColors colors,
 TextTheme typography,
 ) {
 final albumTint = colors.withAlbumTint(album.id);

 return ClayCard(
 variant: ClayVariant.defaultCard,
 padding: EdgeInsets.zero,
 onTap: () {
        ref.read(activeAlbumProvider.notifier).set(album.id);
        context.push('/albums/${album.id}', extra: album);
      },
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 Expanded(
 child: Container(
 decoration: BoxDecoration(
 color: albumTint.accentSoft.withValues(alpha: 0.5),
 borderRadius: BorderRadius.vertical(
 top: Radius.circular(AppTheme.radiusCard),
 ),
 ),
 child: Center(
 child: Icon(
 Icons.photo_library_rounded,
 size: 44,
 color: albumTint.primaryDark,
 ),
 ),
 ),
 ),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 album.title,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: typography.bodyMedium?.copyWith(
 color: colors.ink,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 3),
 Row(
 children: [
 Icon(
 Icons.folder_shared_outlined,
 size: 13,
 color: colors.inkMuted,
 ),
 const SizedBox(width: 4),
 Expanded(
 child: Text(
 'Album',
 style: typography.bodySmall?.copyWith(
 fontSize: 11,
 color: colors.inkMuted,
 ),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }
}
