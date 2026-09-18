/// FeedScreen — day-grouped memory feed for the active album, backed by the
/// signed-in user's own Google Drive.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_mobile/features/feed/presentation/widgets/memory_card.dart';

import 'package:flutter_mobile/features/feed/presentation/widgets/album_dropdown.dart';
import 'package:flutter_mobile/features/auth/presentation/widgets/username_dialog.dart';
import 'package:flutter_mobile/features/feed/presentation/widgets/shimmer_skeleton_card.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';
import 'package:flutter_mobile/shared/widgets/create_album_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('first_startup_completed', true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UsernameDialog.showIfNeeded(context);
      }
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;
      if (current >= max - 400) {
        ref.read(memoriesProvider.notifier).loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final memoriesAsync = ref.watch(memoriesProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(memoriesProvider.notifier).refresh(),
          color: colors.primary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: colors.background,
                elevation: 0,
                scrolledUnderElevation: 2,
                shadowColor: colors.shadow.withValues(alpha: 0.15),
                floating: true,
                snap: true,
                pinned: false,
                toolbarHeight: 88,
                expandedHeight: 88,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: _buildHeader(authState, colors, typography)
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: -0.06, end: 0, duration: 300.ms),
                ),
              ),
              ..._buildFeedSlivers(memoriesAsync, colors, typography),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingCapture(colors)
          .animate()
          .scale(delay: 600.ms, duration: 400.ms, curve: Curves.elasticOut),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader(
    AuthState authState,
    AppColors colors,
    TextTheme typography,
  ) {
    final profile = ref.watch(userProfileProvider);
    final storedName = profile.username;
    final firstName = storedName.isNotEmpty && storedName != 'Storyteller'
        ? storedName
        : (authState.displayName?.trim().split(' ').first ?? 'Friend');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        4,
        AppTheme.spacingMd,
        4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.divider, width: 1),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.08),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/kiokulogo.jpg', fit: BoxFit.cover),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Konnichiwa $firstName!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.displayMedium?.copyWith(
                    color: colors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                AlbumDropdown(
                  albums: ref.watch(albumsProvider).valueOrNull ?? [],
                  activeAlbumId: ref.watch(activeAlbumProvider),
                  colors: colors,
                  typography: typography,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeedSlivers(
    AsyncValue<List<KiokuMemory>> memoriesAsync,
    AppColors colors,
    TextTheme typography,
  ) {
    final loading = memoriesAsync.isLoading && memoriesAsync.value == null;
    final error = memoriesAsync.error;
    final items = memoriesAsync.value ?? <KiokuMemory>[];

    if (loading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            AppTheme.spacingSm,
            AppTheme.spacingMd,
            24,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: AppTheme.spacingMd),
                child: ShimmerSkeletonCard(),
              ),
              childCount: 3,
            ),
          ),
        ),
      ];
    }

    if (error != null && items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildErrorState(error.toString(), colors, typography),
        ),
      ];
    }

    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(colors, typography)
              .animate()
              .fadeIn(delay: 300.ms, duration: 300.ms),
        ),
      ];
    }

    final groups = ref.watch(groupedMemoriesProvider);
    final albumsList = ref.watch(albumsProvider).valueOrNull ?? [];
    final activeAlbumId = ref.watch(activeAlbumProvider);
    final currentAlbumName = albumsList.where((a) => a.id == activeAlbumId).firstOrNull?.title;

    final flatItems = <_FeedEntry>[];
    for (final group in groups) {
      flatItems.add(_FeedDayHeaderEntry(group.day));
      for (final item in group.items) {
        flatItems.add(_FeedMemoryEntry(item));
      }
    }
    final isPaginating = ref.watch(isPaginatingMemoriesProvider);

    return [
      SliverPadding(
        padding: const EdgeInsets.only(bottom: 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final entry = flatItems[index];
              if (entry is _FeedDayHeaderEntry) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd,
                    AppTheme.spacingMd,
                    AppTheme.spacingMd,
                    AppTheme.spacingSm,
                  ),
                  child: _buildDayHeader(entry.day, colors, typography),
                );
              } else if (entry is _FeedMemoryEntry) {
                final card = Padding(
                  key: ValueKey(entry.memory.id),
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd,
                    0,
                    AppTheme.spacingMd,
                    AppTheme.spacingMd,
                  ),
                  child: MemoryCard(
                    item: entry.memory,
                    colors: colors,
                    typography: typography,
                    albumName: entry.memory.albumName ??
                        albumsList.where((a) => a.id == entry.memory.albumId).firstOrNull?.title ??
                        currentAlbumName,
                  ),
                );
                final disableAnims = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
                if (disableAnims) return card;
                return card
                    .animate()
                    .fadeIn(
                      delay: (index * 35).clamp(0, 350).ms,
                      duration: 320.ms,
                    )
                    .slideY(
                      begin: 0.08,
                      end: 0,
                      duration: 320.ms,
                      curve: Curves.easeOutCubic,
                    );
              }
              return const SizedBox.shrink();
            },
            childCount: flatItems.length,
          ),
        ),
      ),
      if (isPaginating)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary,
                ),
              ),
            ),
          ),
        ),
      const SliverToBoxAdapter(
        child: SizedBox(height: 96),
      ),
    ];
  }

  String _dayLabel(DateTime day) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[day.weekday - 1]}, ${months[day.month - 1]} ${day.day}';
  }

  Widget _buildDayHeader(DateTime day, AppColors colors, TextTheme typography) {
    return Row(
      children: [
        Text(
          _dayLabel(day),
          style: typography.displaySmall?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colors.ink,
          ),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(child: Divider(color: colors.divider)),
      ],
    );
  }

  Widget _buildErrorState(String message, AppColors colors, TextTheme typography) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 56, color: colors.inkMuted),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            ClayButton(
              label: 'Retry',
              variant: ClayButtonVariant.secondary,
              onPressed: () => ref.read(memoriesProvider.notifier).refresh(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors, TextTheme typography) {
    final albums = ref.watch(albumsProvider).valueOrNull ?? [];
    final activeAlbumId = ref.watch(activeAlbumProvider);
    final activeAlbum = albums.where((a) => a.id == activeAlbumId).firstOrNull ??
        (albums.isNotEmpty ? albums.first : null);
    final hasAlbums = albums.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasAlbums ? Icons.photo_library_outlined : Icons.auto_stories_outlined,
              size: 64,
              color: colors.inkMuted,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'No memories yet',
              style: typography.headlineSmall?.copyWith(color: colors.ink, fontSize: 20),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              hasAlbums
                  ? (activeAlbum != null
                      ? 'Capture your first memory in "${activeAlbum.title}"'
                      : 'Capture your first memory to get started')
                  : 'Create your first album to get started preserving memories.',
              style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            ClayButton(
              label: hasAlbums ? 'Add a memory' : 'Create your first album',
              variant: ClayButtonVariant.primary,
              onPressed: () async {
                if (hasAlbums) {
                  context.push('/upload');
                } else {
                  final name = await CreateAlbumDialog.show(context);
                  if (name != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Album "$name" created')),
                    );
                  }
                }
              },
            ),
            if (hasAlbums) ...[
              const SizedBox(height: AppTheme.spacingSm),
              TextButton(
                onPressed: () async {
                  final name = await CreateAlbumDialog.show(context);
                  if (name != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Album "$name" created')),
                    );
                  }
                },
                child: Text(
                  'Create another album',
                  style: typography.bodySmall?.copyWith(color: colors.accentDark),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCapture(AppColors colors) {
    return FloatingActionButton.extended(
      onPressed: () => context.push('/upload'),
      backgroundColor: colors.primary,
      foregroundColor: colors.brightness == Brightness.dark ? const Color(0xFF140E0A) : Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
      icon: const Icon(Icons.add, size: 24),
      label: const Text('Capture'),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}

sealed class _FeedEntry {}

class _FeedDayHeaderEntry extends _FeedEntry {
  _FeedDayHeaderEntry(this.day);
  final DateTime day;
}

class _FeedMemoryEntry extends _FeedEntry {
  _FeedMemoryEntry(this.memory);
  final KiokuMemory memory;
}