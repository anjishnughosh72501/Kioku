import 'dart:collection';
import 'dart:typed_data';

/// LRU cache with a maximum byte-budget eviction policy.
class ByteBudgetLruCache {
  ByteBudgetLruCache({required this.maxBytes});

  final int maxBytes;
  final LinkedHashMap<String, Uint8List> _map = LinkedHashMap<String, Uint8List>();
  int _used = 0;

  int get usedBytes => _used;
  int get length => _map.length;

  Uint8List? get(String key) {
    final v = _map.remove(key);
    if (v != null) {
      _map[key] = v; // promote to MRU
    }
    return v;
  }

  void put(String key, Uint8List bytes) {
    if (_map.containsKey(key)) {
      _used -= _map[key]!.length;
      _map.remove(key);
    }
    while (_used + bytes.length > maxBytes && _map.isNotEmpty) {
      final oldestKey = _map.keys.first;
      _used -= _map[oldestKey]!.length;
      _map.remove(oldestKey);
    }
    _map[key] = bytes;
    _used += bytes.length;
  }

  void remove(String key) {
    final v = _map.remove(key);
    if (v != null) {
      _used -= v.length;
    }
  }

  void clear() {
    _map.clear();
    _used = 0;
  }
}
