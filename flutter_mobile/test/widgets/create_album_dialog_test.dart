import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/features/feed/domain/i_memory_repository.dart';
import 'package:flutter_mobile/shared/widgets/create_album_dialog.dart';

class MockMemoryRepo implements IMemoryRepository {
  final List<Album> createdAlbums = [];

  @override
  Future<List<Album>> getAlbums() async => createdAlbums;

  @override
  Future<Album> createAlbum(String name) async {
    final album = Album(id: 'album_${createdAlbums.length + 1}', name: name);
    createdAlbums.add(album);
    return album;
  }

  @override
  Future<void> shareAlbum(String albumId, String email, {String role = 'writer'}) async {}

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

  @override
  Future<Uint8List?> getThumbnailBytes(String memoryId, {required String albumId}) async => null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget(Widget child, MockMemoryRepo repo) {
    return ProviderScope(
      overrides: [
        memoryRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.coffeeLight(),
        home: Scaffold(body: child),
      ),
    );
  }

  group('CreateAlbumDialog', () {
    testWidgets('shows validation error when submitting empty name', (tester) async {
      final repo = MockMemoryRepo();
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CreateAlbumDialog.show(context),
              child: const Text('Open Dialog'),
            ),
          ),
          repo,
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Name your album'), findsOneWidget);

      // Tap Create without entering text
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter an album name'), findsOneWidget);
      expect(repo.createdAlbums.isEmpty, isTrue);
    });

    testWidgets('creates album and closes dialog on valid input', (tester) async {
      final repo = MockMemoryRepo();
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CreateAlbumDialog.show(context),
              child: const Text('Open Dialog'),
            ),
          ),
          repo,
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Kyoto Trip 2026');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(repo.createdAlbums.length, 1);
      expect(repo.createdAlbums.first.name, 'Kyoto Trip 2026');
      expect(find.byType(CreateAlbumDialog), findsNothing);
    });
  });
}
