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
import 'package:flutter_mobile/shared/widgets/clay_card.dart';
import 'package:flutter_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_mobile/features/feed/presentation/widgets/album_dropdown.dart';
import 'package:flutter_mobile/features/feed/presentation/widgets/memory_card.dart';

import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/features/auth/presentation/widgets/username_dialog.dart';
import 'package:flutter_mobile/shared/widgets/create_album_dialog.dart';

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
    final albumsAsync = ref.watch(albumsProvider);
    final activeAlbumId = ref.watch(activeAlbumProvider);
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
              SliverToBoxAdapter(
                child: _buildHeader(activeAlbumId, albumsAsync, authState, colors, typography)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.1, end: 0, duration: 400.ms),
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
    String? activeAlbumId,
    AsyncValue<List<Album>> albumsAsync,
    AuthState authState,
    AppColors colors,
    TextTheme typography,
  ) {
    final storedName = UserProfileService.instance.username;
    final firstName = storedName.isNotEmpty && storedName != 'Storyteller'
        ? storedName
        : (authState.displayName?.trim().split(' ').first ?? 'Friend');
    final albums = albumsAsync.value ?? <Album>[];
    final active = albums.where((a) => a.id == activeAlbumId).firstOrNull;
    final currentYear = active != null
        ? ''
        : '${DateTime.now().year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $firstName',
                  style: typography.bodyMedium?.copyWith(
                    color: colors.inkMuted,
                    fontSize: 14,
                  ),
                ),
                if (albums.isEmpty)
                  Text(
                    'Your memory album',
                    style: typography.bodyMedium?.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  AlbumDropdown(
                    albums: albums,
                    activeAlbumId: activeAlbumId,
                    colors: colors,
                    typography: typography,
                  ),
              ],
            ),
          ),
          if (currentYear.isNotEmpty)
            Text(
              currentYear,
              style: typography.bodyMedium?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w500,
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
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator(color: colors.primary)),
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
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd,
                    0,
                    AppTheme.spacingMd,
                    AppTheme.spacingMd,
                  ),
                  child: MemoryCard(item: entry.memory, colors: colors, typography: typography),
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
            fontFamily: 'Fraunces',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_stories_outlined, size: 64, color: colors.inkMuted),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'No memories yet',
              style: typography.headlineSmall?.copyWith(color: colors.ink, fontSize: 20),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Capture your first memory to get started',
              style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            ClayButton(
              label: 'Create your first album',
              variant: ClayButtonVariant.primary,
              onPressed: () async {
                final name = await CreateAlbumDialog.show(context);
                if (name != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Album "$name" created')),
                  );
                }
              },
            ),
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