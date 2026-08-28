import 'package:cloud_functions/cloud_functions.dart';

import '../../../services/firebase/firebase_callable_router.dart';
import '../models/sleep_models.dart';

class SleepCloudConflict implements Exception {
  const SleepCloudConflict(this.remoteEntry);
  final SleepEntry remoteEntry;
}

class SleepCloudService {
  // Resolved lazily so unit tests can supply a fake callable client.
  // ignore: prefer_initializing_formals
  SleepCloudService({FirebaseFunctions? functions}) : _functions = functions;

  final FirebaseFunctions? _functions;
  FirebaseFunctions get _client => _functions ?? FirebaseFunctions.instance;

  Future<void> setConsent() => _call('setSleepCloudConsent');

  Future<SleepEntry> save(SleepEntry entry) async {
    final data = await _call('saveSleepEntry', {'entry': entry.toJson()});
    if (data['status']?.toString() == 'conflict') {
      final raw = Map<String, dynamic>.from(data['entry'] as Map);
      throw SleepCloudConflict(
        SleepEntry.fromJson(raw, id: raw['id']?.toString()),
      );
    }
    final raw = data['entry'];
    if (raw is! Map) {
      throw const FormatException('Sleep save response was invalid.');
    }
    final entryJson = Map<String, dynamic>.from(raw);
    return SleepEntry.fromJson(entryJson, id: entryJson['id']?.toString());
  }

  Future<void> delete(String wakeDateKey, {required int revision}) => _call(
    'deleteSleepEntry',
    {'wakeDateKey': wakeDateKey, 'revision': revision},
  );

  Future<void> deleteAll() => _call('deleteAllSleepEntries');

  Future<void> revoke() => _call('revokeSleepCloud');

  Future<SleepShareGrant> createShare(int summaryWindowDays) async {
    final data = await _call('createSleepShare', {
      'summaryWindowDays': summaryWindowDays,
    });
    final expiresAt = DateTime.tryParse(
      data['accessExpiresAt']?.toString() ?? '',
    );
    if (data['shareId'] == null || expiresAt == null) {
      throw const FormatException('Sleep sharing response was invalid.');
    }
    return SleepShareGrant(
      id: data['shareId'].toString(),
      summaryWindowDays: summaryWindowDays,
      accessExpiresAt: expiresAt,
      revoked: false,
    );
  }

  Future<void> revokeShare(String shareId) =>
      _call('revokeSleepShare', {'shareId': shareId});

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, dynamic> payload = const {},
  ]) async {
    final response = await _client.routedCallable(name).call(payload);
    if (response.data is! Map) {
      throw const FormatException('Sleep cloud response was invalid.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }
}
