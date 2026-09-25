import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_mobile/core/config.dart';
import 'package:flutter_mobile/core/crypto/crypto_core.dart';
import 'package:flutter_mobile/core/crypto/key_store.dart';
import 'package:flutter_mobile/core/network/http_client_helper.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/util/kioku_log.dart';

class InviteService {
  InviteService._();
  static final InviteService instance = InviteService._();

  HttpClientHelper client = HttpClientHelper.instance;

  // Configurable signaling/relay server host
  String get backendBaseUrl => AppConfig.backendBaseUrl;

  /// 1. Create a claim token with a 10-minute TTL and inviter device public key
  Future<({String claimToken, String inviterPubKey})?> createInviteClaim({
    required String albumId,
  }) async {
    try {
      final myPubKey = await KeyStore.instance.getDevicePublicKey();
      final myPubKeyB64 = base64UrlEncode(myPubKey);

      final res = await UserProfileService.instance.authedRequest(
        (headers) => client.post(
          Uri.parse('$backendBaseUrl/claim/request'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'albumId': albumId, 'inviterPubKey': myPubKeyB64}),
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (
          claimToken: data['claimToken'] as String,
          inviterPubKey: myPubKeyB64,
        );
      } else {
        KiokuLog.e(
          'InviteService',
          'createInviteClaim failed: ${res.statusCode} ${res.body}',
        );
      }
    } catch (e) {
      KiokuLog.e('InviteService', 'createInviteClaim exception', e);
    }
    return null;
  }

  /// 2. Redeem a claim token as joiner
  Future<({String albumId, Uint8List inviterPubKey})?> redeemClaim({
    required String claimToken,
  }) async {
    try {
      final myPubKey = await KeyStore.instance.getDevicePublicKey();
      final res = await UserProfileService.instance.authedRequest(
        (headers) => client.post(
          Uri.parse('$backendBaseUrl/claim/redeem'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'claimToken': claimToken,
            'recipientPubKey': base64UrlEncode(myPubKey),
          }),
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final inviterPubKeyB64 = data['inviterPubKey'] as String;
        return (
          albumId: data['albumId'] as String,
          inviterPubKey: base64Url.decode(
            base64Url.normalize(inviterPubKeyB64),
          ),
        );
      } else {
        KiokuLog.e(
          'InviteService',
          'redeemClaim failed: ${res.statusCode} ${res.body}',
        );
      }
    } catch (e) {
      KiokuLog.e('InviteService', 'redeemClaim exception', e);
    }
    return null;
  }

  /// 3. Inviter seals collection key using crypto_box_seal for recipient
  Future<bool> sealAndPostCollectionKey({
    required String claimToken,
    required String albumId,
    required Uint8List recipientPubKey,
  }) async {
    try {
      final collectionKey = await KeyStore.instance.getOrCreateCollectionKey(
        albumId,
      );
      final sealed = CryptoCore.instance.sealForPublicKey(
        collectionKey,
        recipientPubKey,
      );

      final res = await UserProfileService.instance.authedRequest(
        (headers) => client.post(
          Uri.parse('$backendBaseUrl/claim/seal'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'claimToken': claimToken,
            'sealedKey': base64UrlEncode(sealed),
          }),
        ),
      );

      return res.statusCode == 200;
    } catch (e) {
      KiokuLog.e('InviteService', 'sealAndPostCollectionKey exception', e);
      return false;
    }
  }

  /// 4. Joiner fetches and unseals collection key
  Future<bool> fetchAndUnsealCollectionKey({
    required String claimToken,
    required String albumId,
  }) async {
    try {
      final res = await client.get(
        Uri.parse('$backendBaseUrl/claim/sealed/$claimToken'),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final sealedKeyB64 = data['sealedKey'] as String?;
        if (sealedKeyB64 != null && sealedKeyB64.isNotEmpty) {
          final sealedBytes = base64Url.decode(
            base64Url.normalize(sealedKeyB64),
          );
          final myPubKey = await KeyStore.instance.getDevicePublicKey();
          final mySecKey = await KeyStore.instance.getDevicePrivateKey();

          final unsealed = CryptoCore.instance.unsealWithPrivateKey(
            sealedBytes,
            myPubKey,
            mySecKey,
          );

          if (unsealed.length == 32) {
            await KeyStore.instance.saveCollectionKey(albumId, unsealed);
            return true;
          }
        }
      }
    } catch (e) {
      KiokuLog.e('InviteService', 'fetchAndUnsealCollectionKey exception', e);
    }
    return false;
  }
}
