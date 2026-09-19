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
  });

  group('Universal Short Invite Link & Social Models', () {
    test('InviteResolution deserializes valid response properly', () {
      final json = {
        'status': 'valid',
        'code': '8F3KD2',
        'friendCode': 'KIOKU-ALICE1',
        'username': 'AliceInWonderland',
        'expiresAt': 1750000000000,
      };

      final resolution = InviteResolution.fromJson(json);

      expect(resolution.status, 'valid');
      expect(resolution.code, '8F3KD2');
      expect(resolution.friendCode, 'KIOKU-ALICE1');
      expect(resolution.username, 'AliceInWonderland');
      expect(resolution.isValid, isTrue);
      expect(resolution.isExpired, isFalse);
    });

    test('InviteResolution handles expired and invalid states', () {
      final expiredJson = {
        'status': 'expired',
        'code': 'EXPD12',
        'message': 'Invite code has expired',
      };
      final expired = InviteResolution.fromJson(expiredJson);
      expect(expired.status, 'expired');
      expect(expired.isValid, isFalse);
      expect(expired.isExpired, isTrue);

      final invalid = InviteResolution.invalid('BADCOD');
      expect(invalid.isValid, isFalse);
      expect(invalid.status, 'invalid');
    });

    test('InviteCreation model deserializes', () {
      final json = {
        'code': '8F3KD2',
        'url': 'https://kioku.app/i/8F3KD2',
        'expiresAt': 1750000000000,
      };

      final creation = InviteCreation.fromJson(json);
      expect(creation.code, '8F3KD2');
      expect(creation.url, 'https://kioku.app/i/8F3KD2');
      expect(creation.expiresAt, 1750000000000);
    });

    test('FriendUser model parses and roundtrips', () {
      final json = {
        'friendCode': 'KIOKU-BOB22',
        'username': 'BobTheBuilder',
        'connectedAt': 1710000000,
      };

      final user = FriendUser.fromJson(json);
      expect(user.friendCode, 'KIOKU-BOB22');
      expect(user.username, 'BobTheBuilder');
      expect(user.displayName, 'BobTheBuilder');
      expect(user.connectedAt, 1710000000);

      final jsonOut = user.toJson();
      expect(jsonOut['friendCode'], 'KIOKU-BOB22');
      expect(jsonOut['username'], 'BobTheBuilder');
    });

    test('SentFriendRequest model parses statuses and cancellation correctly', () {
      final json = {
        'id': 'req_sent_1',
        'toCode': 'KIOKU-CHARLIE',
        'toName': 'Charlie',
        'createdAt': 1700000000,
        'status': 'pending',
      };

      final sent = SentFriendRequest.fromJson(json);
      expect(sent.id, 'req_sent_1');
      expect(sent.toCode, 'KIOKU-CHARLIE');
      expect(sent.toName, 'Charlie');
      expect(sent.status, 'pending');
      expect(sent.isPending, isTrue);
      expect(sent.isExpired, isFalse);
    });

    test('createUniversalInvite and resolveInvite make expected HTTP calls', () async {
      await UserProfileService.instance.init();

      UserProfileService.instance.httpClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/friends/token') {
          return http.Response(
            jsonEncode({'token': 'mock_token', 'friendCode': 'KIOKU-TEST'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path == '/friends/invite') {
          return http.Response(
            jsonEncode({
              'code': '9X4KP1',
              'url': 'https://kioku.app/i/9X4KP1',
              'expiresAt': DateTime.now().millisecondsSinceEpoch + 86400000,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path == '/invite/9X4KP1' || path == '/friends/invite/9X4KP1') {
          return http.Response(
            jsonEncode({
              'status': 'valid',
              'code': '9X4KP1',
              'friendCode': 'KIOKU-HOST1',
              'username': 'HostUser',
              'expiresAt': DateTime.now().millisecondsSinceEpoch + 86400000,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final invite = await UserProfileService.instance.createUniversalInvite();
      expect(invite, isNotNull);
      expect(invite!.code, '9X4KP1');
      expect(invite.url, 'https://kioku.app/i/9X4KP1');

      final resolution = await UserProfileService.instance.resolveInvite('9X4KP1');
      expect(resolution.isValid, isTrue);
      expect(resolution.code, '9X4KP1');
      expect(resolution.friendCode, 'KIOKU-HOST1');
      expect(resolution.username, 'HostUser');
    });
  });
}
