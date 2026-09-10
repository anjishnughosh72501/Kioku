import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/features/feed/domain/i_memory_repository.dart';
import 'package:flutter_mobile/features/feed/presentation/screens/feed_screen.dart';

class MockMemoryRepo implements IMemoryRepository {
  MockMemoryRepo({this.memories = const [], this.albums = const []});

  final List<KiokuMemory> memories;
  final List<Album> albums;

  @override
  Future<List<Album>> getAlbums() async => albums;

  @override
  Future<Album> createAlbum(String name) async => Album(id: 'new_id', name: name);

  @override
  Future<void> shareAlbum(String albumId, String email, {String role = 'writer'}) async {}

  @override
  Future<List<AlbumMember>> getAlbumMembers(String albumId) async => [];

  @override
  Future<List<KiokuMemory>> getMemories(String albumId) async => memories;

  @override
  Future<({List<KiokuMemory> items, String? nextPageToken})> getMemoriesPage(
    String albumId, {
    int pageSize = 30,
    String? pageToken,
  }) async => (items: memories, nextPageToken: null);

  @override
  Future<void> deleteMemory(String fileId) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'active_album_id': 'album_1'});
  });

  group('FeedScreen', () {
    testWidgets('renders empty state when album has no memories', (tester) async {
      final repo = MockMemoryRepo(
        albums: [const Album(id: 'album_1', name: 'Summer')],
        memories: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            memoryRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.coffeeLight(),
            home: const FeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No memories yet'), findsOneWidget);
      expect(find.text('Create your first album'), findsOneWidget);
    });

    testWidgets('renders memory cards when memories exist', (tester) async {
      final repo = MockMemoryRepo(
        albums: [const Album(id: 'album_1', name: 'Summer')],
        memories: [
          KiokuMemory(
            id: 'mem_1',
            fileName: 'pic.jpg',
            mimeType: 'image/jpeg',
            caption: 'Morning matcha latte',
            takenAtIso: DateTime(2026, 6, 15, 9, 30).toIso8601String(),
            addedAt: DateTime(2026, 6, 15),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            memoryRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.coffeeLight(),
            home: const FeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Morning matcha latte'), findsOneWidget);
    });
  });
}
