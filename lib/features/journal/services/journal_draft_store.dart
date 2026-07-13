import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class JournalDraftStore {
  JournalDraftStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static String _key(String userId) => 'journal_draft_v1_$userId';

  Future<Map<String, dynamic>?> read(String userId) async {
    String? raw;
    try {
      raw = await _storage.read(key: _key(userId));
    } catch (_) {
      return null;
    }
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String userId, Map<String, dynamic> value) async {
    try {
      await _storage.write(key: _key(userId), value: jsonEncode(value));
    } catch (_) {
      // Draft persistence is best-effort and must never block journaling.
    }
  }

  Future<void> clear(String userId) async {
    try {
      await _storage.delete(key: _key(userId));
    } catch (_) {
      // Saving the Firestore entry remains successful if local cleanup fails.
    }
  }
}
