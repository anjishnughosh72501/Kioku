import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/features/feed/domain/i_memory_repository.dart';
import 'package:flutter_mobile/features/flashbacks/presentation/controllers/flashbacks_controller.dart';

class MockMemoryRepository extends Mock implements IMemoryRepository {
  @override
  Future<Uint8List?> getThumbnailBytes(String? memoryId, {required String? albumId}) =>
      super.noSuchMethod(
        Invocation.method(#getThumbnailBytes, [memoryId], {#albumId: albumId}),
        returnValue: Future.value(Uint8List.fromList([1, 2, 3])),
        returnValueForMissingStub: Future.value(Uint8List.fromList([1, 2, 3])),
      );
}

void main() {
  group('FlashbacksController', () {
    test('maxConcurrency is 4', () {
      expect(FlashbacksController.maxConcurrency, 4);
    });

    test('preloadThumbnails fetches thumbnails with parallel batches', () async {
      final mockRepo = MockMemoryRepository();
      when(mockRepo.getThumbnailBytes(any, albumId: anyNamed('albumId')))
          .thenAnswer((_) async => Uint8List.fromList([0xCA, 0xFE]));

      final container = ProviderContainer(
        overrides: [
          memoryRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(flashbacksControllerProvider.notifier);

      final memories = List<KiokuMemory>.generate(
        10,
        (i) => KiokuMemory(
          id: 'mem_$i',
          fileName: 'photo_$i.jpg',
          mimeType: 'image/jpeg',
          takenAtIso: DateTime.now().toIso8601String(),
          albumId: 'album_test',
          addedAt: DateTime.now(),
        ),
      );

      final loaded = await controller.preloadThumbnails(memories, concurrency: 4);

      expect(loaded.length, 10);
      for (var i = 0; i < 10; i++) {
        expect(loaded['mem_$i'], isNotNull);
      }
      verify(mockRepo.getThumbnailBytes(any, albumId: 'album_test')).called(10);
    });
  });
}
