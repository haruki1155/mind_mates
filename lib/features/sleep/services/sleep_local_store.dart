import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/sleep_models.dart';

class SleepLocalStore {
  SleepLocalStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _indexKey(String userId) => 'sleep_index_v1_$userId';
  String _entryKey(String userId, String wakeDateKey) =>
      'sleep_entry_v1_${userId}_$wakeDateKey';
  String _consentKey(String userId) => 'sleep_consent_v1_$userId';
  String _pendingKey(String userId) => 'sleep_pending_v1_$userId';

  Future<List<SleepEntry>> readEntries(String userId) async {
    final keys = await _readStringList(_indexKey(userId));
    final entries = <SleepEntry>[];
    for (final wakeDateKey in keys) {
      try {
        final raw = await _storage.read(key: _entryKey(userId, wakeDateKey));
        if (raw == null) continue;
        entries.add(
          SleepEntry.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          ),
        );
      } catch (_) {
        // Ignore a corrupt entry while keeping the rest of the diary available.
      }
    }
    entries.sort((a, b) => b.wakeDateKey.compareTo(a.wakeDateKey));
    return entries;
  }

  Future<void> writeEntry(SleepEntry entry) async {
    final index = (await _readStringList(_indexKey(entry.userId))).toSet()
      ..add(entry.wakeDateKey);
    await _storage.write(
      key: _entryKey(entry.userId, entry.wakeDateKey),
      value: jsonEncode(entry.toJson()),
    );
    await _writeStringList(_indexKey(entry.userId), index.toList()..sort());
  }

  Future<void> deleteEntry(String userId, String wakeDateKey) async {
    await _storage.delete(key: _entryKey(userId, wakeDateKey));
    final index = await _readStringList(_indexKey(userId))
      ..remove(wakeDateKey);
    await _writeStringList(_indexKey(userId), index);
  }

  Future<void> clearEntries(String userId) async {
    final keys = await _readStringList(_indexKey(userId));
    for (final wakeDateKey in keys) {
      await _storage.delete(key: _entryKey(userId, wakeDateKey));
    }
    await _storage.delete(key: _indexKey(userId));
    await _storage.delete(key: _pendingKey(userId));
  }

  Future<SleepConsent?> readConsent(String userId) async {
    try {
      final raw = await _storage.read(key: _consentKey(userId));
      if (raw == null) return null;
      return SleepConsent.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeConsent(String userId, SleepConsent consent) => _storage
      .write(key: _consentKey(userId), value: jsonEncode(consent.toJson()));

  Future<Set<String>> readPending(String userId) async =>
      (await _readStringList(_pendingKey(userId))).toSet();

  Future<void> writePending(String userId, Set<String> wakeDateKeys) async {
    if (wakeDateKeys.isEmpty) {
      await _storage.delete(key: _pendingKey(userId));
      return;
    }
    await _writeStringList(_pendingKey(userId), wakeDateKeys.toList()..sort());
  }

  Future<List<String>> _readStringList(String key) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null) return <String>[];
      return (jsonDecode(raw) as List)
          .map((value) => value.toString())
          .toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _writeStringList(String key, List<String> values) =>
      _storage.write(key: key, value: jsonEncode(values));
}
