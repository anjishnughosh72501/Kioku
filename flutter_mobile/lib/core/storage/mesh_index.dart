import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MeshIndexEntry {
  final String objectId;
  final String containerId;
  final bool hasFullRes;
  final bool hasThumb;
  final Set<String> knownHolders;
  final DateTime lastSeen;

  const MeshIndexEntry({
    required this.objectId,
    required this.containerId,
    required this.hasFullRes,
    required this.hasThumb,
    required this.knownHolders,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'objectId': objectId,
        'containerId': containerId,
        'hasFullRes': hasFullRes,
        'hasThumb': hasThumb,
        'knownHolders': knownHolders.toList(),
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory MeshIndexEntry.fromJson(Map<String, dynamic> json) => MeshIndexEntry(
        objectId: json['objectId'] as String,
        containerId: json['containerId'] as String? ?? 'default',
        hasFullRes: json['hasFullRes'] as bool? ?? false,
        hasThumb: json['hasThumb'] as bool? ?? false,
        knownHolders: Set<String>.from((json['knownHolders'] as List<dynamic>?) ?? []),
        lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? '') ?? DateTime.now(),
      );

  MeshIndexEntry copyWith({
    bool? hasFullRes,
    bool? hasThumb,
    Set<String>? knownHolders,
    DateTime? lastSeen,
  }) =>
      MeshIndexEntry(
        objectId: objectId,
        containerId: containerId,
        hasFullRes: hasFullRes ?? this.hasFullRes,
        hasThumb: hasThumb ?? this.hasThumb,
        knownHolders: knownHolders ?? this.knownHolders,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}

class MeshIndex {
  MeshIndex._();
  static final MeshIndex instance = MeshIndex._();

  static const _kPrefix = 'kioku_mesh_index_';

  final Map<String, MeshIndexEntry> _memoryIndex = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_kPrefix));
    for (final k in keys) {
      final raw = prefs.getString(k);
      if (raw != null) {
        try {
          final entry = MeshIndexEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          _memoryIndex[entry.objectId] = entry;
        } catch (_) {}
      }
    }
    _loaded = true;
  }

  Future<MeshIndexEntry?> getEntry(String objectId) async {
    await _ensureLoaded();
    return _memoryIndex[objectId];
  }

  Future<void> saveEntry(MeshIndexEntry entry) async {
    await _ensureLoaded();
    _memoryIndex[entry.objectId] = entry;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefix + entry.objectId, jsonEncode(entry.toJson()));
  }

  Future<void> deleteEntry(String objectId) async {
    await _ensureLoaded();
    _memoryIndex.remove(objectId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefix + objectId);
  }

  Future<List<String>> listBlobIds(String containerId) async {
    await _ensureLoaded();
    return _memoryIndex.values
        .where((e) => e.containerId == containerId)
        .map((e) => e.objectId)
        .toList();
  }

  Future<void> recordHolder(String objectId, String deviceId) async {
    final entry = await getEntry(objectId);
    if (entry != null) {
      final updated = entry.copyWith(
        knownHolders: {...entry.knownHolders, deviceId},
        lastSeen: DateTime.now(),
      );
      await saveEntry(updated);
    }
  }
}
