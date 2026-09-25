import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/util/kioku_log.dart';

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

  void removeOptimistic(String friendCode) {
    state.whenData((current) {
      state = AsyncValue.data(
        current.where((f) => f.friendCode != friendCode).toList(),
      );
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
    StateNotifierProvider<FriendsListNotifier, AsyncValue<List<FriendUser>>>((
      ref,
    ) {
      return FriendsListNotifier(ref);
    });

// --- Incoming Requests Notifier ---
class IncomingRequestsNotifier
    extends StateNotifier<AsyncValue<List<FriendRequest>>> {
  IncomingRequestsNotifier(this.ref, {bool startPeriodic = false})
    : super(const AsyncValue.loading()) {
    refresh();
    if (startPeriodic) {
      _startPeriodicPoll();
    }
  }

  final Ref ref;
  Timer? _pollTimer;

  void startPeriodicPoll() {
    if (_pollTimer == null || !_pollTimer!.isActive) {
      _startPeriodicPoll();
    }
  }

  void stopPeriodicPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startPeriodicPoll() {
    _pollTimer?.cancel();
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

    final now = DateTime.now().millisecondsSinceEpoch;
    // Optimistically add to friends list
    ref
        .read(friendsListProvider.notifier)
        .addOptimistic(
          FriendUser(
            friendCode: req.fromCode,
            username: req.fromName,
            createdAt: req.createdAt ?? now,
            updatedAt: now,
            status: 'accepted',
          ),
        );

    final ok = await UserProfileService.instance.acceptRequest(req);
    if (!ok && mounted) {
      state = AsyncValue.data(previous);
      ref.read(friendsListProvider.notifier).removeOptimistic(req.fromCode);
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
    StateNotifierProvider<
      IncomingRequestsNotifier,
      AsyncValue<List<FriendRequest>>
    >((ref) {
      return IncomingRequestsNotifier(ref);
    });

// --- Sent Requests Notifier ---
class SentRequestsNotifier
    extends StateNotifier<AsyncValue<List<SentFriendRequest>>> {
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
    final previous = state.valueOrNull ?? [];
    final now = DateTime.now().millisecondsSinceEpoch;
    // Optimistically update status to pending
    state = AsyncValue.data(
      previous.map((r) {
        if (r.id == requestId) {
          return SentFriendRequest(
            id: r.id,
            fromCode: r.fromCode,
            toCode: r.toCode,
            toName: r.toName,
            status: 'pending',
            createdAt: r.createdAt,
            updatedAt: now,
          );
        }
        return r;
      }).toList(),
    );

    final ok = await UserProfileService.instance.resendSentRequest(requestId);
    if (!ok && mounted) {
      state = AsyncValue.data(previous);
      return false;
    }
    return true;
  }
}

final sentRequestsProvider =
    StateNotifierProvider<
      SentRequestsNotifier,
      AsyncValue<List<SentFriendRequest>>
    >((ref) {
      return SentRequestsNotifier(ref);
    });

// --- Unread Badge Provider ---
final friendsUnreadBadgeProvider = Provider<int>((ref) {
  final incoming = ref.watch(incomingRequestsProvider);
  return incoming.valueOrNull?.length ?? 0;
});

// --- Invite Generation Lifecycle & Controller ---
enum InviteStatus { idle, generating, ready, expired, error }

class InviteUiState {
  final InviteStatus status;
  final InviteCreation? invite;
  final String? errorMessage;

  const InviteUiState({
    this.status = InviteStatus.idle,
    this.invite,
    this.errorMessage,
  });

  const InviteUiState.idle() : this(status: InviteStatus.idle);

  const InviteUiState.generating({InviteCreation? current})
    : this(status: InviteStatus.generating, invite: current);

  const InviteUiState.ready(InviteCreation invite)
    : this(status: InviteStatus.ready, invite: invite);

  const InviteUiState.expired(InviteCreation invite)
    : this(status: InviteStatus.expired, invite: invite);

  const InviteUiState.error(String message, {InviteCreation? fallback})
    : this(status: InviteStatus.error, errorMessage: message, invite: fallback);

  bool get isIdle => status == InviteStatus.idle;
  bool get isGenerating => status == InviteStatus.generating;
  bool get isReady => status == InviteStatus.ready;
  bool get isExpired => status == InviteStatus.expired;
  bool get isError => status == InviteStatus.error;

  /// Returns true if an invite exists and is not expired
  bool get hasValidInvite => invite != null && !invite!.isExpired;
}

class InviteController extends StateNotifier<InviteUiState> {
  InviteController({
    this.profileService,
    Future<InviteCreation?> Function({String? myName})? createInviteFn,
  }) : _createInviteFn = createInviteFn,
       super(const InviteUiState.idle());

  final UserProfileService? profileService;
  final Future<InviteCreation?> Function({String? myName})? _createInviteFn;
  UserProfileService get _service =>
      profileService ?? UserProfileService.instance;

  Future<InviteCreation?> _createInvite({String? myName}) {
    if (_createInviteFn != null) {
      return _createInviteFn(myName: myName);
    }
    return _service.createUniversalInvite(myName: myName);
  }

  Future<void>? _activeGeneration;

  /// Ensures an invite is generated.
  /// - If currently generating: returns the in-flight request (deduplication).
  /// - If already ready AND invite is not expired: returns immediately.
  /// - Otherwise (idle, expired, error): initiates a fresh invite creation.
  Future<void> ensureInviteGenerated({bool force = false}) async {
    // 1. Deduplicate concurrent in-flight generation requests
    if (state.isGenerating && _activeGeneration != null) {
      return _activeGeneration!;
    }

    // 2. If already ready and valid (not expired), do not regenerate unless forced
    if (!force && state.isReady && state.hasValidInvite) {
      return;
    }

    // 3. If ready but expired, mark expired before generating
    if (!force && state.invite != null && state.invite!.isExpired) {
      state = InviteUiState.expired(state.invite!);
    }

    _activeGeneration = _performGenerate();
    return _activeGeneration!;
  }

  Future<void> retry() => ensureInviteGenerated(force: true);

  void reset() {
    _activeGeneration = null;
    state = const InviteUiState.idle();
  }

  Future<void> _performGenerate() async {
    state = InviteUiState.generating(current: state.invite);
    try {
      final invite = await _createInvite();
      if (!mounted) return;

      if (invite != null) {
        if (invite.isExpired) {
          state = InviteUiState.expired(invite);
        } else {
          state = InviteUiState.ready(invite);
        }
      } else {
        state = const InviteUiState.error("Couldn't generate an invite link.");
      }
    } catch (e, st) {
      KiokuLog.e('InviteController', 'Failed to generate invite link', e, st);
      if (mounted) {
        state = const InviteUiState.error("Couldn't generate an invite link.");
      }
    } finally {
      _activeGeneration = null;
    }
  }
}

final inviteControllerProvider =
    StateNotifierProvider<InviteController, InviteUiState>((ref) {
      return InviteController();
    });

// --- Legacy Universal Invite Provider (Preserved for compatibility) ---
class UserInviteNotifier extends StateNotifier<AsyncValue<InviteCreation?>> {
  UserInviteNotifier({bool autoInit = false})
    : super(const AsyncValue.loading()) {
    if (autoInit) {
      loadOrGenerate();
    }
  }

  Future<void> loadOrGenerate({bool forceRefresh = false}) async {
    if (!forceRefresh && state.valueOrNull != null) return;
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
    StateNotifierProvider<UserInviteNotifier, AsyncValue<InviteCreation?>>((
      ref,
    ) {
      return UserInviteNotifier(autoInit: false);
    });
