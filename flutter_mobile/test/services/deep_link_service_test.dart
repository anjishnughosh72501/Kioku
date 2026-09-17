import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/storage/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderWindows.registerWith();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ensureAlbum creates and stores album on disk', () async {
    final album = await LocalStorageService.instance.ensureAlbum(
      id: 'test_album_123',
      name: 'Summer Holiday',
      storageType: 'local',
    );

    expect(album.id, 'test_album_123');
    expect(album.name, 'Summer Holiday');

    final albums = await LocalStorageService.instance.getAlbums();
    expect(albums.any((a) => a.id == 'test_album_123'), isTrue);
  });

  test('addFriend with displayName stores friend and display name', () async {
    await UserProfileService.instance.init();
    final added = await UserProfileService.instance.addFriend(
      'KIOKU-FRIEND1',
      displayName: 'Alice',
    );

    expect(added, isTrue);
    final friends = await UserProfileService.instance.getConnectedFriends();
    expect(friends.contains('KIOKU-FRIEND1'), isTrue);

    final name = await UserProfileService.instance.getFriendName('KIOKU-FRIEND1');
    expect(name, 'Alice');
  });
}
