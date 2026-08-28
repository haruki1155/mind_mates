import 'package:cloud_functions/cloud_functions.dart';

import '../database/firestore_collections.dart';
import '../models/mood_model.dart';
import '../services/firebase/firestore_service.dart';

class MoodRepository {
  MoodRepository({
    FirestoreService? firestoreService,
    this._functions,
    DateTime Function()? nowProvider,
  }) : _firestoreService = firestoreService ?? FirestoreService(),
       _nowProvider = nowProvider ?? DateTime.now;

  final FirestoreService _firestoreService;
  final DateTime Function() _nowProvider;
  final FirebaseFunctions? _functions;

  FirebaseFunctions get _callables =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  static const timezone = 'Asia/Manila';

  static DateTime manilaWallClock(DateTime instant) {
    final shifted = instant.toUtc().add(const Duration(hours: 8));
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

  static String dateKeyFor(DateTime instant) {
    final date = manilaWallClock(instant);
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String dailyDocumentId(String userId, DateTime instant) {
    return 'daily_${userId}_${dateKeyFor(instant)}';
  }

  Future<MoodModel?> fetchTodayMood(String userId, {DateTime? now}) async {
    final instant = now ?? _nowProvider();
    final dateKey = dateKeyFor(instant);
    final documentId = dailyDocumentId(userId, instant);
    final deterministic = await _firestoreService.getDocument(
      FirestoreCollections.moods,
      documentId,
    );
    if (deterministic != null) {
      return MoodModel.fromJson(deterministic, id: documentId);
    }

    final recent = await fetchRecentMoods(userId, limit: 50);
    for (final mood in recent) {
      final moodDateKey = (mood.dateKey ?? '').trim().isNotEmpty
          ? mood.dateKey
          : dateKeyFor(mood.createdAt);
      if (moodDateKey == dateKey) return mood;
    }
    return null;
  }

  Future<DailyMoodSaveResult> saveDailyMood({
    required String userId,
    required int level,
    String? label,
    String? note,
    DateTime? now,
  }) async {
    final moodKey = _moodKeyFor(level: level, label: label);
    final result = await _callables.httpsCallable('logDailyMood').call<Object?>(
      {'moodKey': moodKey, if (note?.isNotEmpty ?? false) 'note': note},
    );
    final data = result.data;
    if (data is! Map) throw const FormatException('Mood response was invalid.');
    final mood = data['mood'];
    if (mood is! Map) throw const FormatException('Mood response was invalid.');
    final createdAtMillis = mood['createdAtMillis'];
    if (createdAtMillis is! num) {
      throw const FormatException('Mood response was invalid.');
    }
    return DailyMoodSaveResult(
      created: data['created'] == true,
      dayStreak: _intOrZero(data['dayStreak']),
      longestStreak: _intOrZero(data['longestStreak']),
      mood: MoodModel(
        id: mood['id']?.toString() ?? '',
        userId: userId,
        moodKey: mood['moodKey']?.toString(),
        level: _intOrZero(mood['level']),
        label: mood['label']?.toString(),
        note: mood['note']?.toString(),
        dateKey: mood['dateKey']?.toString(),
        timezone: timezone,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis.toInt()),
      ),
    );
  }

  Future<List<MoodModel>> fetchRecentMoods(String userId, {int limit = 14}) {
    return _firestoreService
        .getDocuments(
          FirestoreCollections.moods,
          whereEquals: {'userId': userId},
          orderBy: 'createdAt',
          limit: limit,
        )
        .then(
          (docs) => docs
              .map((doc) => MoodModel.fromJson(doc, id: doc['id']?.toString()))
              .toList(growable: false),
        );
  }

  Stream<List<MoodModel>> watchRecentMoods(String userId, {int limit = 14}) {
    return _firestoreService
        .watchDocuments(
          FirestoreCollections.moods,
          whereEquals: {'userId': userId},
          orderBy: 'createdAt',
          limit: limit,
        )
        .map(
          (docs) => docs
              .map((doc) => MoodModel.fromJson(doc, id: doc['id']?.toString()))
              .toList(growable: false),
        );
  }

  Future<String> createMood({
    required String userId,
    required int level,
    String? label,
    String? note,
    DateTime? now,
  }) async {
    final result = await saveDailyMood(
      userId: userId,
      level: level,
      label: label,
      note: note,
      now: now ?? _nowProvider(),
    );
    return result.mood.id;
  }

  static int _intOrZero(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _moodKeyFor({required int level, String? label}) {
    final normalized = label?.trim().toLowerCase();
    const keys = {
      'great': 5,
      'okay': 4,
      'tired': 3,
      'stressed': 2,
      'sad': 1,
      'angry': 1,
      'excited': 5,
    };
    if (normalized != null && keys[normalized] == level) return normalized;
    throw ArgumentError('A valid mood key is required.');
  }
}

class DailyMoodSaveResult {
  const DailyMoodSaveResult({
    required this.mood,
    required this.created,
    this.dayStreak = 0,
    this.longestStreak = 0,
  });

  final MoodModel mood;
  final bool created;
  final int dayStreak;
  final int longestStreak;
}
