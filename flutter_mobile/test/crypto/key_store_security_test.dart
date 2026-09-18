import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodium_libs/src/platforms/sodium_windows.dart';
import 'package:flutter_mobile/core/crypto/crypto_core.dart';
import 'package:flutter_mobile/core/crypto/key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SodiumWindows.registerWith();

  setUpAll(() async {
    await CryptoCore.instance.init();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('KeyStore Security Invariants', () {
    test('Initialize and saveCollectionKey NEVER write key material to SharedPreferences', () async {
      final storage = InMemorySecureStorage();
      final keyStore = KeyStore(storage: storage);

      await keyStore.initialize();
      final masterKey = await keyStore.getMasterKey();
      expect(masterKey.length, equals(32));

      await keyStore.saveCollectionKey('album_123', masterKey);

      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      // Invariant: zero keys in SharedPreferences should contain any kioku_sec_* keys
      final leakedKeys = allKeys.where((k) => k.contains('kioku_sec_') || k.contains('backup')).toList();
      expect(leakedKeys, isEmpty);

      // Verify that the master key and collection key exist ONLY in the secure storage provider
      expect(await storage.containsKey(key: 'kioku_sec_master_key'), isTrue);
      expect(await storage.containsKey(key: 'kioku_sec_coll_key_album_123'), isTrue);
    });

    test('Collection key rotation generates fresh distinct key and stays strictly in secure storage', () async {
      final storage = InMemorySecureStorage();
      final keyStore = KeyStore(storage: storage);

      await keyStore.initialize();
      final key1 = await keyStore.getOrCreateCollectionKey('album_test');
      final key2 = await keyStore.rotateCollectionKey('album_test');

      expect(key1.length, equals(32));
      expect(key2.length, equals(32));
      expect(key1, isNot(equals(key2)));

      final currentKey = await keyStore.getOrCreateCollectionKey('album_test');
      expect(currentKey, equals(key2));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('kioku_sec_')), isEmpty);
    });
  });
}
