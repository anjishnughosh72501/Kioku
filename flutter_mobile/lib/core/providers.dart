/// App-level Riverpod providers for albums, memories, and flashbacks.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/features/auth/domain/i_auth_repository.dart';
import 'package:flutter_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter_mobile/features/feed/domain/i_memory_repository.dart';
import 'package:flutter_mobile/features/feed/domain/use_cases/get_memories_use_case.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/features/upload/domain/i_upload_repository.dart';

import 'package:flutter_mobile/core/crypto/key_store.dart';
import 'package:flutter_mobile/core/storage/storage_provider.dart';
import 'package:flutter_mobile/core/storage/local_storage_provider.dart';
import 'package:flutter_mobile/core/storage/drive_storage_provider.dart';
import 'package:flutter_mobile/core/storage/s3_storage_provider.dart';
import 'package:flutter_mobile/core/storage/webdav_storage_provider.dart';
import 'package:flutter_mobile/core/storage/mesh_storage_provider.dart';
import 'package:flutter_mobile/core/storage/storage_settings_service.dart';
import 'package:flutter_mobile/features/feed/data/encrypted_memory_repository.dart';

/// Core Clean Architecture Repository Providers
final authRepositoryProvider =
    Provider<IAuthRepository>((ref) => AuthRepository());

final keyStoreProvider = Provider<KeyStore>((ref) => KeyStore.instance);

final localStorageProvider =
    Provider<LocalStorageProvider>((ref) => const LocalStorageProvider());

final driveStorageProvider =
    Provider<DriveStorageProvider>((ref) => const DriveStorageProvider());

final storageSettingsServiceProvider =
    Provider<StorageSettingsService>((ref) => const StorageSettingsService());

final s3ConfigProvider = StateProvider<S3StorageConfig?>((ref) => null);
final webDavConfigProvider = StateProvider<WebDavConfig?>((ref) => null);

final meshStorageProvider =
    Provider<MeshStorageProvider>((ref) => MeshStorageProvider());

final activeStorageTypeProvider =
    StateProvider<StorageProviderType>((ref) => StorageProviderType.local);

final storageProviderProvider = Provider<StorageProvider>((ref) {
  final activeType = ref.watch(activeStorageTypeProvider);
  switch (activeType) {
    case StorageProviderType.drive:
      return ref.watch(driveStorageProvider);
    case StorageProviderType.s3:
      final cfg = ref.watch(s3ConfigProvider);
      if (cfg != null) {
        return S3StorageProvider(config: cfg);
      }
      return ref.watch(localStorageProvider);
    case StorageProviderType.webdav:
      final cfg = ref.watch(webDavConfigProvider);
      if (cfg != null) {
        return WebDavStorageProvider(config: cfg);
      }
      return ref.watch(localStorageProvider);
    case StorageProviderType.mesh:
      return ref.watch(meshStorageProvider);
    case StorageProviderType.local:
      if (AppDrive.instance.isBound) {
        return ref.watch(driveStorageProvider);
      }
      return ref.watch(localStorageProvider);
  }
});

final encryptedMemoryRepositoryProvider =
    Provider<EncryptedMemoryRepository>((ref) {
  final keyStore = ref.watch(keyStoreProvider);
  return EncryptedMemoryRepository(
    provider: () => ref.watch(storageProviderProvider),
    keyStore: keyStore,
  );
});

final memoryRepositoryProvider =
    Provider<IMemoryRepository>((ref) => ref.watch(encryptedMemoryRepositoryProvider));

final uploadRepositoryProvider =
    Provider<IUploadRepository>((ref) => ref.watch(encryptedMemoryRepositoryProvider));

final userProfileProvider =
    StateProvider<({String username, String friendCode})>((ref) {
  final svc = UserProfileService.instance;
  return (username: svc.username, friendCode: svc.friendCode);
});

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
      final currentList = state.valueOrNull ?? [];
      state = AsyncData([...currentList, album]);
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

final isPaginatingMemoriesProvider = StateProvider<bool>((ref) => false);

/// Memories of the active album.
class Memories extends AsyncNotifier<List<KiokuMemory>> {
  String? _nextPageToken;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<KiokuMemory>> build() async {
    final albumId = ref.watch(activeAlbumProvider);
    if (albumId == null) {
      _nextPageToken = null;
      _hasMore = false;
      return const [];
    }
    final page = await ref.watch(memoryRepositoryProvider).getMemoriesPage(albumId);
    _nextPageToken = page.nextPageToken;
    _hasMore = page.nextPageToken != null;
    return page.items;
  }

  Future<void> refresh() async {
    final albumId = ref.read(activeAlbumProvider);
    if (albumId == null) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(memoryRepositoryProvider).getMemoriesPage(albumId);
      _nextPageToken = page.nextPageToken;
      _hasMore = page.nextPageToken != null;
      return page.items;
    });
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    final albumId = ref.read(activeAlbumProvider);
    if (albumId == null) return;
    _isLoadingMore = true;
    ref.read(isPaginatingMemoriesProvider.notifier).state = true;
    try {
      final page = await ref.read(memoryRepositoryProvider).getMemoriesPage(
        albumId,
        pageToken: _nextPageToken,
      );
      _nextPageToken = page.nextPageToken;
      _hasMore = page.nextPageToken != null;
      if (state.hasValue) {
        state = AsyncData([...state.requireValue, ...page.items]);
      }
    } finally {
      _isLoadingMore = false;
      ref.read(isPaginatingMemoriesProvider.notifier).state = false;
    }
  }

  Future<void> delete(String fileId) async {
    await ref.read(memoryRepositoryProvider).deleteMemory(fileId);
    if (state.hasValue) {
      state = AsyncData(
        state.requireValue.where((m) => m.id != fileId).toList(),
      );
    }
  }
}

final memoriesProvider = AsyncNotifierProvider<Memories, List<KiokuMemory>>(
  Memories.new,
);

/// Derived provider: groups memories by day, memoized by Riverpod.
final groupedMemoriesProvider =
    Provider<List<({DateTime day, List<KiokuMemory> items})>>((ref) {
  final memories = ref.watch(memoriesProvider).value ?? const [];
  final map = <String, ({DateTime day, List<KiokuMemory> items})>{};
  for (final item in memories) {
    final d = item.takenAt;
    if (d == null) continue;
    final day = DateTime(d.year, d.month, d.day);
    final key = day.toIso8601String();
    final existing = map[key];
    if (existing == null) {
      map[key] = (day: day, items: [item]);
    } else {
      existing.items.add(item);
    }
  }
  return map.values.toList()..sort((a, b) => b.day.compareTo(a.day));
});

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