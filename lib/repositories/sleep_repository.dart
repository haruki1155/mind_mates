import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../features/sleep/models/sleep_models.dart';
import '../features/sleep/services/sleep_local_store.dart';
import '../services/firebase/firestore_service.dart';

class SleepLoadResult {
  const SleepLoadResult({
    required this.entries,
    required this.consent,
    required this.pendingSync,
  });
  final List<SleepEntry> entries;
  final SleepConsent? consent;
  final bool pendingSync;
}

class SleepRepository {
  SleepRepository({
    SleepLocalStore? localStore,
    FirestoreService? firestoreService,
  }) : _local = localStore ?? SleepLocalStore(),
       _firestore = firestoreService ?? FirestoreService();

  final SleepLocalStore _local;
  final FirestoreService _firestore;

  Future<SleepLoadResult> load(String userId) async {
    final consent = await _local.readConsent(userId);
    var entries = await _local.readEntries(userId);
    var pending = (await _local.readPending(userId)).isNotEmpty;
    if (consent?.isCurrent == true && consent!.cloudEnabled) {
      try {
        await _writeCloudPreference(userId);
        entries = await _mergeCloud(userId, entries);
        pending = false;
      } catch (_) {
        pending = true;
      }
    }
    return SleepLoadResult(
      entries: entries,
      consent: consent,
      pendingSync: pending,
    );
  }

  Future<void> setConsent(String userId, SleepConsentChoice choice) async {
    final now = DateTime.now();
    final consent = SleepConsent(
      choice: choice,
      version: SleepConsent.currentVersion,
      decidedAt: now,
    );
    await _local.writeConsent(userId, consent);
    if (choice == SleepConsentChoice.cloud) {
      try {
        await _writeCloudPreference(userId);
        await _mergeCloud(userId, await _local.readEntries(userId));
      } catch (_) {
        // The local decision remains valid; refresh/retry completes cloud setup.
      }
    }
  }

  Future<List<SleepEntry>> save(
    SleepEntry entry, {
    required bool cloudEnabled,
  }) async {
    final contributors = {...entry.contributorTags};
    if (entry.napCount > 0 || entry.napMinutes > 0) {
      contributors.add('naps');
    } else {
      contributors.remove('naps');
    }
    final normalized = entry.copyWith(contributorTags: contributors);
    await _local.writeEntry(normalized);
    if (cloudEnabled) {
      try {
        await _writeCloud(normalized);
        final pending = await _local.readPending(entry.userId)
          ..remove('save:${entry.wakeDateKey}');
        await _local.writePending(entry.userId, pending);
      } catch (_) {
        final pending = await _local.readPending(entry.userId)
          ..add('save:${entry.wakeDateKey}');
        await _local.writePending(entry.userId, pending);
        rethrow;
      }
    }
    return _local.readEntries(entry.userId);
  }

  Future<List<SleepEntry>> delete(
    String userId,
    String wakeDateKey, {
    required bool cloudEnabled,
  }) async {
    await _local.deleteEntry(userId, wakeDateKey);
    if (cloudEnabled) {
      final pending = await _local.readPending(userId);
      Object? syncError;
      try {
        await _firestore.deleteDocument(
          FirestoreCollections.sleepEntries,
          SleepEntry.documentId(
            userId,
            SleepEntry.dateFromWakeKey(wakeDateKey),
          ),
        );
        pending.remove('delete:$wakeDateKey');
      } catch (_) {
        pending.add('delete:$wakeDateKey');
        syncError = StateError('Sleep deletion is pending cloud sync.');
      }
      await _local.writePending(userId, pending);
      if (syncError != null) throw syncError;
    }
    return _local.readEntries(userId);
  }

  Future<void> deleteAll(String userId, {required bool cloudEnabled}) async {
    if (cloudEnabled) await _deleteCloudEntries(userId);
    await _local.clearEntries(userId);
  }

  Future<void> revokeCloud(String userId) async {
    await _deleteCloudEntries(userId);
    await _firestore.deleteDocument(
      FirestoreCollections.sleepPreferences,
      userId,
    );
    await _local.writeConsent(
      userId,
      SleepConsent(
        choice: SleepConsentChoice.localOnly,
        version: SleepConsent.currentVersion,
        decidedAt: DateTime.now(),
      ),
    );
    await _local.writePending(userId, {});
  }

  Future<List<SleepEntry>> retrySync(String userId) async {
    await _writeCloudPreference(userId);
    return _mergeCloud(userId, await _local.readEntries(userId));
  }

  Future<List<SleepEntry>> _mergeCloud(
    String userId,
    List<SleepEntry> localEntries,
  ) async {
    final existingPending = await _local.readPending(userId);
    final deleteKeys = existingPending
        .where((value) => value.startsWith('delete:'))
        .map((value) => value.substring('delete:'.length))
        .toSet();
    final unresolvedDeletes = <String>{};
    for (final wakeDateKey in deleteKeys) {
      try {
        await _firestore.deleteDocument(
          FirestoreCollections.sleepEntries,
          SleepEntry.documentId(
            userId,
            SleepEntry.dateFromWakeKey(wakeDateKey),
          ),
        );
      } catch (_) {
        unresolvedDeletes.add('delete:$wakeDateKey');
      }
    }
    final docs = await _firestore.getDocuments(
      FirestoreCollections.sleepEntries,
      whereEquals: {'userId': userId},
      orderBy: 'wakeDateKey',
    );
    final cloud = <String, SleepEntry>{};
    for (final doc in docs) {
      final entry = SleepEntry.fromJson(doc, id: doc['id']?.toString());
      if (deleteKeys.contains(entry.wakeDateKey)) continue;
      cloud[entry.wakeDateKey] = entry;
    }
    final merged = <String, SleepEntry>{
      for (final entry in localEntries) entry.wakeDateKey: entry,
    };
    for (final entry in cloud.values) {
      final local = merged[entry.wakeDateKey];
      if (local == null ||
          entry.clientUpdatedAt.isAfter(local.clientUpdatedAt)) {
        merged[entry.wakeDateKey] = entry;
        await _local.writeEntry(entry);
      }
    }
    final pending = <String>{...unresolvedDeletes};
    for (final entry in merged.values) {
      final remote = cloud[entry.wakeDateKey];
      if (remote == null ||
          entry.clientUpdatedAt.isAfter(remote.clientUpdatedAt)) {
        try {
          await _writeCloud(entry);
        } catch (_) {
          pending.add('save:${entry.wakeDateKey}');
        }
      }
    }
    await _local.writePending(userId, pending);
    if (pending.isNotEmpty) {
      throw StateError('Some sleep entries could not sync.');
    }
    final output = merged.values.toList()
      ..sort((a, b) => b.wakeDateKey.compareTo(a.wakeDateKey));
    return output;
  }

  Future<void> _writeCloud(SleepEntry entry) {
    final data = entry.toJson()
      ..remove('id')
      ..update(
        'attemptedSleepAt',
        (_) => Timestamp.fromDate(
          SleepEntry.manilaWallToInstant(entry.attemptedSleepAt),
        ),
      )
      ..update(
        'sleepOnsetAt',
        (_) => Timestamp.fromDate(
          SleepEntry.manilaWallToInstant(entry.sleepOnsetAt),
        ),
      )
      ..update(
        'finalWakeAt',
        (_) => Timestamp.fromDate(
          SleepEntry.manilaWallToInstant(entry.finalWakeAt),
        ),
      )
      ..update(
        'outOfBedAt',
        (_) => Timestamp.fromDate(
          SleepEntry.manilaWallToInstant(entry.outOfBedAt),
        ),
      )
      ..update('createdAt', (_) => Timestamp.fromDate(entry.createdAt))
      ..update(
        'clientUpdatedAt',
        (_) => Timestamp.fromDate(entry.clientUpdatedAt),
      )
      ..['updatedAt'] = FieldValue.serverTimestamp();
    return _firestore.setDocument(
      FirestoreCollections.sleepEntries,
      entry.id,
      data,
    );
  }

  Future<void> _writeCloudPreference(String userId) {
    return _firestore
        .setDocument(FirestoreCollections.sleepPreferences, userId, {
          'userId': userId,
          'consentVersion': SleepConsent.currentVersion,
          'cloudConsent': true,
          'grantedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _deleteCloudEntries(String userId) async {
    final query = await _firestore.firestore
        .collection(FirestoreCollections.sleepEntries)
        .where('userId', isEqualTo: userId)
        .get();
    for (var offset = 0; offset < query.docs.length; offset += 450) {
      final batch = _firestore.firestore.batch();
      for (final doc in query.docs.skip(offset).take(450)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
