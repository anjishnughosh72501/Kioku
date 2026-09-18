import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderWindows.registerWith();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserProfileService.instance.httpClient = MockClient((request) async {
      final path = request.url.path;
      if (path == '/friends/request') {
        return http.Response(
          jsonEncode({'id': 'req_123', 'status': 'pending', 'alreadySent': false}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.startsWith('/friends/requests/')) {
        return http.Response(
          jsonEncode({
            'requests': [],
            'accepted': [
              {
                'id': 'req_accepted_1',
                'toCode': 'KIOKU-ACCEPTED-FRIEND',
                'fromName': 'Alice',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path == '/friends/ack' ||
          path == '/friends/accept' ||
          path == '/friends/decline' ||
          path == '/friends/albums/accept' ||
          path == '/friends/albums/decline') {
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path == '/friends/albums/invite') {
        return http.Response(
          jsonEncode({'id': 'alb_inv_123', 'status': 'pending'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.startsWith('/friends/albums/invites/')) {
        return http.Response(
          jsonEncode({
            'invites': [
              {
                'id': 'alb_inv_99',
                'albumId': 'local_test_shared',
                'albumName': 'Kyoto 2026',
                'fromCode': 'KIOKU-KYOTO-HOST',
                'toCode': 'KIOKU-SELF',
                'fromName': 'Host',
                'claimToken': 'claim_token_123',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not Found', 404);
    });
  });

  group('Friend Request System & UserProfileService', () {
    test('FriendRequest json serialization and deserialization roundtrips', () {
      const original = FriendRequest(
        id: 'req_123',
        fromCode: 'KIOKU-AAAA',
        toCode: 'KIOKU-BBBB',
        fromName: 'Alice',
        createdAt: 1700000000,
      );

      final json = original.toJson();
      final restored = FriendRequest.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.fromCode, original.fromCode);
      expect(restored.toCode, original.toCode);
      expect(restored.fromName, original.fromName);
      expect(restored.createdAt, original.createdAt);
    });

    test('AlbumInvite json serialization and deserialization roundtrips', () {
      const original = AlbumInvite(
        id: 'invite_123',
        albumId: 'album_456',
        albumName: 'Tokyo Vacation',
        fromCode: 'KIOKU-HOST',
        toCode: 'KIOKU-GUEST',
        fromName: 'HostUser',
        claimToken: 'claim_abc',
        inviterPubKey: 'pubkey_xyz',
        createdAt: 1700000000,
      );

      final json = original.toJson();
      final restored = AlbumInvite.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.albumId, original.albumId);
      expect(restored.albumName, original.albumName);
      expect(restored.fromCode, original.fromCode);
      expect(restored.toCode, original.toCode);
      expect(restored.fromName, original.fromName);
      expect(restored.claimToken, original.claimToken);
      expect(restored.inviterPubKey, original.inviterPubKey);
    });

    test('sendFriendRequest prevents sending to oneself', () async {
      await UserProfileService.instance.init();
      final myCode = UserProfileService.instance.friendCode;

      final res = await UserProfileService.instance.sendFriendRequest(myCode);
      expect(res, FriendRequestResult.sameUser);
    });

    test('sendFriendRequest marks code as pending in local state', () async {
      await UserProfileService.instance.init();
      const targetCode = 'KIOKU-TARGET';

      final res = await UserProfileService.instance.sendFriendRequest(targetCode);
      expect(res, FriendRequestResult.sent);

      final pending = await UserProfileService.instance.getPendingSentRequests();
      expect(pending.contains(targetCode), isTrue);

      // Sending again to same target returns alreadySent
      final dupRes = await UserProfileService.instance.sendFriendRequest(targetCode);
      expect(dupRes, FriendRequestResult.alreadySent);
    });

    test('pollIncomingRequests processes accepted requests bidirectionally', () async {
      await UserProfileService.instance.init();

      // Seed pending sent request for KIOKU-ACCEPTED-FRIEND
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('kioku_pending_sent_requests', ['KIOKU-ACCEPTED-FRIEND']);

      // Poll
      await UserProfileService.instance.pollIncomingRequests();

      // Verify KIOKU-ACCEPTED-FRIEND has been auto-added to connected friends
      final friends = await UserProfileService.instance.getConnectedFriends();
      expect(friends.contains('KIOKU-ACCEPTED-FRIEND'), isTrue);

      // Verify pending sent was cleared
      final pending = await UserProfileService.instance.getPendingSentRequests();
      expect(pending.contains('KIOKU-ACCEPTED-FRIEND'), isFalse);
    });

    test('acceptRequest adds friend and cleans up pending/incoming state', () async {
      await UserProfileService.instance.init();

      // Seed a pending sent request and an incoming request
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('kioku_pending_sent_requests', ['KIOKU-FRIEND']);

      const incoming = FriendRequest(
        id: 'req_xyz',
        fromCode: 'KIOKU-FRIEND',
        toCode: 'KIOKU-SELF',
        fromName: 'Bob',
      );

      final accepted = await UserProfileService.instance.acceptRequest(incoming);
      expect(accepted, isTrue);

      final friends = await UserProfileService.instance.getConnectedFriends();
      expect(friends.contains('KIOKU-FRIEND'), isTrue);

      final friendName = await UserProfileService.instance.getFriendName('KIOKU-FRIEND');
      expect(friendName, 'Bob');

      // Pending sent should be cleared
      final pending = await UserProfileService.instance.getPendingSentRequests();
      expect(pending.contains('KIOKU-FRIEND'), isFalse);
    });

    test('declineRequest removes request from cached incoming requests', () async {
      await UserProfileService.instance.init();

      const incoming = FriendRequest(
        id: 'req_decline_me',
        fromCode: 'KIOKU-STRANGER',
        toCode: 'KIOKU-SELF',
        fromName: 'Stranger',
      );

      final declined = await UserProfileService.instance.declineRequest(incoming);
      expect(declined, isTrue);

      final friends = await UserProfileService.instance.getConnectedFriends();
      expect(friends.contains('KIOKU-STRANGER'), isFalse);
    });

    test('sendAlbumInvite and pollIncomingAlbumInvites work properly', () async {
      await UserProfileService.instance.init();

      final sent = await UserProfileService.instance.sendAlbumInvite(
        albumId: 'test_album_1',
        albumName: 'Test Album',
        toFriendCode: 'KIOKU-FRIEND-X',
      );
      expect(sent, isTrue);

      final invites = await UserProfileService.instance.pollIncomingAlbumInvites();
      expect(invites.isNotEmpty, isTrue);
      expect(invites.first.albumName, 'Kyoto 2026');

      final accepted = await UserProfileService.instance.acceptAlbumInvite(invites.first);
      expect(accepted, isTrue);
    });
  });
}
