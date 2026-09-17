import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/features/feed/domain/i_memory_repository.dart';

class MockMemoryRepository implements IMemoryRepository {
  MockMemoryRepository({this.failCreation = false, this.failSharing = false});

  final bool failCreation;
  final bool failSharing;
  final List<Album> albums = [const Album(id: '1', name: 'Summer')];

  @override
  Future<List<Album>> getAlbums() async => albums;

  @override
  Future<Album> createAlbum(String name) async {
    if (failCreation) throw Exception('Drive write error');
    final album = Album(id: '2', name: name);
    albums.add(album);
    return album;
  }

  @override
  Future<void> shareAlbum(String albumId, String email, {String role = 'writer'}) async {
    if (failSharing) throw Exception('Drive permission error');
  }

  @override
  Future<List<AlbumMember>> getAlbumMembers(String albumId) async => [];

  @override
  Future<List<KiokuMemory>> getMemories(String albumId) async => [];

  @override
  Future<({List<KiokuMemory> items, String? nextPageToken})> getMemoriesPage(
    String albumId, {
    int pageSize = 30,
    String? pageToken,
  }) async => (items: <KiokuMemory>[], nextPageToken: null);

  @override
  Future<void> deleteMemory(String fileId, {String? albumId}) async {}
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Albums notifier', () {
    test('addAlbum throws AlbumException on repository failure', () async {
      final mockRepo = MockMemoryRepository(failCreation: true);
      final container = ProviderContainer(
        overrides: [
          memoryRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(albumsProvider.notifier).addAlbum('Failing Album'),
        throwsA(isA<AlbumException>()),
      );
    });

    test('share throws AlbumException on repository failure', () async {
      final mockRepo = MockMemoryRepository(failSharing: true);
      final container = ProviderContainer(
        overrides: [
          memoryRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(albumsProvider.notifier).share('1', 'bad@example.com'),
        throwsA(isA<AlbumException>()),
      );
    });

    test('addAlbum creates album and updates activeAlbumProvider and albums list', () async {
      final mockRepo = MockMemoryRepository();
      final container = ProviderContainer(
        overrides: [
          memoryRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final album = await container.read(albumsProvider.notifier).addAlbum('Tokyo 2026');
      expect(album.name, 'Tokyo 2026');
      expect(container.read(activeAlbumProvider), '2');
      final currentAlbums = container.read(albumsProvider).value;
      expect(currentAlbums?.any((a) => a.id == '2' && a.name == 'Tokyo 2026'), isTrue);
    });

    test('setAlbumThumbnail updates album thumbnail and persists in state', () async {
      final mockRepo = MockMemoryRepository();
      final container = ProviderContainer(
        overrides: [
          memoryRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      // Load albums first
      await container.read(albumsProvider.future);

      // Update thumbnail
      await container.read(albumsProvider.notifier).setAlbumThumbnail('1', 'some/test/path.jpg');
      final updated = container.read(albumsProvider).value;
      final album1 = updated?.firstWhere((a) => a.id == '1');
      expect(album1?.thumbnailPath, 'some/test/path.jpg');
    });
  });
}
