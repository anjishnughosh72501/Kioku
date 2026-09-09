/// App-level Riverpod providers for albums, memories, and flashbacks.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/features/auth/domain/i_auth_repository.dart';
import 'package:flutter_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter_mobile/features/feed/domain/i_memory_repository.dart';
import 'package:flutter_mobile/features/feed/data/memory_repository.dart';
import 'package:flutter_mobile/features/feed/domain/use_cases/get_memories_use_case.dart';
import 'package:flutter_mobile/features/upload/domain/i_upload_repository.dart';
import 'package:flutter_mobile/features/upload/data/upload_repository.dart';

/// Core Clean Architecture Repository Providers
final authRepositoryProvider =
    Provider<IAuthRepository>((ref) => AuthRepository());

final memoryRepositoryProvider =
    Provider<IMemoryRepository>((ref) => const MemoryRepository());

final uploadRepositoryProvider =
    Provider<IUploadRepository>((ref) => const UploadRepository());

final getMemoriesUseCaseProvider = Provider<GetMemoriesUseCase>(
  (ref) => GetMemoriesUseCase(ref.watch(memoryRepositoryProvider)),
);

/// Current bearer token, used for authorized video streaming (alt=media).
final driveAuthTokenProvider = FutureProvider<String>((ref) async {
  return AppDrive.instance.accessToken();
});

/// Id of the album currently shown in the feed / upload target.
class ActiveAlbum extends StateNotifier<String?> {
  ActiveAlbum() : super(null) {
    _load();
  }

  static const _key = 'active_album_id';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      state = prefs.getString(_key);
    }
  }

  Future<void> set(String? id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, id);
    }
  }
}

final activeAlbumProvider =
    StateNotifierProvider<ActiveAlbum, String?>((ref) => ActiveAlbum());

class AlbumException implements Exception {
  final String message;
  const AlbumException(this.message);
  @override
  String toString() => message;
}

/// All albums visible to the signed-in user (folders they own or that were
/// shared with them).
class Albums extends AsyncNotifier<List<Album>> {
  @override
  Future<List<Album>> build() async {
    final albums = await ref.watch(memoryRepositoryProvider).getAlbums();
    // Auto-select first album if activeAlbumProvider is null, scheduled after build
    if (albums.isNotEmpty && ref.read(activeAlbumProvider) == null) {
      Future.microtask(() {
        if (ref.read(activeAlbumProvider) == null) {
          ref.read(activeAlbumProvider.notifier).set(albums.first.id);
        }
      });
    }
    return albums;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(memoryRepositoryProvider).getAlbums(),
    );
  }

  Future<Album> addAlbum(String name) async {
    try {
      final album = await ref.read(memoryRepositoryProvider).createAlbum(name);
      await ref.read(activeAlbumProvider.notifier).set(album.id);
      await refresh();
      return album;
    } on Exception catch (e) {
      throw AlbumException('Could not create album: $e');
    }
  }

  Future<void> share(String albumId, String email) async {
    try {
      await ref.read(memoryRepositoryProvider).shareAlbum(albumId, email);
    } on Exception catch (e) {
      throw AlbumException('Could not share album: $e');
    }
  }
}

final albumsProvider = AsyncNotifierProvider<Albums, List<Album>>(
  Albums.new,
);

/// Memories of the active album.
class Memories extends AsyncNotifier<List<KiokuMemory>> {
  @override
  Future<List<KiokuMemory>> build() async {
    final albumId = ref.watch(activeAlbumProvider);
    if (albumId == null) return const [];
    return ref.watch(getMemoriesUseCaseProvider)(albumId);
  }

  Future<void> refresh() async {
    final albumId = ref.read(activeAlbumProvider);
    if (albumId == null) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(getMemoriesUseCaseProvider)(albumId),
    );
  }
}

final memoriesProvider = AsyncNotifierProvider<Memories, List<KiokuMemory>>(
  Memories.new,
);

/// One flashback set, computed locally from memories across albums.
class FlashbackSetData {
  const FlashbackSetData({
    required this.period,
    required this.periodTitle,
    required this.subtitle,
    required this.items,
  });

  final String period;
  final String periodTitle;
  final String subtitle;
  final List<KiokuMemory> items;
}

/// Today's flashbacks: yearly (same day-month in a past year), monthly
/// (previous calendar month), weekly (past 7 days).
final flashbacksProvider = FutureProvider<List<FlashbackSetData>>((ref) async {
  final albums = await ref.watch(albumsProvider.future);
  final memories = <KiokuMemory>[];
  for (final album in albums) {
    try {
      memories.addAll(
        await ref.read(memoryRepositoryProvider).getMemories(album.id),
      );
    } catch (_) {
      // Skip albums we can no longer read.
    }
  }
  return _computeFlashbacks(memories);
});

List<FlashbackSetData> _computeFlashbacks(List<KiokuMemory> all) {
  final now = DateTime.now();
  final nowMonthDay = (now.month, now.day);

  final yearlyCandidates = all
      .where((m) {
        final t = m.takenAt;
        if (t == null) return false;
        return t.month == now.month &&
            t.day == now.day &&
            t.year < now.year;
      })
      .toList()
    ..sort((a, b) => (b.takenAt ?? DateTime(0)).compareTo(a.takenAt ?? DateTime(0)));

  // Fall back to any past year with the same month-day if not exactly one year
  // ago, so the section rarely sits empty.
  final finalYearly = yearlyCandidates.isNotEmpty
      ? yearlyCandidates
      : all
            .where((m) {
              final t = m.takenAt;
              if (t == null) return false;
              return (t.month, t.day) == nowMonthDay && t.year < now.year;
            })
            .toList();
  _sortDesc(finalYearly);

  final prevMonth = now.month == 1 ? 12 : now.month - 1;
  final prevYear = now.month == 1 ? now.year - 1 : now.year;
  final finalMonthly = all
      .where((m) {
        final t = m.takenAt;
        if (t == null) return false;
        return t.month == prevMonth && t.year == prevYear;
      })
      .toList();
  _sortDesc(finalMonthly);

  final finalWeekly = all
      .where((m) {
        final t = m.takenAt;
        if (t == null) return false;
        return now.difference(t).inDays <= 7;
      })
      .toList();
  _sortDesc(finalWeekly);

  return [
    FlashbackSetData(
      period: 'yearly',
      periodTitle: '1 Year Ago Today',
      subtitle: "From last year's album",
      items: finalYearly,
    ),
    FlashbackSetData(
      period: 'monthly',
      periodTitle: "Last Month's Album",
      subtitle: 'From last month',
      items: finalMonthly,
    ),
    FlashbackSetData(
      period: 'weekly',
      periodTitle: 'A Passing Memory',
      subtitle: 'From this week',
      items: finalWeekly,
    ),
  ];
}

void _sortDesc(List<KiokuMemory> list) =>
    list.sort((a, b) => (b.takenAt ?? DateTime(0)).compareTo(a.takenAt ?? DateTime(0)));