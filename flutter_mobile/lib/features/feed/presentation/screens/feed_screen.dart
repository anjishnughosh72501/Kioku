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
import 'package:flutter_mobile/features/feed/presentation/controllers/feed_controller.dart';
import 'package:flutter_mobile/features/feed/presentation/widgets/memory_card.dart';

import 'package:flutter_mobile/features/feed/presentation/widgets/album_dropdown.dart';
import 'package:flutter_mobile/features/auth/presentation/widgets/username_dialog.dart';

import 'package:flutter_mobile/features/friends/presentation/controllers/friends_controller.dart';
import 'package:flutter_mobile/features/friends/presentation/widgets/invite_accept_dialog.dart';
import 'package:flutter_mobile/core/services/deep_link_service.dart';
import 'package:flutter_mobile/shared/design_system/index.dart';
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
      final hasPrompted = prefs.getBool('kioku_username_prompted') ?? false;
      if (!hasPrompted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            UsernameDialog.showIfNeeded(context);
          }
        });
      }
      final pendingInvite = prefs.getString('pending_invite_code');
      if (pendingInvite != null && pendingInvite.isNotEmpty) {
        prefs.remove('pending_invite_code');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            InviteAcceptDialog.show(context, pendingInvite);
          }
        });
      }
      final pendingLink = prefs.getString('pending_deep_link');
      if (pendingLink != null && pendingLink.isNotEmpty) {
        prefs.remove('pending_deep_link');
        final uri = Uri.tryParse(pendingLink);
        if (uri != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              DeepLinkService.handleIncomingUri(uri: uri, ref: ref, context: context);
            }
          });
        }
      }
      prefs.setBool('first_startup_completed', true);
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;
      if (FeedController.shouldPrefetch(offset: current, maxScrollExtent: max)) {
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
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(friendsUnreadBadgeProvider);
              return IconButton(
                tooltip: 'Friends & Connections',
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread', style: const TextStyle(fontSize: 10)),
                  backgroundColor: colors.primary,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.divider),
                    ),
                    child: Icon(Icons.people_alt_outlined, size: 20, color: colors.ink),
                  ),
                ),
                onPressed: () => context.push('/friends'),
              );
            },
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
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                child: index == 0
                    ? const MemorySkeleton(isHero: true)
                    : const MemorySkeleton(),
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
                final isFirstMemory = entry.memory.id == items.first.id;
                final card = Padding(
                  key: ValueKey(entry.memory.id),
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd,
                    0,
                    AppTheme.spacingMd,
                    AppTheme.spacingMd,
                  ),
                  child: isFirstMemory
                      ? HeroMemoryCard(
                          item: entry.memory,
                          badgeLabel: "TODAY'S MEMORY",
                          albumName: entry.memory.albumName ??
                              albumsList.where((a) => a.id == entry.memory.albumId).firstOrNull?.title ??
                              currentAlbumName,
                        )
                      : MemoryCard(
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final memoryDay = DateTime(day.year, day.month, day.day);
    final diffDays = today.difference(memoryDay).inDays;

    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    if (diffDays > 1 && diffDays < 7) {
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return 'This ${days[day.weekday - 1]}';
    }

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
    return '${months[day.month - 1]} ${day.day}, ${day.year}';
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

    return KiokuEmptyState(
      icon: hasAlbums ? Icons.photo_library_outlined : Icons.auto_stories_outlined,
      title: 'No memories yet',
      subtitle: hasAlbums
          ? (activeAlbum != null
              ? 'Capture your first memory in "${activeAlbum.title}"'
              : 'Capture your first memory to get started')
          : 'Create your first album to get started preserving memories.',
      buttonText: hasAlbums ? 'Add a memory' : 'Create your first album',
      onButtonPressed: () async {
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
      secondaryButtonText: hasAlbums ? 'Create another album' : null,
      onSecondaryPressed: hasAlbums
          ? () async {
              final name = await CreateAlbumDialog.show(context);
              if (name != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Album "$name" created')),
                );
              }
            }
          : null,
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