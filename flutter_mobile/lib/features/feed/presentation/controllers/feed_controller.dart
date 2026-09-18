import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';

/// Feed pagination and scroll-prefetching controller for Kioku v4.0.
class FeedPaginationState {
  final List<KiokuMemory> items;
  final bool isLoading;
  final bool isPaginating;
  final bool hasMore;
  final String? nextPageToken;

  const FeedPaginationState({
    this.items = const [],
    this.isLoading = false,
    this.isPaginating = false,
    this.hasMore = true,
    this.nextPageToken,
  });

  FeedPaginationState copyWith({
    List<KiokuMemory>? items,
    bool? isLoading,
    bool? isPaginating,
    bool? hasMore,
    String? nextPageToken,
  }) {
    return FeedPaginationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isPaginating: isPaginating ?? this.isPaginating,
      hasMore: hasMore ?? this.hasMore,
      nextPageToken: nextPageToken ?? this.nextPageToken,
    );
  }
}

class FeedController extends StateNotifier<FeedPaginationState> {
  final Ref _ref;
  static const int pageSize = 20;

  FeedController(this._ref) : super(const FeedPaginationState());

  /// Returns true if the scroll position indicates that the next page should be prefetched
  /// (when offset reaches 80% of total scrollable extent, or within 400px of bottom).
  static bool shouldPrefetch({
    required double offset,
    required double maxScrollExtent,
  }) {
    if (maxScrollExtent <= 0) return false;
    final reached80Percent = offset >= (maxScrollExtent * 0.8);
    final within400Px = offset >= (maxScrollExtent - 400);
    return reached80Percent || within400Px;
  }

  /// Check scroll position and trigger prefetch if needed.
  void onScrollPositionChanged({
    required double offset,
    required double maxScrollExtent,
  }) {
    if (shouldPrefetch(offset: offset, maxScrollExtent: maxScrollExtent)) {
      loadNextPage();
    }
  }

  Future<void> loadNextPage() async {
    if (state.isPaginating || !state.hasMore) return;
    state = state.copyWith(isPaginating: true);
    try {
      await _ref.read(memoriesProvider.notifier).loadMore();
    } finally {
      state = state.copyWith(isPaginating: false);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      await _ref.read(memoriesProvider.notifier).refresh();
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final feedControllerProvider =
    StateNotifierProvider<FeedController, FeedPaginationState>((ref) {
  return FeedController(ref);
});
