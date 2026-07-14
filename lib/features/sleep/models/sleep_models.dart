import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_mapper.dart';

enum SleepConsentChoice { cloud, localOnly }

enum SleepSyncState { idle, syncing, pending, error }

class SleepConsent {
  const SleepConsent({
    required this.choice,
    required this.version,
    required this.decidedAt,
  });

  static const currentVersion = 'sleep-v1';
  final SleepConsentChoice choice;
  final String version;
  final DateTime decidedAt;

  bool get isCurrent => version == currentVersion;
  bool get cloudEnabled => choice == SleepConsentChoice.cloud;

  Map<String, dynamic> toJson() => {
    'choice': choice.name,
    'version': version,
    'decidedAt': decidedAt.toUtc().toIso8601String(),
  };

  factory SleepConsent.fromJson(Map<String, dynamic> json) => SleepConsent(
    choice: json['choice'] == SleepConsentChoice.cloud.name
        ? SleepConsentChoice.cloud
        : SleepConsentChoice.localOnly,
    version: json['version']?.toString() ?? '',
    decidedAt:
        DateTime.tryParse(json['decidedAt']?.toString() ?? '') ??
        DateTime(2000),
  );
}

class SleepTags {
  const SleepTags._();

  static const contributors = <String, String>{
    'late_caffeine': 'Caffeine later in the day',
    'alcohol': 'Alcohol',
    'nicotine': 'Nicotine',
    'naps': 'Naps',
    'exercise': 'Exercise',
    'late_screens': 'Screens near bedtime',
    'stress': 'Stress or worry',
    'environment': 'Sleep environment',
    'late_meal': 'Late meal',
    'schedule_change': 'Schedule change',
    'illness_pain': 'Illness or pain',
    'medication': 'Medication',
  };

  static const concerns = <String, String>{
    'breathing_pauses_gasping': 'Breathing pauses or gasping',
    'loud_snoring_tiredness': 'Loud snoring with tiredness',
    'dangerous_sleepiness': 'Dangerous daytime sleepiness',
    'persistent_problems': 'Persistent sleep problems',
    'worsening_symptoms': 'Worsening symptoms',
  };
}

class SleepEntry {
  const SleepEntry({
    required this.id,
    required this.userId,
    required this.wakeDateKey,
    required this.attemptedSleepAt,
    required this.sleepOnsetAt,
    required this.finalWakeAt,
    required this.outOfBedAt,
    required this.awakeningCount,
    required this.awakeMinutes,
    required this.napCount,
    required this.napMinutes,
    required this.restfulness,
    required this.daytimeSleepiness,
    required this.perceivedQuality,
    required this.contributorTags,
    required this.concernTags,
    required this.createdAt,
    required this.clientUpdatedAt,
  });

  static const timezone = 'Asia/Manila';
  final String id;
  final String userId;
  final String wakeDateKey;
  final DateTime attemptedSleepAt;
  final DateTime sleepOnsetAt;
  final DateTime finalWakeAt;
  final DateTime outOfBedAt;
  final int awakeningCount;
  final int awakeMinutes;
  final int napCount;
  final int napMinutes;
  final int restfulness;
  final int daytimeSleepiness;
  final int perceivedQuality;
  final Set<String> contributorTags;
  final Set<String> concernTags;
  final DateTime createdAt;
  final DateTime clientUpdatedAt;

  static DateTime manilaNow([DateTime? now]) {
    final shifted = (now ?? DateTime.now()).toUtc().add(
      const Duration(hours: 8),
    );
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  static String wakeKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  static String documentId(String userId, DateTime wakeDate) =>
      'sleep_${userId}_${wakeKey(wakeDate)}';

  static DateTime manilaWallToInstant(DateTime wallClock) => DateTime.utc(
    wallClock.year,
    wallClock.month,
    wallClock.day,
    wallClock.hour,
    wallClock.minute,
    wallClock.second,
    wallClock.millisecond,
    wallClock.microsecond,
  ).subtract(const Duration(hours: 8));

  static DateTime dateFromWakeKey(String value) {
    if (!RegExp(r'^\d{8}$').hasMatch(value)) {
      throw const FormatException('Invalid wake date key.');
    }
    return DateTime(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(4, 6)),
      int.parse(value.substring(6, 8)),
    );
  }

  SleepEntry copyWith({
    DateTime? clientUpdatedAt,
    Set<String>? contributorTags,
    Set<String>? concernTags,
  }) => SleepEntry(
    id: id,
    userId: userId,
    wakeDateKey: wakeDateKey,
    attemptedSleepAt: attemptedSleepAt,
    sleepOnsetAt: sleepOnsetAt,
    finalWakeAt: finalWakeAt,
    outOfBedAt: outOfBedAt,
    awakeningCount: awakeningCount,
    awakeMinutes: awakeMinutes,
    napCount: napCount,
    napMinutes: napMinutes,
    restfulness: restfulness,
    daytimeSleepiness: daytimeSleepiness,
    perceivedQuality: perceivedQuality,
    contributorTags: contributorTags ?? this.contributorTags,
    concernTags: concernTags ?? this.concernTags,
    createdAt: createdAt,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'wakeDateKey': wakeDateKey,
    'timezone': timezone,
    'attemptedSleepAt': attemptedSleepAt.toIso8601String(),
    'sleepOnsetAt': sleepOnsetAt.toIso8601String(),
    'finalWakeAt': finalWakeAt.toIso8601String(),
    'outOfBedAt': outOfBedAt.toIso8601String(),
    'awakeningCount': awakeningCount,
    'awakeMinutes': awakeMinutes,
    'napCount': napCount,
    'napMinutes': napMinutes,
    'restfulness': restfulness,
    'daytimeSleepiness': daytimeSleepiness,
    'perceivedQuality': perceivedQuality,
    'contributorTags': contributorTags.toList()..sort(),
    'concernTags': concernTags.toList()..sort(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'clientUpdatedAt': clientUpdatedAt.toUtc().toIso8601String(),
  };

  factory SleepEntry.fromJson(Map<String, dynamic> json, {String? id}) {
    DateTime requiredInstant(String key) {
      final value = dateTimeFromFirestore(json[key]);
      if (value == null) throw FormatException('Missing $key.');
      return value;
    }

    DateTime requiredWallClock(String key) {
      final raw = json[key];
      if (raw is Timestamp) return manilaNow(raw.toDate());
      final value = DateTime.tryParse(raw?.toString() ?? '');
      if (value == null) throw FormatException('Missing $key.');
      return value;
    }

    Set<String> strings(String key) => ((json[key] as List?) ?? const [])
        .map((value) => value.toString())
        .toSet();

    return SleepEntry(
      id: id ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      wakeDateKey: json['wakeDateKey']?.toString() ?? '',
      attemptedSleepAt: requiredWallClock('attemptedSleepAt'),
      sleepOnsetAt: requiredWallClock('sleepOnsetAt'),
      finalWakeAt: requiredWallClock('finalWakeAt'),
      outOfBedAt: requiredWallClock('outOfBedAt'),
      awakeningCount: intFromFirestore(json['awakeningCount']),
      awakeMinutes: intFromFirestore(json['awakeMinutes']),
      napCount: intFromFirestore(json['napCount']),
      napMinutes: intFromFirestore(json['napMinutes']),
      restfulness: intFromFirestore(json['restfulness']),
      daytimeSleepiness: intFromFirestore(json['daytimeSleepiness']),
      perceivedQuality: intFromFirestore(json['perceivedQuality']),
      contributorTags: strings('contributorTags'),
      concernTags: strings('concernTags'),
      createdAt: requiredInstant('createdAt'),
      clientUpdatedAt: requiredInstant('clientUpdatedAt'),
    );
  }
}

class SleepMeasures {
  const SleepMeasures({
    required this.timeInBedMinutes,
    required this.sleepLatencyMinutes,
    required this.totalSleepMinutes,
    required this.nightWakefulnessMinutes,
    required this.awakeBeforeRisingMinutes,
    required this.efficiency,
  });

  final int timeInBedMinutes;
  final int sleepLatencyMinutes;
  final int totalSleepMinutes;
  final int nightWakefulnessMinutes;
  final int awakeBeforeRisingMinutes;
  final double efficiency;
}

class SleepWindowSummary {
  const SleepWindowSummary({
    required this.windowDays,
    required this.entryCount,
    this.averageSleepMinutes,
    this.averageWakefulnessMinutes,
    this.averageEfficiency,
    this.averageRestfulness,
    this.averageSleepiness,
    this.averageQuality,
    this.averageScheduleShiftMinutes,
  });

  final int windowDays;
  final int entryCount;
  final double? averageSleepMinutes;
  final double? averageWakefulnessMinutes;
  final double? averageEfficiency;
  final double? averageRestfulness;
  final double? averageSleepiness;
  final double? averageQuality;
  final double? averageScheduleShiftMinutes;
}

class SleepContributorObservation {
  const SleepContributorObservation({
    required this.tag,
    required this.message,
    required this.strength,
  });

  final String tag;
  final String message;
  final double strength;
}

class SleepCalculator {
  const SleepCalculator._();

  static SleepMeasures measures(SleepEntry entry) {
    final timeInBed = entry.outOfBedAt
        .difference(entry.attemptedSleepAt)
        .inMinutes;
    final latency = entry.sleepOnsetAt
        .difference(entry.attemptedSleepAt)
        .inMinutes;
    final sleepWindow = entry.finalWakeAt
        .difference(entry.sleepOnsetAt)
        .inMinutes;
    final totalSleep = sleepWindow - entry.awakeMinutes;
    final beforeRising = entry.outOfBedAt
        .difference(entry.finalWakeAt)
        .inMinutes;
    final efficiency = timeInBed <= 0
        ? 0.0
        : (totalSleep / timeInBed * 100).clamp(0, 100).toDouble();
    return SleepMeasures(
      timeInBedMinutes: timeInBed,
      sleepLatencyMinutes: latency,
      totalSleepMinutes: totalSleep,
      nightWakefulnessMinutes: entry.awakeMinutes,
      awakeBeforeRisingMinutes: beforeRising,
      efficiency: efficiency,
    );
  }

  static String? validate(SleepEntry entry, {DateTime? now}) {
    final today = manilaDate(now ?? DateTime.now());
    if (dateOnly(
      SleepEntry.dateFromWakeKey(entry.wakeDateKey),
    ).isAfter(today)) {
      return 'Wake date cannot be in the future.';
    }
    if (entry.id !=
        SleepEntry.documentId(
          entry.userId,
          SleepEntry.dateFromWakeKey(entry.wakeDateKey),
        )) {
      return 'The sleep entry ID does not match its wake date.';
    }
    if (entry.awakeningCount < 0 || entry.awakeningCount > 50) {
      return 'Enter an awakening count from 0 to 50.';
    }
    if ((entry.awakeningCount == 0 && entry.awakeMinutes != 0) ||
        (entry.awakeningCount > 0 && entry.awakeMinutes <= 0)) {
      return 'Add awake minutes when awakenings are recorded.';
    }
    if (entry.napCount < 0 ||
        entry.napCount > 10 ||
        entry.napMinutes < 0 ||
        entry.napMinutes > 720) {
      return 'Check the nap count and duration.';
    }
    if (![
      entry.restfulness,
      entry.daytimeSleepiness,
      entry.perceivedQuality,
    ].every((rating) => rating >= 1 && rating <= 5)) {
      return 'Complete all ratings from 1 to 5.';
    }
    if (!entry.contributorTags.every(SleepTags.contributors.containsKey) ||
        !entry.concernTags.every(SleepTags.concerns.containsKey)) {
      return 'One or more selected tags are not supported.';
    }
    if (entry.sleepOnsetAt.isBefore(entry.attemptedSleepAt) ||
        entry.finalWakeAt.isBefore(entry.sleepOnsetAt) ||
        entry.outOfBedAt.isBefore(entry.finalWakeAt)) {
      return 'Sleep times must follow their chronological order.';
    }
    final measures = SleepCalculator.measures(entry);
    if (measures.timeInBedMinutes <= 0 || measures.timeInBedMinutes > 1440) {
      return 'Time in bed must be more than 0 and no more than 24 hours.';
    }
    if (measures.totalSleepMinutes < 0) {
      return 'Awake minutes cannot exceed the sleep window.';
    }
    return null;
  }

  static DateTime manilaDate(DateTime instant) {
    final value = SleepEntry.manilaNow(instant);
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static List<DateTime>? composeTimes({
    required DateTime wakeDate,
    required int attemptedMinutes,
    required int onsetMinutes,
    required int finalWakeMinutes,
    required int outOfBedMinutes,
  }) {
    final day = dateOnly(wakeDate);
    DateTime at(int offset, int minutes) =>
        day.add(Duration(days: offset, minutes: minutes));
    final finalWake = at(0, finalWakeMinutes);
    final candidates = <List<DateTime>>[];
    for (final attemptedDay in const [-1, 0]) {
      for (final onsetDay in const [-1, 0]) {
        for (final outDay in const [0, 1]) {
          final values = [
            at(attemptedDay, attemptedMinutes),
            at(onsetDay, onsetMinutes),
            finalWake,
            at(outDay, outOfBedMinutes),
          ];
          if (!values[1].isBefore(values[0]) &&
              !values[2].isBefore(values[1]) &&
              !values[3].isBefore(values[2]) &&
              values[3].difference(values[0]) <= const Duration(hours: 24) &&
              values[3].isAfter(values[0])) {
            candidates.add(values);
          }
        }
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) => a[3].difference(a[0]).compareTo(b[3].difference(b[0])),
    );
    return candidates.first;
  }

  static SleepWindowSummary summarize(
    List<SleepEntry> entries, {
    required int days,
    DateTime? now,
  }) {
    final end = manilaDate(now ?? DateTime.now());
    final start = end.subtract(Duration(days: days - 1));
    final sample = entries.where((entry) {
      final date = SleepEntry.dateFromWakeKey(entry.wakeDateKey);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList()..sort((a, b) => a.wakeDateKey.compareTo(b.wakeDateKey));
    if (sample.isEmpty) {
      return SleepWindowSummary(windowDays: days, entryCount: 0);
    }
    final metrics = sample.map(measures).toList();
    double avg(Iterable<num> values) =>
        values.fold<double>(0, (total, value) => total + value) / values.length;
    double? schedule;
    if (sample.length >= 3) {
      final shifts = <int>[];
      for (var i = 1; i < sample.length; i++) {
        final onsetShift = _clockDifference(
          sample[i].sleepOnsetAt,
          sample[i - 1].sleepOnsetAt,
        );
        final wakeShift = _clockDifference(
          sample[i].finalWakeAt,
          sample[i - 1].finalWakeAt,
        );
        shifts.add(((onsetShift + wakeShift) / 2).round());
      }
      schedule = avg(shifts);
    }
    return SleepWindowSummary(
      windowDays: days,
      entryCount: sample.length,
      averageSleepMinutes: avg(metrics.map((value) => value.totalSleepMinutes)),
      averageWakefulnessMinutes: avg(
        metrics.map((value) => value.nightWakefulnessMinutes),
      ),
      averageEfficiency: avg(metrics.map((value) => value.efficiency)),
      averageRestfulness: avg(sample.map((value) => value.restfulness)),
      averageSleepiness: avg(sample.map((value) => value.daytimeSleepiness)),
      averageQuality: avg(sample.map((value) => value.perceivedQuality)),
      averageScheduleShiftMinutes: schedule,
    );
  }

  static List<SleepContributorObservation> observations(
    List<SleepEntry> entries, {
    DateTime? now,
  }) {
    final end = manilaDate(now ?? DateTime.now());
    final start = end.subtract(const Duration(days: 13));
    final sample = entries.where((entry) {
      final date = SleepEntry.dateFromWakeKey(entry.wakeDateKey);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
    final output = <SleepContributorObservation>[];
    for (final tag in SleepTags.contributors.keys) {
      final tagged = sample
          .where((entry) => entry.contributorTags.contains(tag))
          .toList();
      final other = sample
          .where((entry) => !entry.contributorTags.contains(tag))
          .toList();
      if (tagged.length < 3 || other.length < 3) continue;
      double avgQuality(List<SleepEntry> values) =>
          values.fold<double>(
            0,
            (total, entry) => total + entry.perceivedQuality,
          ) /
          values.length;
      double avgRestfulness(List<SleepEntry> values) =>
          values.fold<double>(0, (total, entry) => total + entry.restfulness) /
          values.length;
      double avgSleepiness(List<SleepEntry> values) =>
          values.fold<double>(
            0,
            (total, entry) => total + entry.daytimeSleepiness,
          ) /
          values.length;
      double avgOnset(List<SleepEntry> values) =>
          values.fold<double>(
            0,
            (total, entry) => total + _bedtimeMinute(entry.sleepOnsetAt),
          ) /
          values.length;
      double avgMinutes(List<SleepEntry> values) =>
          values
              .map(measures)
              .fold<double>(
                0,
                (total, value) => total + value.totalSleepMinutes,
              ) /
          values.length;
      double avgEfficiency(List<SleepEntry> values) =>
          values
              .map(measures)
              .fold<double>(0, (total, value) => total + value.efficiency) /
          values.length;
      final qualityDiff = avgQuality(tagged) - avgQuality(other);
      final restfulnessDiff = avgRestfulness(tagged) - avgRestfulness(other);
      final sleepinessDiff = avgSleepiness(tagged) - avgSleepiness(other);
      final onsetDiff = avgOnset(tagged) - avgOnset(other);
      final minutesDiff = avgMinutes(tagged) - avgMinutes(other);
      final efficiencyDiff = avgEfficiency(tagged) - avgEfficiency(other);
      String? detail;
      double strength = 0;
      if (qualityDiff.abs() >= .5) {
        detail =
            'quality was ${qualityDiff > 0 ? 'higher' : 'lower'} by ${qualityDiff.abs().toStringAsFixed(1)} points';
        strength = qualityDiff.abs() / .5;
      }
      if (restfulnessDiff.abs() >= .5 &&
          restfulnessDiff.abs() / .5 > strength) {
        detail =
            'restfulness was ${restfulnessDiff > 0 ? 'higher' : 'lower'} by ${restfulnessDiff.abs().toStringAsFixed(1)} points';
        strength = restfulnessDiff.abs() / .5;
      }
      if (sleepinessDiff.abs() >= .5 && sleepinessDiff.abs() / .5 > strength) {
        detail =
            'daytime sleepiness was ${sleepinessDiff > 0 ? 'higher' : 'lower'} by ${sleepinessDiff.abs().toStringAsFixed(1)} points';
        strength = sleepinessDiff.abs() / .5;
      }
      if (onsetDiff.abs() >= 30 && onsetDiff.abs() / 30 > strength) {
        detail =
            'estimated sleep onset was about ${onsetDiff.abs().round()} minutes ${onsetDiff > 0 ? 'later' : 'earlier'}';
        strength = onsetDiff.abs() / 30;
      }
      if (minutesDiff.abs() >= 30 && minutesDiff.abs() / 30 > strength) {
        detail =
            'estimated sleep was ${minutesDiff > 0 ? 'longer' : 'shorter'} by about ${minutesDiff.abs().round()} minutes';
        strength = minutesDiff.abs() / 30;
      }
      if (efficiencyDiff.abs() >= 5 && efficiencyDiff.abs() / 5 > strength) {
        detail =
            'estimated efficiency was ${efficiencyDiff > 0 ? 'higher' : 'lower'} by ${efficiencyDiff.abs().toStringAsFixed(0)} points';
        strength = efficiencyDiff.abs() / 5;
      }
      if (detail != null) {
        output.add(
          SleepContributorObservation(
            tag: tag,
            message:
                'On nights when you recorded ${SleepTags.contributors[tag]!.toLowerCase()}, $detail. This is an observation, not proof of a cause.',
            strength: strength,
          ),
        );
      }
    }
    output.sort((a, b) => b.strength.compareTo(a.strength));
    return output.take(3).toList(growable: false);
  }

  static double? latestSevenAverage(List<SleepEntry> entries) {
    if (entries.isEmpty) return null;
    final sorted = [...entries]
      ..sort((a, b) => b.wakeDateKey.compareTo(a.wakeDateKey));
    final sample = sorted.take(7).toList();
    return sample.fold<double>(
          0,
          (total, entry) => total + entry.perceivedQuality,
        ) /
        sample.length;
  }

  static int _clockDifference(DateTime a, DateTime b) {
    final difference = ((a.hour * 60 + a.minute) - (b.hour * 60 + b.minute))
        .abs();
    return difference > 720 ? 1440 - difference : difference;
  }

  static int _bedtimeMinute(DateTime value) {
    final minute = value.hour * 60 + value.minute;
    return minute < 12 * 60 ? minute + 1440 : minute;
  }
}
