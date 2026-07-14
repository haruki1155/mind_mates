import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/sleep/models/sleep_models.dart';
import 'package:mind_mates/features/sleep/services/sleep_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('entries and consent are isolated by account', () async {
    final store = SleepLocalStore();
    await store.writeEntry(_entry('user_a'));
    await store.writeConsent(
      'user_a',
      SleepConsent(
        choice: SleepConsentChoice.localOnly,
        version: SleepConsent.currentVersion,
        decidedAt: DateTime.utc(2026, 7, 14),
      ),
    );

    expect(await store.readEntries('user_a'), hasLength(1));
    expect(await store.readEntries('user_b'), isEmpty);
    expect(
      (await store.readConsent('user_a'))!.choice,
      SleepConsentChoice.localOnly,
    );
    expect(await store.readConsent('user_b'), isNull);
  });

  test(
    'edit, delete, pending sync, and clear update the encrypted index',
    () async {
      final store = SleepLocalStore();
      final original = _entry('user_a');
      await store.writeEntry(original);
      await store.writeEntry(
        original.copyWith(clientUpdatedAt: DateTime.utc(2026, 7, 15)),
      );
      await store.writePending('user_a', {original.wakeDateKey});

      expect(await store.readEntries('user_a'), hasLength(1));
      expect(await store.readPending('user_a'), {original.wakeDateKey});

      await store.deleteEntry('user_a', original.wakeDateKey);
      expect(await store.readEntries('user_a'), isEmpty);

      await store.writeEntry(original);
      await store.clearEntries('user_a');
      expect(await store.readEntries('user_a'), isEmpty);
      expect(await store.readPending('user_a'), isEmpty);
    },
  );
}

SleepEntry _entry(String userId) {
  final wake = DateTime(2026, 7, 14);
  return SleepEntry(
    id: SleepEntry.documentId(userId, wake),
    userId: userId,
    wakeDateKey: SleepEntry.wakeKey(wake),
    attemptedSleepAt: DateTime(2026, 7, 13, 23),
    sleepOnsetAt: DateTime(2026, 7, 13, 23, 30),
    finalWakeAt: DateTime(2026, 7, 14, 7),
    outOfBedAt: DateTime(2026, 7, 14, 7, 15),
    awakeningCount: 0,
    awakeMinutes: 0,
    napCount: 0,
    napMinutes: 0,
    restfulness: 4,
    daytimeSleepiness: 2,
    perceivedQuality: 4,
    contributorTags: const {},
    concernTags: const {},
    createdAt: DateTime.utc(2026, 7, 14),
    clientUpdatedAt: DateTime.utc(2026, 7, 14),
  );
}
