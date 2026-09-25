import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/core/crypto/key_store.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';
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
  Future<void> deleteMemory(String fileId, {String? albumId}) async {}

  @override
  Future<Uint8List?> getThumbnailBytes(String memoryId, {required String albumId}) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderWindows.registerWith();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'active_album_id': 'album_1',
      'kioku_username': 'Alice',
      'kioku_username_prompted': true,
    });
    UserProfileService.instance.secureStorage = InMemorySecureStorage();
    UserProfileService.instance.httpClient = MockClient((request) async {
      return http.Response(
        jsonEncode({'ok': true, 'token': 'mock_token', 'albums': [], 'requests': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
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
      expect(find.text('Add a memory'), findsOneWidget);
    });

    testWidgets('renders empty state when no albums exist', (tester) async {
      final repo = MockMemoryRepo(
        albums: [],
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
