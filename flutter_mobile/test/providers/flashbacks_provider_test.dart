import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/features/feed/domain/i_memory_repository.dart';

class FakeAlbums extends Albums {
  @override
  Future<List<Album>> build() async => [
        const Album(id: 'album-1', name: 'Summer 2025'),
      ];
}

class FakeMemoryRepository implements IMemoryRepository {
  FakeMemoryRepository(this.memories);

  final List<KiokuMemory> memories;

  @override
  Future<List<Album>> getAlbums() async => [
        const Album(id: 'album-1', name: 'Summer 2025'),
      ];

  @override
  Future<List<KiokuMemory>> getMemories(String albumId) async => memories;

  @override
  Future<Album> createAlbum(String name) async => Album(id: 'new', name: name);

  @override
  Future<void> shareAlbum(String albumId, String email, {String role = 'writer'}) async {}

  @override
  Future<List<AlbumMember>> getAlbumMembers(String albumId) async => [];

  @override
  Future<void> deleteMemory(String fileId) async {}
}

void main() {
  group('flashbacksProvider', () {
    test('returns 3 flashback sets (yearly, monthly, weekly)', () async {
      final container = ProviderContainer(
        overrides: [
          albumsProvider.overrideWith(FakeAlbums.new),
          memoryRepositoryProvider
              .overrideWithValue(FakeMemoryRepository(<KiokuMemory>[])),
        ],
      );
      addTearDown(container.dispose);

      final flashbacks = await container.read(flashbacksProvider.future);
      expect(flashbacks.length, 3);
      expect(flashbacks.every((f) => f.items.isEmpty), isTrue);
    });

    test('correctly buckets weekly memories from the past 7 days', () async {
      final now = DateTime.now();
      final fakeMemories = <KiokuMemory>[
        KiokuMemory(
          id: '1',
          fileName: 'photo1.jpg',
          mimeType: 'image/jpeg',
          takenAtIso: now.subtract(const Duration(days: 2)).toIso8601String(),
          addedAt: now,
          uploaderName: 'Alice',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          albumsProvider.overrideWith(FakeAlbums.new),
          memoryRepositoryProvider
              .overrideWithValue(FakeMemoryRepository(fakeMemories)),
        ],
      );
      addTearDown(container.dispose);

      final flashbacks = await container.read(flashbacksProvider.future);
      final weekly = flashbacks.where((f) => f.period == 'weekly').firstOrNull;
      expect(weekly, isNotNull);
      expect(weekly!.items.length, 1);
      expect(weekly.items.first.id, '1');
    });
  });
}
