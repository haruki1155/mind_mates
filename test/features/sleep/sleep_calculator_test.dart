import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/sleep/models/sleep_models.dart';

void main() {
  group('SleepCalculator timestamp composition', () {
    test('anchors an overnight sleep to the Manila wake date', () {
      final values = SleepCalculator.composeTimes(
        wakeDate: DateTime(2026, 7, 14),
        attemptedMinutes: 23 * 60,
        onsetMinutes: 23 * 60 + 30,
        finalWakeMinutes: 7 * 60,
        outOfBedMinutes: 7 * 60 + 15,
      );

      expect(values, isNotNull);
      expect(values![0], DateTime(2026, 7, 13, 23));
      expect(values[1], DateTime(2026, 7, 13, 23, 30));
      expect(values[2], DateTime(2026, 7, 14, 7));
      expect(values[3], DateTime(2026, 7, 14, 7, 15));
    });

    test('supports sleep beginning after midnight', () {
      final values = SleepCalculator.composeTimes(
        wakeDate: DateTime(2026, 7, 14),
        attemptedMinutes: 60,
        onsetMinutes: 90,
        finalWakeMinutes: 8 * 60,
        outOfBedMinutes: 8 * 60 + 10,
      );
      expect(values![0], DateTime(2026, 7, 14, 1));
      expect(values[1], DateTime(2026, 7, 14, 1, 30));
    });

    test('rejects a chronology that exceeds 24 hours', () {
      final values = SleepCalculator.composeTimes(
        wakeDate: DateTime(2026, 7, 14),
        attemptedMinutes: 8 * 60,
        onsetMinutes: 7 * 60,
        finalWakeMinutes: 6 * 60,
        outOfBedMinutes: 5 * 60,
      );
      expect(values, isNull);
    });
  });

  test('calculates all sleep measures without persisting them', () {
    final entry = _entry(
      attempted: DateTime(2026, 7, 13, 22, 30),
      onset: DateTime(2026, 7, 13, 23),
      wake: DateTime(2026, 7, 14, 7),
      out: DateTime(2026, 7, 14, 7, 30),
      awakeMinutes: 30,
      awakenings: 2,
    );
    final result = SleepCalculator.measures(entry);
    expect(result.timeInBedMinutes, 540);
    expect(result.sleepLatencyMinutes, 30);
    expect(result.totalSleepMinutes, 450);
    expect(result.nightWakefulnessMinutes, 30);
    expect(result.awakeBeforeRisingMinutes, 30);
    expect(result.efficiency, closeTo(83.33, .01));
    expect(SleepCalculator.validate(entry, now: DateTime(2026, 7, 14)), isNull);
  });

  test('Firestore timestamps round-trip as Manila wall-clock times', () {
    final source = _entry();
    final json = source.toJson()
      ..['attemptedSleepAt'] = Timestamp.fromDate(
        SleepEntry.manilaWallToInstant(source.attemptedSleepAt),
      )
      ..['sleepOnsetAt'] = Timestamp.fromDate(
        SleepEntry.manilaWallToInstant(source.sleepOnsetAt),
      )
      ..['finalWakeAt'] = Timestamp.fromDate(
        SleepEntry.manilaWallToInstant(source.finalWakeAt),
      )
      ..['outOfBedAt'] = Timestamp.fromDate(
        SleepEntry.manilaWallToInstant(source.outOfBedAt),
      );

    final restored = SleepEntry.fromJson(json);
    expect(restored.attemptedSleepAt, source.attemptedSleepAt);
    expect(restored.finalWakeAt, source.finalWakeAt);
  });

  test('requires awake minutes when awakenings are recorded', () {
    final entry = _entry(awakenings: 1, awakeMinutes: 0);
    expect(
      SleepCalculator.validate(entry, now: DateTime(2026, 7, 14)),
      contains('awake minutes'),
    );
  });

  test('summary with fewer than three entries withholds regularity', () {
    final summary = SleepCalculator.summarize(
      [_entry(), _entry(day: 13)],
      days: 7,
      now: DateTime.utc(2026, 7, 14),
    );
    expect(summary.entryCount, 2);
    expect(summary.averageQuality, 3);
    expect(summary.averageScheduleShiftMinutes, isNull);
  });

  test(
    'summary keeps coverage separate from missing days and averages optional daytime ratings',
    () {
      final summary = SleepCalculator.summarize(
        [_entry(day: 14, energy: 4, focus: 2), _entry(day: 12, energy: 2)],
        days: 7,
        now: DateTime.utc(2026, 7, 14),
      );
      expect(summary.entryCount, 2);
      expect(summary.windowDays, 7);
      expect(summary.averageEnergy, 3);
      expect(summary.averageFocus, 2);
      expect(summary.typicalBedtimeMinutes, isNull);
    },
  );

  test('regularity uses noon-anchored bedtime minutes across midnight', () {
    final summary = SleepCalculator.summarize(
      [
        _entry(day: 14, attempted: DateTime(2026, 7, 13, 23, 45)),
        _entry(day: 13, attempted: DateTime(2026, 7, 13, 0, 15)),
        _entry(day: 12, attempted: DateTime(2026, 7, 11, 23, 55)),
      ],
      days: 7,
      now: DateTime.utc(2026, 7, 14),
    );
    expect(summary.typicalBedtimeMinutes, greaterThan(1400));
    expect(summary.bedtimeVariationMinutes, lessThan(30));
  });

  test('baseline change needs coverage in both comparison windows', () {
    final entries = [
      for (var day = 14; day >= 12; day--) _entry(day: day),
      for (var day = 7; day >= 5; day--)
        _entry(
          day: day,
          attempted: DateTime(2026, 7, day - 1, 23),
          onset: DateTime(2026, 7, day - 1, 23, 30),
          wake: DateTime(2026, 7, day, 5),
          out: DateTime(2026, 7, day, 5, 15),
        ),
    ];
    final summary = SleepCalculator.summarize(
      entries,
      days: 7,
      now: DateTime.utc(2026, 7, 14),
    );
    expect(summary.comparisonSleepMinutes, closeTo(120, .1));
  });

  test('profile average uses the latest seven available entries', () {
    final entries = List.generate(
      9,
      (index) => _entry(day: 14 - index, quality: index < 7 ? 5 : 1),
    );
    expect(SleepCalculator.latestSevenAverage(entries), 5);
  });

  test('contributor observations require three tagged and untagged nights', () {
    final entries = <SleepEntry>[
      for (var index = 0; index < 3; index++)
        _entry(day: 14 - index, quality: 2, tags: {'stress'}),
      for (var index = 3; index < 6; index++)
        _entry(day: 14 - index, quality: 4),
    ];
    final result = SleepCalculator.observations(
      entries,
      now: DateTime.utc(2026, 7, 14),
    );
    expect(result, hasLength(1));
    expect(
      result.single.message,
      contains('does not show that the tag caused'),
    );
  });
}

SleepEntry _entry({
  int day = 14,
  int quality = 3,
  int awakenings = 0,
  int awakeMinutes = 0,
  Set<String> tags = const {},
  int? energy,
  int? focus,
  DateTime? attempted,
  DateTime? onset,
  DateTime? wake,
  DateTime? out,
}) {
  final wakeDate = DateTime(2026, 7, day);
  return SleepEntry(
    id: SleepEntry.documentId('user_1', wakeDate),
    userId: 'user_1',
    wakeDateKey: SleepEntry.wakeKey(wakeDate),
    attemptedSleepAt: attempted ?? wakeDate.subtract(const Duration(hours: 8)),
    sleepOnsetAt:
        onset ?? wakeDate.subtract(const Duration(hours: 7, minutes: 30)),
    finalWakeAt: wake ?? wakeDate,
    outOfBedAt: out ?? wakeDate.add(const Duration(minutes: 15)),
    awakeningCount: awakenings,
    awakeMinutes: awakeMinutes,
    napCount: 0,
    napMinutes: 0,
    restfulness: 3,
    daytimeSleepiness: 3,
    perceivedQuality: quality,
    contributorTags: tags,
    concernTags: const {},
    createdAt: wakeDate,
    clientUpdatedAt: wakeDate,
    energy: energy,
    focus: focus,
  );
}
