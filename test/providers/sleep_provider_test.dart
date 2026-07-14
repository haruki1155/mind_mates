import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/sleep/models/sleep_models.dart';
import 'package:mind_mates/providers/sleep_provider.dart';
import 'package:mind_mates/repositories/sleep_repository.dart';

void main() {
  test('local-only consent saves entries without cloud sync', () async {
    final repository = _FakeSleepRepository();
    final provider = SleepProvider(repository);
    await provider.load('user_1');
    await provider.chooseStorage('user_1', SleepConsentChoice.localOnly);
    final saved = await provider.save(_entry());

    expect(saved, isTrue);
    expect(provider.cloudEnabled, isFalse);
    expect(provider.entries, hasLength(1));
    expect(repository.lastCloudEnabled, isFalse);
  });

  test(
    'cloud save failure preserves the local entry and marks sync pending',
    () async {
      final repository = _FakeSleepRepository(failCloudSave: true);
      final provider = SleepProvider(repository);
      await provider.load('user_1');
      await provider.chooseStorage('user_1', SleepConsentChoice.cloud);

      expect(await provider.save(_entry()), isTrue);
      expect(provider.entries, hasLength(1));
      expect(provider.syncState, SleepSyncState.pending);
      expect(provider.errorMessage, contains('Saved on this device'));
    },
  );

  test('revocation retains entries while disabling cloud', () async {
    final repository = _FakeSleepRepository();
    final provider = SleepProvider(repository);
    await provider.load('user_1');
    await provider.chooseStorage('user_1', SleepConsentChoice.cloud);
    await provider.save(_entry());

    expect(await provider.revokeCloud('user_1'), isTrue);
    expect(provider.cloudEnabled, isFalse);
    expect(provider.entries, hasLength(1));
  });
}

class _FakeSleepRepository extends SleepRepository {
  _FakeSleepRepository({this.failCloudSave = false});
  final bool failCloudSave;
  final List<SleepEntry> stored = [];
  SleepConsent? consent;
  bool? lastCloudEnabled;

  @override
  Future<SleepLoadResult> load(String userId) async => SleepLoadResult(
    entries: List.of(stored),
    consent: consent,
    pendingSync: false,
  );

  @override
  Future<void> setConsent(String userId, SleepConsentChoice choice) async {
    consent = SleepConsent(
      choice: choice,
      version: SleepConsent.currentVersion,
      decidedAt: DateTime.now(),
    );
  }

  @override
  Future<List<SleepEntry>> save(
    SleepEntry entry, {
    required bool cloudEnabled,
  }) async {
    lastCloudEnabled = cloudEnabled;
    stored.removeWhere((item) => item.wakeDateKey == entry.wakeDateKey);
    stored.add(entry);
    if (failCloudSave && cloudEnabled) throw StateError('offline');
    return List.of(stored);
  }

  @override
  Future<void> revokeCloud(String userId) async {
    consent = SleepConsent(
      choice: SleepConsentChoice.localOnly,
      version: SleepConsent.currentVersion,
      decidedAt: DateTime.now(),
    );
  }
}

SleepEntry _entry() {
  final wake = SleepCalculator.manilaDate(DateTime.now());
  return SleepEntry(
    id: SleepEntry.documentId('user_1', wake),
    userId: 'user_1',
    wakeDateKey: SleepEntry.wakeKey(wake),
    attemptedSleepAt: wake.subtract(const Duration(hours: 8)),
    sleepOnsetAt: wake.subtract(const Duration(hours: 7, minutes: 30)),
    finalWakeAt: wake,
    outOfBedAt: wake.add(const Duration(minutes: 15)),
    awakeningCount: 0,
    awakeMinutes: 0,
    napCount: 0,
    napMinutes: 0,
    restfulness: 3,
    daytimeSleepiness: 3,
    perceivedQuality: 3,
    contributorTags: const {},
    concernTags: const {},
    createdAt: DateTime.now(),
    clientUpdatedAt: DateTime.now(),
  );
}
