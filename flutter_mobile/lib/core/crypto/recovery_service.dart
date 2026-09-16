import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'crypto_core.dart';

class RecoveryBlob {
  final Uint8List encryptedMasterKey;
  final Uint8List nonce;

  const RecoveryBlob({
    required this.encryptedMasterKey,
    required this.nonce,
  });
}

class RecoveryService {
  RecoveryService._();
  static final RecoveryService instance = RecoveryService._();

  /// Generates a 256-bit recovery key as a 24-word BIP39 mnemonic phrase
  String generateRecoveryPhrase() {
    final entropy = CryptoCore.instance.generateRandomKey();
    final hexString = entropy.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return bip39.entropyToMnemonic(hexString);
  }

  /// Converts a 24-word mnemonic back into 32-byte recovery key
  Uint8List phraseToKey(String phrase) {
    final cleaned = phrase.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final hexStr = bip39.mnemonicToEntropy(cleaned);
    final result = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      result[i] = int.parse(hexStr.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  /// Validates whether a phrase is a valid 24-word BIP39 mnemonic
  bool validatePhrase(String phrase) {
    final words = phrase.trim().split(RegExp(r'\s+'));
    if (words.length != 24) return false;
    return bip39.validateMnemonic(phrase.trim());
  }

  /// Creates a mutual recovery blob: wraps masterKey using the recoveryKey
  RecoveryBlob createRecoveryBlob(Uint8List masterKey, Uint8List recoveryKey) {
    final wrapped = CryptoCore.instance.wrapKey(masterKey, recoveryKey);
    return RecoveryBlob(
      encryptedMasterKey: wrapped.cipherText,
      nonce: wrapped.nonce,
    );
  }

  /// Recovers masterKey from a recovery phrase and encrypted blob
  Uint8List recoverMasterKey({
    required String phrase,
    required Uint8List encryptedMasterKey,
    required Uint8List nonce,
  }) {
    final recoveryKey = phraseToKey(phrase);
    return CryptoCore.instance.unwrapKey(
      encryptedMasterKey,
      nonce,
      recoveryKey,
    );
  }
}
