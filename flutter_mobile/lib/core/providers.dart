/// App-level Riverpod providers for albums, memories, and flashbacks.
library;

import 'dart:typed_data';
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
import 'package:flutter_mobile/core/utils/lru_cache.dart';
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

class StorageMisconfiguredProvider implements StorageProvider {
  final String providerName;
  const StorageMisconfiguredProvider(this.providerName);

  @override
  StorageProviderType get type => StorageProviderType.local;

  @override
  StorageCapabilities get capabilities => StorageCapabilities(
        displayName: '$providerName (Not Configured)',
      );

  @override
  Future<String> putBlob(Uint8List ciphertext, {required String containerId, required String objectId}) {
    throw StateError('$providerName storage is not configured. Please open Settings -> Storage Backend to configure your credentials.');
  }

  @override
  Future<Uint8List> getBlob(String objectId, {required String containerId}) {
    throw StateError('$providerName storage is not configured. Please open Settings -> Storage Backend to configure your credentials.');
  }

  @override
  Future<void> deleteBlob(String objectId, {required String containerId}) {
    throw StateError('$providerName storage is not configured.');
  }

  @override
  Future<List<String>> listBlobs(String containerId) async => [];
}

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
      return const StorageMisconfiguredProvider('S3 Cloud');
    case StorageProviderType.webdav:
      final cfg = ref.watch(webDavConfigProvider);
      if (cfg != null) {
        return WebDavStorageProvider(config: cfg);
      }
      return const StorageMisconfiguredProvider('WebDAV');
    case StorageProviderType.mesh:
      return ref.watch(meshStorageProvider);
    case StorageProviderType.local:
      if (AppDrive.instance.isBound) {
        return ref.watch(driveStorageProvider);
      }
      return ref.watch(localStorageProvider);
  }
});

final memoryMediaCacheProvider = Provider<ByteBudgetLruCache>((ref) {
  return ByteBudgetLruCache(maxBytes: 50 * 1024 * 1024);
});

final memoryThumbCacheProvider = Provider<ByteBudgetLruCache>((ref) {
  return ByteBudgetLruCache(maxBytes: 20 * 1024 * 1024);
});

final memoryMetadataCacheProvider = Provider<Map<String, KiokuMemory>>((ref) {
  return <String, KiokuMemory>{};
});

final encryptedMemoryRepositoryProvider =
    Provider<EncryptedMemoryRepository>((ref) {
  final keyStore = ref.watch(keyStoreProvider);
  return EncryptedMemoryRepository(
    provider: () => ref.watch(storageProviderProvider),
    keyStore: keyStore,
    mediaCache: ref.watch(memoryMediaCacheProvider),
    thumbCache: ref.watch(memoryThumbCacheProvider),
    metadataCache: ref.watch(memoryMetadataCacheProvider),
  );
});

final memoryRepositoryProvider =
    Provider<IMemoryRepository>((ref) => ref.watch(encryptedMemoryRepositoryProvider));

final uploadRepositoryProvider =
    Provider<IUploadRepository>((ref) => ref.watch(encryptedMemoryRepositoryProvider));

class UserProfileNotifier extends StateNotifier<({String username, String friendCode})> {
  UserProfileNotifier()
      : super((
          username: UserProfileService.instance.username,
          friendCode: UserProfileService.instance.friendCode,
        )) {
    _listener = (profile) {
      if (mounted) {
        state = (username: profile.username, friendCode: profile.friendCode);
      }
    };
    UserProfileService.instance.addListener(_listener);
  }

  late final void Function(UserProfile) _listener;

  @override
  void dispose() {
    UserProfileService.instance.removeListener(_listener);
    super.dispose();
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, ({String username, String friendCode})>((ref) {
  return UserProfileNotifier();
});

class ConnectedFriendsNotifier extends StateNotifier<List<String>> {
  ConnectedFriendsNotifier() : super([]) {
    _load();
    _listener = () => _load();
    UserProfileService.instance.addFriendListener(_listener);
  }

  late final void Function() _listener;

  Future<void> _load() async {
    final friends = await UserProfileService.instance.getConnectedFriends();
    if (mounted) {
      state = friends;
    }
  }

  Future<bool> addFriend(String friendCode) async {
    final success = await UserProfileService.instance.addFriend(friendCode);
    if (success) {
      await _load();
    }
    return success;
  }

  Future<bool> removeFriend(String friendCode) async {
    final success = await UserProfileService.instance.removeFriend(friendCode);
    if (success) {
      await _load();
    }
    return success;
  }

  @override
  void dispose() {
    UserProfileService.instance.removeFriendListener(_listener);
    super.dispose();
  }
}

final connectedFriendsProvider =
    StateNotifierProvider<ConnectedFriendsNotifier, List<String>>((ref) {
  return ConnectedFriendsNotifier();
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
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted && state == null) {
        state = prefs.getString(_key);
      }
    } catch (_) {}
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
    final prefs = await SharedPreferences.getInstance();
    return albums.map((a) {
      final thumb = prefs.getString('album_thumb_${a.id}');
      final storage = prefs.getString('album_storage_${a.id}') ?? 'local';
      return a.copyWith(thumbnailPath: thumb, storageType: storage);
    }).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final albums = await ref.read(memoryRepositoryProvider).getAlbums();
      final prefs = await SharedPreferences.getInstance();
      return albums.map((a) {
        final thumb = prefs.getString('album_thumb_${a.id}');
        final storage = prefs.getString('album_storage_${a.id}') ?? 'local';
        return a.copyWith(thumbnailPath: thumb, storageType: storage);
      }).toList();
    });
  }

  Future<Album> addAlbum(String name, {String? storageType}) async {
    try {
      final album = await ref.read(memoryRepositoryProvider).createAlbum(name);
      final resolvedStorage = storageType ?? ref.read(activeStorageTypeProvider).name;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('album_storage_${album.id}', resolvedStorage);
      final enriched = album.copyWith(storageType: resolvedStorage);
      final currentList = state.valueOrNull ?? [];
      state = AsyncData([...currentList, enriched]);
      await ref.read(activeAlbumProvider.notifier).set(album.id);
      await refresh();
      return enriched;
    } on Exception catch (e) {
      throw AlbumException('Could not create album: $e');
    }
  }

  Future<void> setAlbumThumbnail(String albumId, String thumbnailPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('album_thumb_$albumId', thumbnailPath);
    if (state.hasValue) {
      state = AsyncData(
        state.requireValue.map((a) => a.id == albumId ? a.copyWith(thumbnailPath: thumbnailPath) : a).toList(),
      );
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

/// Provider for memories of a specific album
final albumMemoriesProvider = FutureProvider.family<List<KiokuMemory>, String>((ref, albumId) async {
  return await ref.watch(memoryRepositoryProvider).getMemories(albumId);
});

final isPaginatingMemoriesProvider = StateProvider<bool>((ref) => false);

/// Memories of the feed (shows all updates or active album).
class Memories extends AsyncNotifier<List<KiokuMemory>> {
  String? _nextPageToken;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<KiokuMemory>> build() async {
    final albumId = ref.watch(activeAlbumProvider);
    final albums = await ref.watch(albumsProvider.future);
    if (albums.isEmpty) {
      _nextPageToken = null;
      _hasMore = false;
      return const [];
    }

    if (albumId != null && albumId != 'all' && albums.any((a) => a.id == albumId)) {
      final page = await ref.watch(memoryRepositoryProvider).getMemoriesPage(albumId);
      _nextPageToken = page.nextPageToken;
      _hasMore = page.nextPageToken != null;
      return page.items;
    }

    // Feed shows all updates across all albums
    final repo = ref.read(memoryRepositoryProvider);
    final results = await Future.wait(
      albums.map((album) async {
        try {
          return await repo.getMemories(album.id);
        } catch (_) {
          return <KiokuMemory>[];
        }
      }),
    );
    final all = results.expand((m) => m).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    _nextPageToken = null;
    _hasMore = false;
    return all;
  }

  Future<void> refresh() async {
    final albumId = ref.read(activeAlbumProvider);
    final albums = await ref.read(albumsProvider.future);
    if (albums.isEmpty) {
      state = const AsyncData([]);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (albumId != null && albumId != 'all' && albums.any((a) => a.id == albumId)) {
        final page = await ref.read(memoryRepositoryProvider).getMemoriesPage(albumId);
        _nextPageToken = page.nextPageToken;
        _hasMore = page.nextPageToken != null;
        return page.items;
      }

      final repo = ref.read(memoryRepositoryProvider);
      final results = await Future.wait(
        albums.map((album) async {
          try {
            return await repo.getMemories(album.id);
          } catch (_) {
            return <KiokuMemory>[];
          }
        }),
      );
      final all = results.expand((m) => m).toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      _nextPageToken = null;
      _hasMore = false;
      return all;
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
    final albumId = ref.read(activeAlbumProvider);
    await ref.read(memoryRepositoryProvider).deleteMemory(fileId, albumId: albumId);
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
      map[key] = (day: day, items: [...existing.items, item]);
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
  final repo = ref.read(memoryRepositoryProvider);
  final results = await Future.wait(
    albums.map((album) async {
      try {
        return await repo.getMemories(album.id);
      } catch (_) {
        return <KiokuMemory>[];
      }
    }),
  );
  final memories = results.expand((m) => m).toList();
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