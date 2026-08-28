import 'dart:async';

import '../database/firestore_collections.dart';
import '../features/sleep/models/sleep_models.dart';
import '../features/sleep/services/sleep_local_store.dart';
import '../features/sleep/services/sleep_cloud_service.dart';
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
    SleepCloudService? cloudService,
  }) : _local = localStore ?? SleepLocalStore(),
       _firestore = firestoreService ?? FirestoreService(),
       _cloud = cloudService ?? SleepCloudService();

  final SleepLocalStore _local;
  final FirestoreService _firestore;
  final SleepCloudService _cloud;

  Future<SleepLoadResult> load(String userId) async {
    final consent = await _local.readConsent(userId);
    var entries = await _local.readEntries(userId);
    var pending = (await _local.readPending(userId)).isNotEmpty;
    if (consent?.isCurrent == true && consent!.cloudEnabled) {
      try {
        await _cloud.setConsent();
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
        await _cloud.setConsent();
        await _mergeCloud(userId, await _local.readEntries(userId));
      } catch (_) {
        // The local decision remains valid; refresh/retry completes cloud setup.
      }
    }
  }

  Future<SleepSaveResult> save(
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
    var savedEntry = normalized;
    try {
      await _local.writeEntry(normalized);
    } catch (_) {
      return const SleepSaveResult(
        status: SleepSaveStatus.localSaveFailed,
        message:
            'We could not save this entry on this device. Please try again.',
      );
    }
    if (cloudEnabled) {
      try {
        final canonical = await _cloud.save(normalized);
        await _local.writeEntry(canonical);
        savedEntry = canonical;
        final pending = await _local.readPending(entry.userId)
          ..remove('save:${entry.wakeDateKey}');
        await _local.writePending(entry.userId, pending);
      } on SleepCloudConflict catch (error) {
        await _local.writeEntry(normalized);
        final pending = await _local.readPending(entry.userId)
          ..remove('save:${entry.wakeDateKey}');
        await _local.writePending(entry.userId, pending);
        return SleepSaveResult(
          status: SleepSaveStatus.conflict,
          message:
              'This entry changed on another device. Review the cloud version before replacing it.',
          conflictingEntry: error.remoteEntry,
        );
      } catch (_) {
        final pending = await _local.readPending(entry.userId)
          ..add('save:${entry.wakeDateKey}');
        await _local.writePending(entry.userId, pending);
        return SleepSaveResult(
          status: SleepSaveStatus.savedLocallySyncPending,
          message: 'Saved on this device. Cloud sync is pending.',
          savedEntry: savedEntry,
        );
      }
    }
    return SleepSaveResult(
      status: SleepSaveStatus.savedLocallyAndSynced,
      savedEntry: savedEntry,
    );
  }

  Future<List<SleepEntry>> delete(
    String userId,
    String wakeDateKey, {
    required bool cloudEnabled,
  }) async {
    final existing = await _local.readEntries(userId);
    final revision = existing
        .where((entry) => entry.wakeDateKey == wakeDateKey)
        .map((entry) => entry.revision)
        .firstOrNull;
    await _local.deleteEntry(userId, wakeDateKey);
    if (cloudEnabled) {
      final pending = await _local.readPending(userId);
      Object? syncError;
      try {
        await _cloud.delete(wakeDateKey, revision: revision ?? 0);
        pending.removeWhere(
          (value) => value.startsWith('delete:$wakeDateKey:'),
        );
      } catch (_) {
        pending.add('delete:$wakeDateKey:${revision ?? 0}');
        syncError = StateError('Sleep deletion is pending cloud sync.');
      }
      await _local.writePending(userId, pending);
      if (syncError != null) throw syncError;
    }
    return _local.readEntries(userId);
  }

  Future<void> deleteAll(String userId, {required bool cloudEnabled}) async {
    if (cloudEnabled) await _cloud.deleteAll();
    await _local.clearEntries(userId);
  }

  Future<void> revokeCloud(String userId) async {
    await _cloud.revoke();
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
    await _cloud.setConsent();
    return _mergeCloud(userId, await _local.readEntries(userId));
  }

  Future<List<SleepEntry>> keepCloudVersion(SleepEntry entry) async {
    await _local.writeEntry(entry);
    return _local.readEntries(entry.userId);
  }

  Future<SleepShareGrant> createCounselorShare(int summaryWindowDays) =>
      _cloud.createShare(summaryWindowDays);

  Future<List<SleepShareGrant>> loadCounselorShares(String userId) async {
    final docs = await _firestore.getDocuments(
      FirestoreCollections.sleepSharedSummaries,
      whereEquals: {'ownerId': userId},
      orderBy: 'generatedAt',
    );
    return docs
        .map((doc) => SleepShareGrant.fromJson(doc))
        .toList(growable: false);
  }

  Future<void> revokeCounselorShare(String shareId) =>
      _cloud.revokeShare(shareId);

  Future<List<SleepEntry>> _mergeCloud(
    String userId,
    List<SleepEntry> localEntries,
  ) async {
    final existingPending = await _local.readPending(userId);
    final deletePairs = existingPending
        .where((value) => value.startsWith('delete:'))
        .map((value) => value.substring('delete:'.length).split(':'))
        .where((parts) => parts.length == 2)
        .map((parts) => MapEntry(parts[0], int.tryParse(parts[1]) ?? 0));
    final deleteOperations = <String, int>{
      for (final pair in deletePairs) pair.key: pair.value,
    };
    final deleteKeys = deleteOperations.keys.toSet();
    final unresolvedDeletes = <String>{};
    for (final wakeDateKey in deleteKeys) {
      try {
        await _cloud.delete(
          wakeDateKey,
          revision: deleteOperations[wakeDateKey] ?? 0,
        );
      } catch (_) {
        unresolvedDeletes.add(
          'delete:$wakeDateKey:${deleteOperations[wakeDateKey] ?? 0}',
        );
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
      if (local == null || entry.revision > local.revision) {
        merged[entry.wakeDateKey] = entry;
        await _local.writeEntry(entry);
      }
    }
    final pending = <String>{...unresolvedDeletes};
    for (final entry in merged.values) {
      final remote = cloud[entry.wakeDateKey];
      if (remote == null || entry.revision > remote.revision) {
        try {
          final canonical = await _cloud.save(entry);
          merged[entry.wakeDateKey] = canonical;
          await _local.writeEntry(canonical);
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
}
