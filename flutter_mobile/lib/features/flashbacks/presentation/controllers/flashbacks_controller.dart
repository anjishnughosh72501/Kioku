import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';

class FlashbacksState {
  final List<FlashbackSetData> sets;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, Uint8List> loadedThumbnails;

  const FlashbacksState({
    this.sets = const [],
    this.isLoading = false,
    this.errorMessage,
    this.loadedThumbnails = const {},
  });

  FlashbacksState copyWith({
    List<FlashbackSetData>? sets,
    bool? isLoading,
    String? errorMessage,
    Map<String, Uint8List>? loadedThumbnails,
  }) {
    return FlashbacksState(
      sets: sets ?? this.sets,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      loadedThumbnails: loadedThumbnails ?? this.loadedThumbnails,
    );
  }
}

class FlashbacksController extends StateNotifier<FlashbacksState> {
  final Ref _ref;
  static const int maxConcurrency = 4;

  FlashbacksController(this._ref) : super(const FlashbacksState());

  /// Loads flashbacks sets and preloads their thumbnails in parallel batches of [maxConcurrency].
  Future<void> loadFlashbacks() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final sets = await _ref.read(flashbacksProvider.future);
      state = state.copyWith(sets: sets, isLoading: false);

      // Collect all memory items across the flashback sets
      final allItems = sets.expand((s) => s.items).toList();
      await preloadThumbnails(allItems);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Parallelizes photo thumbnail loading with Future.wait() and max concurrency of 4,
  /// ensuring high performance without loading heavyweight full-res media.
  Future<Map<String, Uint8List>> preloadThumbnails(
    List<KiokuMemory> items, {
    int concurrency = maxConcurrency,
  }) async {
    final repo = _ref.read(memoryRepositoryProvider);
    final results = Map<String, Uint8List>.from(state.loadedThumbnails);

    // Filter items that need fetching and have a valid albumId
    final toFetch = items
        .where((m) => m.albumId != null && !results.containsKey(m.id))
        .toList();

    for (var i = 0; i < toFetch.length; i += concurrency) {
      final batch = toFetch.sublist(
        i,
        (i + concurrency).clamp(0, toFetch.length),
      );

      final batchResults = await Future.wait(
        batch.map((item) async {
          try {
            final bytes = await repo.getThumbnailBytes(
              item.id,
              albumId: item.albumId!,
            );
            return (id: item.id, bytes: bytes);
          } catch (_) {
            return (id: item.id, bytes: null);
          }
        }),
      );

      for (final res in batchResults) {
        if (res.bytes != null) {
          results[res.id] = res.bytes!;
        }
      }

      state = state.copyWith(loadedThumbnails: Map.unmodifiable(results));
    }

    return results;
  }
}

final flashbacksControllerProvider =
    StateNotifierProvider<FlashbacksController, FlashbacksState>((ref) {
  return FlashbacksController(ref);
});
