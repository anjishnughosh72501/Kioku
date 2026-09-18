import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';

// --- Friends List Notifier ---
class FriendsListNotifier extends StateNotifier<AsyncValue<List<FriendUser>>> {
  FriendsListNotifier(this.ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref ref;

  Future<void> refresh() async {
    try {
      final friends = await UserProfileService.instance.getRemoteFriends();
      if (mounted) {
        state = AsyncValue.data(friends);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void addOptimistic(FriendUser user) {
    state.whenData((current) {
      if (!current.any((f) => f.friendCode == user.friendCode)) {
        state = AsyncValue.data([user, ...current]);
      }
    });
  }

  Future<bool> removeFriend(String friendCode) async {
    final previous = state.valueOrNull;
    if (previous != null) {
      state = AsyncValue.data(
        previous.where((f) => f.friendCode != friendCode).toList(),
      );
    }
    final ok = await UserProfileService.instance.removeFriend(friendCode);
    if (!ok && previous != null && mounted) {
      // Revert on failure
      state = AsyncValue.data(previous);
    }
    ref.invalidate(connectedFriendsProvider);
    return ok;
  }
}

final friendsListProvider =
    StateNotifierProvider<FriendsListNotifier, AsyncValue<List<FriendUser>>>((ref) {
  return FriendsListNotifier(ref);
});

// --- Incoming Requests Notifier ---
class IncomingRequestsNotifier extends StateNotifier<AsyncValue<List<FriendRequest>>> {
  IncomingRequestsNotifier(this.ref) : super(const AsyncValue.loading()) {
    refresh();
    _startPeriodicPoll();
  }

  final Ref ref;
  Timer? _pollTimer;

  void _startPeriodicPoll() {
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent && state.value == null) {
      state = const AsyncValue.loading();
    }
    try {
      final requests = await UserProfileService.instance.pollIncomingRequests();
      if (mounted) {
        state = AsyncValue.data(requests);
      }
    } catch (e, st) {
      if (mounted && !silent) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<bool> accept(FriendRequest req) async {
    final previous = state.valueOrNull ?? [];
    // Optimistic removal from incoming
    state = AsyncValue.data(previous.where((r) => r.id != req.id).toList());

    // Optimistically add to friends list
    ref.read(friendsListProvider.notifier).addOptimistic(
      FriendUser(friendCode: req.fromCode, username: req.fromName),
    );

    final ok = await UserProfileService.instance.acceptRequest(req);
    if (!ok && mounted) {
      state = AsyncValue.data(previous);
      ref.read(friendsListProvider.notifier).refresh();
      return false;
    }
    ref.invalidate(connectedFriendsProvider);
    return true;
  }

  Future<bool> decline(FriendRequest req) async {
    final previous = state.valueOrNull ?? [];
    state = AsyncValue.data(previous.where((r) => r.id != req.id).toList());

    final ok = await UserProfileService.instance.declineRequest(req);
    if (!ok && mounted) {
      state = AsyncValue.data(previous);
      return false;
    }
    return true;
  }
}

final incomingRequestsProvider =
    StateNotifierProvider<IncomingRequestsNotifier, AsyncValue<List<FriendRequest>>>((ref) {
  return IncomingRequestsNotifier(ref);
});

// --- Sent Requests Notifier ---
class SentRequestsNotifier extends StateNotifier<AsyncValue<List<SentFriendRequest>>> {
  SentRequestsNotifier(this.ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref ref;

  Future<void> refresh({bool silent = false}) async {
    if (!silent && state.value == null) {
      state = const AsyncValue.loading();
    }
    try {
      final sent = await UserProfileService.instance.getSentFriendRequests();
      if (mounted) {
        state = AsyncValue.data(sent);
      }
    } catch (e, st) {
      if (mounted && !silent) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<bool> cancel(String requestId) async {
    final previous = state.valueOrNull ?? [];
    state = AsyncValue.data(previous.where((r) => r.id != requestId).toList());

    final ok = await UserProfileService.instance.cancelSentRequest(requestId);
    if (!ok && mounted) {
      state = AsyncValue.data(previous);
      return false;
    }
    return true;
  }

  Future<bool> resend(String requestId) async {
    final ok = await UserProfileService.instance.resendSentRequest(requestId);
    if (ok) {
      await refresh();
    }
    return ok;
  }
}

final sentRequestsProvider =
    StateNotifierProvider<SentRequestsNotifier, AsyncValue<List<SentFriendRequest>>>((ref) {
  return SentRequestsNotifier(ref);
});

// --- Unread Badge Provider ---
final friendsUnreadBadgeProvider = Provider<int>((ref) {
  final incoming = ref.watch(incomingRequestsProvider);
  return incoming.valueOrNull?.length ?? 0;
});

// --- Short Universal Invite Provider ---
class UserInviteNotifier extends StateNotifier<AsyncValue<InviteCreation?>> {
  UserInviteNotifier() : super(const AsyncValue.loading()) {
    loadOrGenerate();
  }

  Future<void> loadOrGenerate({bool forceRefresh = false}) async {
    if (!forceRefresh && state.value != null) return;
    state = const AsyncValue.loading();
    try {
      final invite = await UserProfileService.instance.createUniversalInvite();
      if (mounted) {
        state = AsyncValue.data(invite);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }
}

final userInviteProvider =
    StateNotifierProvider<UserInviteNotifier, AsyncValue<InviteCreation?>>((ref) {
  return UserInviteNotifier();
});
