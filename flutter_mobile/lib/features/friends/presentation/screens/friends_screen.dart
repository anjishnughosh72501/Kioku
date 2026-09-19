import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/features/friends/presentation/controllers/friends_controller.dart';
import 'package:flutter_mobile/features/friends/presentation/widgets/invite_accept_dialog.dart';
import 'package:flutter_mobile/features/friends/presentation/widgets/invite_share_sheet.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final unreadCount = ref.watch(friendsUnreadBadgeProvider);
    final friendsAsync = ref.watch(friendsListProvider);
    final sentAsync = ref.watch(sentRequestsProvider);

    final friendsCount = friendsAsync.valueOrNull?.length ?? 0;
    final sentCount = sentAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.ink, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Friends & Connections',
          style: typography.headlineSmall?.copyWith(
            color: colors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Invite Friends',
            icon: Icon(Icons.qr_code_rounded, color: colors.primary),
            onPressed: () => InviteShareSheet.show(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.divider, width: 0.8),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: colors.inkMuted,
              labelStyle: typography.bodySmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle: typography.bodySmall?.copyWith(fontWeight: FontWeight.w500, fontSize: 12),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Friends'),
                      if (friendsCount > 0) ...[
                        const SizedBox(width: 4),
                        Text('($friendsCount)', style: const TextStyle(fontSize: 10)),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Incoming'),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Sent'),
                      if (sentCount > 0) ...[
                        const SizedBox(width: 4),
                        Text('($sentCount)', style: const TextStyle(fontSize: 10)),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Add'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (UserProfileService.instance.authStatus == FriendAuthStatus.offline)
            Container(
              color: Colors.amber.shade800,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline mode — showing cached friends. Reconnect to sync.',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FriendsTab(onSwitchToAdd: () => _tabController.animateTo(3)),
                const _IncomingTab(),
                const _SentTab(),
                _AddFriendTab(onInviteTap: () => InviteShareSheet.show(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 1: ACCEPTED FRIENDS
// ==========================================
class _FriendsTab extends ConsumerWidget {
  const _FriendsTab({required this.onSwitchToAdd});

  final VoidCallback onSwitchToAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final friendsAsync = ref.watch(friendsListProvider);

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => ref.read(friendsListProvider.notifier).refresh(),
      child: friendsAsync.when(
        data: (friends) {
          if (friends.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.spacingXl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.divider),
                      ),
                      child: Icon(Icons.people_outline_rounded, size: 40, color: colors.inkMuted),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    Text(
                      'No friends yet',
                      style: typography.titleLarge?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Invite someone to begin sharing encrypted memories & shared albums.',
                      textAlign: TextAlign.center,
                      style: typography.bodyMedium?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    ClayButton(
                      label: 'Invite Friends',
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                      variant: ClayButtonVariant.primary,
                      onPressed: onSwitchToAdd,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            itemCount: friends.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final friend = friends[index];
              return _FriendCard(friend: friend);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading friends: $err', style: TextStyle(color: colors.primary)),
              const SizedBox(height: 12),
              ClayButton(
                label: 'Retry',
                size: ClayButtonSize.small,
                onPressed: () => ref.read(friendsListProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendCard extends ConsumerWidget {
  const _FriendCard({required this.friend});

  final FriendUser friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final displayName = friend.username?.isNotEmpty == true ? friend.username! : friend.friendCode;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return ClayCard(
      variant: ClayVariant.defaultCard,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(
                initial,
                style: typography.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayName,
                      style: typography.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Connected',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Code: ${friend.friendCode} • Memory Partner',
                  style: typography.bodySmall?.copyWith(
                    color: colors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded, color: colors.inkMuted),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: colors.surfaceContainer,
            onSelected: (action) async {
              if (action == 'albums') {
                context.push('/albums');
              } else if (action == 'remove') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: colors.surfaceContainer,
                    title: const Text('Remove Friend'),
                    content: Text('Are you sure you want to remove $displayName from your friends?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(friendsListProvider.notifier).removeFriend(friend.friendCode);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Removed $displayName from friends')),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'albums', child: Text('Shared Albums')),
              const PopupMenuItem(value: 'remove', child: Text('Remove Friend', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 2: INCOMING REQUESTS
// ==========================================
class _IncomingTab extends ConsumerWidget {
  const _IncomingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final incomingAsync = ref.watch(incomingRequestsProvider);

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => ref.read(incomingRequestsProvider.notifier).refresh(),
      child: incomingAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.spacingXl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.divider),
                      ),
                      child: Icon(Icons.inbox_rounded, size: 40, color: colors.inkMuted),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    Text(
                      'No incoming requests',
                      style: typography.titleLarge?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'When someone adds you using your Friend Code or short invite link, their request appears here.',
                      textAlign: TextAlign.center,
                      style: typography.bodyMedium?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final req = requests[index];
              return _IncomingCard(request: req);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading requests: $err', style: TextStyle(color: colors.primary)),
        ),
      ),
    );
  }
}

class _IncomingCard extends ConsumerStatefulWidget {
  const _IncomingCard({required this.request});

  final FriendRequest request;

  @override
  ConsumerState<_IncomingCard> createState() => _IncomingCardState();
}

class _IncomingCardState extends ConsumerState<_IncomingCard> {
  bool _acting = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final name = widget.request.fromName ?? widget.request.fromCode;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return ClayCard(
      variant: ClayVariant.defaultCard,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: typography.titleMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: typography.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    Text(
                      'Wants to connect • Code: ${widget.request.fromCode}',
                      style: typography.bodySmall?.copyWith(
                        color: colors.inkMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _acting
                      ? null
                      : () async {
                          setState(() => _acting = true);
                          await ref.read(incomingRequestsProvider.notifier).decline(widget.request);
                        },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    ),
                  ),
                  child: Text('Decline', style: TextStyle(color: colors.inkMuted)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ClayButton(
                  label: _acting ? 'Accepting...' : 'Accept',
                  variant: ClayButtonVariant.primary,
                  size: ClayButtonSize.small,
                  onPressed: _acting
                      ? () {}
                      : () async {
                          setState(() => _acting = true);
                          final ok = await ref
                              .read(incomingRequestsProvider.notifier)
                              .accept(widget.request);
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Connected with $name!')),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 3: SENT REQUESTS
// ==========================================
class _SentTab extends ConsumerWidget {
  const _SentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final sentAsync = ref.watch(sentRequestsProvider);

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => ref.read(sentRequestsProvider.notifier).refresh(),
      child: sentAsync.when(
        data: (sentRequests) {
          if (sentRequests.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.spacingXl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.divider),
                      ),
                      child: Icon(Icons.outbox_rounded, size: 40, color: colors.inkMuted),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    Text(
                      'No sent requests',
                      style: typography.titleLarge?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Friend requests you send to others will be tracked here until accepted.',
                      textAlign: TextAlign.center,
                      style: typography.bodyMedium?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            itemCount: sentRequests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final req = sentRequests[index];
              return _SentCard(req: req);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading sent requests: $err', style: TextStyle(color: colors.primary)),
        ),
      ),
    );
  }
}

class _SentCard extends ConsumerStatefulWidget {
  const _SentCard({required this.req});

  final SentFriendRequest req;

  @override
  ConsumerState<_SentCard> createState() => _SentCardState();
}

class _SentCardState extends ConsumerState<_SentCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final targetName = widget.req.toName ?? widget.req.toCode;
    final isExpired = widget.req.isExpired;

    return ClayCard(
      variant: ClayVariant.defaultCard,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: Border.all(color: colors.divider),
            ),
            child: Center(
              child: Icon(Icons.send_rounded, size: 20, color: colors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  targetName,
                  style: typography.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? Colors.redAccent.withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isExpired ? 'Expired' : 'Pending',
                        style: TextStyle(
                          color: isExpired ? Colors.redAccent : Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.req.toCode,
                      style: typography.bodySmall?.copyWith(
                        color: colors.inkMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isExpired) ...[
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await ref.read(sentRequestsProvider.notifier).resend(widget.req.id);
                      if (mounted) setState(() => _busy = false);
                    },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
              ),
              child: Text('Resend', style: TextStyle(color: colors.primary, fontSize: 12)),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await ref.read(sentRequestsProvider.notifier).cancel(widget.req.id);
                      if (mounted) setState(() => _busy = false);
                    },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.divider),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
              ),
              child: Text('Cancel', style: TextStyle(color: colors.inkMuted, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// TAB 4: ADD FRIEND (METHOD A & B)
// ==========================================
class _AddFriendTab extends ConsumerStatefulWidget {
  const _AddFriendTab({required this.onInviteTap});

  final VoidCallback onInviteTap;

  @override
  ConsumerState<_AddFriendTab> createState() => _AddFriendTabState();
}

class _AddFriendTabState extends ConsumerState<_AddFriendTab> {
  final _codeController = TextEditingController();
  final _linkController = TextEditingController();
  bool _submittingCode = false;
  bool _resolvingLink = false;
  String? _codeError;
  String? _linkError;

  @override
  void dispose() {
    _codeController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _submitFriendCode() async {
    final text = _codeController.text.trim().toUpperCase();
    if (text.isEmpty) {
      setState(() => _codeError = 'Please enter a friend code');
      return;
    }
    final myCode = UserProfileService.instance.friendCode.trim().toUpperCase();
    if (text == myCode) {
      setState(() => _codeError = 'You cannot add your own code');
      return;
    }

    final friends = await UserProfileService.instance.getConnectedFriends();
    if (friends.contains(text)) {
      setState(() => _codeError = 'You are already connected with this friend');
      return;
    }

    final sent = await UserProfileService.instance.getSentFriendRequests();
    if (sent.any((r) => r.toCode.trim().toUpperCase() == text && r.isPending)) {
      setState(() => _codeError = 'A request to this friend is already pending');
      return;
    }

    setState(() {
      _submittingCode = true;
      _codeError = null;
    });

    FriendLookupResult? lookup;
    try {
      lookup = await UserProfileService.instance.lookupFriendCode(text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submittingCode = false;
        _codeError = e is FriendException ? e.message : 'Unable to verify friend code';
      });
      return;
    }

    if (!mounted) return;

    if (lookup == null) {
      setState(() {
        _submittingCode = false;
        _codeError = 'Friend code not found. Please verify spelling.';
      });
      return;
    }

    // Show pre-send confirmation dialog
    final recipientName = lookup.displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Friend Request?'),
        content: Text('Do you want to send a friend request to $recipientName ($text)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() => _submittingCode = false);
      return;
    }

    final res = await UserProfileService.instance.sendFriendRequest(
      text,
      myName: UserProfileService.instance.username,
    );

    if (!mounted) return;
    setState(() => _submittingCode = false);

    if (res == FriendRequestResult.sent || res == FriendRequestResult.alreadySent) {
      _codeController.clear();
      ref.read(sentRequestsProvider.notifier).refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to $recipientName!')),
      );
    } else if (res == FriendRequestResult.alreadyFriends) {
      setState(() => _codeError = 'Already in your friends list');
    } else {
      setState(() => _codeError = 'Could not send request. Check code and connection.');
    }
  }

  Future<void> _resolvePastedLink() async {
    final text = _linkController.text.trim();
    if (text.isEmpty) {
      setState(() => _linkError = 'Please paste an invite link or code');
      return;
    }

    String code = text;
    if (code.contains('/i/')) {
      code = code.split('/i/').last.split('?').first.split('/').first;
    } else if (code.contains('/invite/')) {
      code = code.split('/invite/').last.split('?').first.split('/').first;
    }

    code = code.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _linkError = 'Invalid invite link format');
      return;
    }

    setState(() {
      _resolvingLink = true;
      _linkError = null;
    });

    _linkController.clear();
    setState(() => _resolvingLink = false);

    InviteAcceptDialog.show(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner: Share Your Own Invite
          ClayCard(
            variant: ClayVariant.elevated,
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.qr_code_2_rounded, size: 28, color: colors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Your Invite Link',
                        style: typography.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      Text(
                        'Generate a short link or QR code to share via chat.',
                        style: typography.bodySmall?.copyWith(
                          color: colors.inkMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                ClayButton(
                  label: 'Share',
                  size: ClayButtonSize.small,
                  variant: ClayButtonVariant.primary,
                  onPressed: widget.onInviteTap,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingLg),

          // Method A: Enter Friend Code
          ClayCard(
            variant: ClayVariant.defaultCard,
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.pin_outlined, size: 20, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Method A — Friend Code',
                      style: typography.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your friend\'s unique 8-character Kioku code:',
                  style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'e.g. ABCD1234',
                    errorText: _codeError,
                    prefixIcon: Icon(Icons.badge_outlined, color: colors.primary),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                ClayButton(
                  label: _submittingCode ? 'Sending...' : 'Add Friend',
                  variant: ClayButtonVariant.secondary,
                  onPressed: _submittingCode ? () {} : _submitFriendCode,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingLg),

          // Method B: Short Link / QR Scanner
          ClayCard(
            variant: ClayVariant.defaultCard,
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 20, color: colors.accentDark),
                    const SizedBox(width: 8),
                    Text(
                      'Method B — Short Link / QR Code',
                      style: typography.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Paste a kioku.app/i/XXXXXX short link or invite code to connect:',
                  style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                TextField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    hintText: 'kioku.app/i/8F3KD2 or code',
                    errorText: _linkError,
                    prefixIcon: Icon(Icons.link_rounded, color: colors.accentDark),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste_rounded, size: 18),
                      tooltip: 'Paste from clipboard',
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          _linkController.text = data!.text!.trim();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                ClayButton(
                  label: _resolvingLink ? 'Checking...' : 'Open Invite Confirmation',
                  variant: ClayButtonVariant.primary,
                  onPressed: _resolvingLink ? () {} : _resolvePastedLink,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
