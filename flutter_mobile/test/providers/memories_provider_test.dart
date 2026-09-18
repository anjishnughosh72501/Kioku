import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/features/feed/domain/i_memory_repository.dart';

class MockMemoryRepository implements IMemoryRepository {
  MockMemoryRepository({required this.memories});

  final List<KiokuMemory> memories;
  final List<String> deletedIds = [];

  @override
  Future<List<Album>> getAlbums() async => [const Album(id: 'album_1', name: 'Trip')];

  @override
  Future<Album> createAlbum(String name) async => Album(id: 'new_id', name: name);

  @override
  Future<void> shareAlbum(String albumId, String email, {String role = 'writer'}) async {}

  @override
  Future<List<AlbumMember>> getAlbumMembers(String albumId) async => [];

  @override
  Future<List<KiokuMemory>> getMemories(String albumId) async => List.from(memories);

  @override
  Future<({List<KiokuMemory> items, String? nextPageToken})> getMemoriesPage(
    String albumId, {
    int pageSize = 30,
    String? pageToken,
  }) async => (items: List<KiokuMemory>.from(memories), nextPageToken: null);

  @override
  Future<void> deleteMemory(String fileId, {String? albumId}) async {
    deletedIds.add(fileId);
    memories.removeWhere((m) => m.id == fileId);
  }

  @override
  Future<Uint8List?> getThumbnailBytes(String memoryId, {required String albumId}) async => null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'active_album_id': 'album_1'});
  });

  group('Memories notifier', () {
    test('delete calls repository and removes memory from state', () async {
      final item1 = KiokuMemory(
        id: 'mem_1',
        fileName: '1.jpg',
        mimeType: 'image/jpeg',
        takenAtIso: DateTime(2026, 1, 1).toIso8601String(),
        addedAt: DateTime(2026, 1, 1),
      );
      final item2 = KiokuMemory(
        id: 'mem_2',
        fileName: '2.jpg',
        mimeType: 'image/jpeg',
        takenAtIso: DateTime(2026, 1, 2).toIso8601String(),
        addedAt: DateTime(2026, 1, 2),
      );

      final mockRepo = MockMemoryRepository(memories: [item1, item2]);

      final container = ProviderContainer(
        overrides: [
          memoryRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      // Set active album
      container.read(activeAlbumProvider.notifier).set('album_1');

      // Trigger initial load
      final initial = await container.read(memoriesProvider.future);
      expect(initial.length, 2);

      // Perform delete
      await container.read(memoriesProvider.notifier).delete('mem_1');

      // Verify repository received delete
      expect(mockRepo.deletedIds, contains('mem_1'));

      // Verify state was updated
      final updated = container.read(memoriesProvider).value;
      expect(updated?.length, 1);
      expect(updated?.first.id, 'mem_2');
    });

    test('userProfileProvider emits default identity', () {
      final container = ProviderContainer();
      final profile = container.read(userProfileProvider);
      expect(profile.username.isNotEmpty, isTrue);
      expect(profile.friendCode.isNotEmpty, isTrue);
    });
  });
}
