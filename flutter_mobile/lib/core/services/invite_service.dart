import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_mobile/core/config.dart';
import 'package:flutter_mobile/core/crypto/crypto_core.dart';
import 'package:flutter_mobile/core/crypto/key_store.dart';

class InviteService {
  InviteService._();
  static final InviteService instance = InviteService._();

  // Configurable signaling/relay server host
  String backendBaseUrl = AppConfig.backendBaseUrl;

  /// 1. Create a claim token with a 10-minute TTL and inviter device public key
  Future<({String claimToken, String inviterPubKey})?> createInviteClaim({
    required String albumId,
  }) async {
    try {
      final myPubKey = await KeyStore.instance.getDevicePublicKey();
      final myPubKeyB64 = base64UrlEncode(myPubKey);

      final res = await http.post(
        Uri.parse('$backendBaseUrl/claim/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'albumId': albumId,
          'inviterPubKey': myPubKeyB64,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (
          claimToken: data['claimToken'] as String,
          inviterPubKey: myPubKeyB64,
        );
      }
    } catch (_) {
      // Fallback for offline / direct mesh exchange
    }

    try {
      final myPubKey = await KeyStore.instance.getDevicePublicKey();
      return (
        claimToken: '',
        inviterPubKey: base64UrlEncode(myPubKey),
      );
    } catch (_) {
      return null;
    }
  }

  /// 2. Redeem a claim token as joiner
  Future<({String albumId, Uint8List inviterPubKey})?> redeemClaim({
    required String claimToken,
  }) async {
    try {
      final myPubKey = await KeyStore.instance.getDevicePublicKey();
      final res = await http.post(
        Uri.parse('$backendBaseUrl/claim/redeem'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'claimToken': claimToken,
          'recipientPubKey': base64UrlEncode(myPubKey),
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final inviterPubKeyB64 = data['inviterPubKey'] as String;
        return (
          albumId: data['albumId'] as String,
          inviterPubKey: base64Url.decode(base64Url.normalize(inviterPubKeyB64)),
        );
      }
    } catch (_) {}
    return null;
  }

  /// 3. Inviter seals collection key using crypto_box_seal for recipient
  Future<bool> sealAndPostCollectionKey({
    required String claimToken,
    required String albumId,
    required Uint8List recipientPubKey,
  }) async {
    try {
      final collectionKey = await KeyStore.instance.getOrCreateCollectionKey(albumId);
      final sealed = CryptoCore.instance.sealForPublicKey(collectionKey, recipientPubKey);

      final res = await http.post(
        Uri.parse('$backendBaseUrl/claim/seal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'claimToken': claimToken,
          'sealedKey': base64UrlEncode(sealed),
        }),
      ).timeout(const Duration(seconds: 4));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 4. Joiner fetches and unseals collection key
  Future<bool> fetchAndUnsealCollectionKey({
    required String claimToken,
    required String albumId,
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$backendBaseUrl/claim/sealed/$claimToken'),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final sealedKeyB64 = data['sealedKey'] as String?;
        if (sealedKeyB64 != null && sealedKeyB64.isNotEmpty) {
          final sealedBytes = base64Url.decode(base64Url.normalize(sealedKeyB64));
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
    } catch (_) {}
    return false;
  }
}
