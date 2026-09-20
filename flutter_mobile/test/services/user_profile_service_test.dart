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
      if (path == '/friends/token') {
        return http.Response(
          jsonEncode({'token': 'mock_test_token_123', 'friendCode': 'KIOKU-TEST'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
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
      if (path == '/albums') {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'ok': true, 'album': {'id': 'alb_mock_1', 'title': 'Mock Album'}}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'albums': [
              {
                'id': 'alb_remote_1',
                'title': 'Remote Kyoto',
                'name': 'Remote Kyoto',
                'ownerUserId': 'KIOKU-HOST',
                'role': 'member',
                'storageType': 'local',
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

    test('fetchServerAlbums and registerAlbumOnServer interact with canonical backend', () async {
      await UserProfileService.instance.init();

      final registered = await UserProfileService.instance.registerAlbumOnServer(
        albumId: 'alb_new_local',
        title: 'New Album',
      );
      expect(registered, isTrue);

      final serverAlbums = await UserProfileService.instance.fetchServerAlbums();
      expect(serverAlbums.isNotEmpty, isTrue);
      expect(serverAlbums.first['id'], 'alb_remote_1');
      expect(serverAlbums.first['title'], 'Remote Kyoto');
    });

    test('sendFriendRequest returns error and never adds to pending on server failure', () async {
      await UserProfileService.instance.init();

      // Temporarily swap client to simulate server error
      final originalClient = UserProfileService.instance.httpClient;
      UserProfileService.instance.httpClient = MockClient((_) async => http.Response('Server Error', 500));

      final result = await UserProfileService.instance.sendFriendRequest('KIOKU-TARGET-FAIL');
      expect(result, FriendRequestResult.error);

      // Verify no optimistic mutation occurred in local state
      final pending = await UserProfileService.instance.getPendingSentRequests();
      expect(pending.contains('KIOKU-TARGET-FAIL'), isFalse);

      UserProfileService.instance.httpClient = originalClient;
    });

    test('acceptRequest returns false and does not add friend on server failure', () async {
      await UserProfileService.instance.init();

      final originalClient = UserProfileService.instance.httpClient;
      UserProfileService.instance.httpClient = MockClient((_) async => http.Response('Server Error', 500));

      const incoming = FriendRequest(
        id: 'req_fail_id',
        fromCode: 'KIOKU-REJECTED',
        toCode: 'KIOKU-SELF',
        fromName: 'Malicious',
      );

      final accepted = await UserProfileService.instance.acceptRequest(incoming);
      expect(accepted, isFalse);

      final friends = await UserProfileService.instance.getConnectedFriends();
      expect(friends.contains('KIOKU-REJECTED'), isFalse);

      UserProfileService.instance.httpClient = originalClient;
    });

    test('sendFriendRequest maps 404 to notFound', () async {
      await UserProfileService.instance.init();
      final originalClient = UserProfileService.instance.httpClient;
      UserProfileService.instance.httpClient = MockClient((request) async {
        if (request.url.path == '/friends/token') {
          return http.Response(jsonEncode({'token': 'mock_tok', 'friendCode': 'TEST'}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode({'error': 'Recipient not found'}), 404, headers: {'content-type': 'application/json'});
      });

      final result = await UserProfileService.instance.sendFriendRequest('NONEXISTENT-CODE');
      expect(result, FriendRequestResult.notFound);
      UserProfileService.instance.httpClient = originalClient;
    });

    test('sendFriendRequest maps 401/403 to unauthorized', () async {
      await UserProfileService.instance.init();
      final originalClient = UserProfileService.instance.httpClient;
      UserProfileService.instance.httpClient = MockClient((request) async {
        if (request.url.path == '/friends/token') {
          return http.Response(jsonEncode({'token': 'mock_tok', 'friendCode': 'TEST'}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode({'error': 'Invalid or expired token'}), 401, headers: {'content-type': 'application/json'});
      });

      final result = await UserProfileService.instance.sendFriendRequest('VALID-CODE-BUT-UNAUTH');
      expect(result, FriendRequestResult.unauthorized);
      UserProfileService.instance.httpClient = originalClient;
    });

    test('sendFriendRequest maps 409 Already friends to alreadyFriends', () async {
      await UserProfileService.instance.init();
      final originalClient = UserProfileService.instance.httpClient;
      UserProfileService.instance.httpClient = MockClient((request) async {
        if (request.url.path == '/friends/token') {
          return http.Response(jsonEncode({'token': 'mock_tok', 'friendCode': 'TEST'}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode({'error': 'Already connected as friends'}), 409, headers: {'content-type': 'application/json'});
      });

      final result = await UserProfileService.instance.sendFriendRequest('CONNECTED-FRIEND');
      expect(result, FriendRequestResult.alreadyFriends);
      UserProfileService.instance.httpClient = originalClient;
    });

    test('lookupFriendCode parses metadata on 200 and returns null on 404', () async {
      await UserProfileService.instance.init();
      final originalClient = UserProfileService.instance.httpClient;
      UserProfileService.instance.httpClient = MockClient((request) async {
        if (request.url.path == '/friends/token') {
          return http.Response(jsonEncode({'token': 'mock_tok', 'friendCode': 'TEST'}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/friends/lookup/VALID-USER') {
          return http.Response(
            jsonEncode({'exists': true, 'friendCode': 'VALID-USER', 'username': 'Valid User'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'error': 'Not found'}), 404, headers: {'content-type': 'application/json'});
      });

      final found = await UserProfileService.instance.lookupFriendCode('VALID-USER');
      expect(found, isNotNull);
      expect(found?.displayName, 'Valid User');
      expect(found?.friendCode, 'VALID-USER');

      final missing = await UserProfileService.instance.lookupFriendCode('UNKNOWN');
      expect(missing, isNull);

      UserProfileService.instance.httpClient = originalClient;
    });

    test('confirmInvite returns data on 200 and throws FriendException on 400/404', () async {
      await UserProfileService.instance.init();
      final originalClient = UserProfileService.instance.httpClient;
      UserProfileService.instance.httpClient = MockClient((request) async {
        if (request.url.path == '/friends/token') {
          return http.Response(jsonEncode({'token': 'mock_tok', 'friendCode': 'TEST'}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/friends/invite/confirm') {
          final body = jsonDecode(request.body);
          if (body['inviteCode'] == 'GOOD-INVITE') {
            return http.Response(
              jsonEncode({'success': true, 'fromCode': 'INVITER-1', 'status': 'request_created'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'error': 'Invite code not found or expired', 'code': 'INVITE_NOT_FOUND'}),
            404,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final result = await UserProfileService.instance.confirmInvite('GOOD-INVITE');
      expect(result, isNotNull);
      expect(result?['status'], 'request_created');

      expect(
        () async => await UserProfileService.instance.confirmInvite('BAD-INVITE'),
        throwsA(isA<FriendException>()),
      );

      UserProfileService.instance.httpClient = originalClient;
    });

    test('createUniversalInvite throws FriendException on server error', () async {
      await UserProfileService.instance.init();
      final originalClient = UserProfileService.instance.httpClient;
      UserProfileService.instance.httpClient = MockClient((request) async {
        if (request.url.path == '/friends/token') {
          return http.Response(jsonEncode({'token': 'mock_tok', 'friendCode': 'TEST'}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/friends/invite/create') {
          return http.Response('Internal Error', 500);
        }
        return http.Response('Not Found', 404);
      });

      expect(
        () async => await UserProfileService.instance.createUniversalInvite(),
        throwsA(isA<FriendException>()),
      );

      UserProfileService.instance.httpClient = originalClient;
    });
  });
}
