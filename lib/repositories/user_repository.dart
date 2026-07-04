import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../models/user_model.dart';
import '../services/firebase/firestore_service.dart';

enum UserActivityType {
  quickAssessment,
  fullAssessment,
  mindAidMessage,
  moodCheckIn,
  journalEntry,
  breathingSession,
  secretChatPost,
  secretChatComment,
  secretChatInteraction;

  String get storedValue => name;
}

class StreakUpdate {
  const StreakUpdate({
    required this.dayStreak,
    required this.longestStreak,
    required this.lastActivityDateKey,
    required this.activeDateKeys,
    required this.incremented,
    required this.wasReset,
  });

  final int dayStreak;
  final int longestStreak;
  final String lastActivityDateKey;
  final List<String> activeDateKeys;
  final bool incremented;
  final bool wasReset;
}

class StreakCalculator {
  const StreakCalculator._();

  static StreakUpdate calculate({
    required DateTime occurredAt,
    String? previousDateKey,
    int currentStreak = 0,
    int longestStreak = 0,
    List<String> activeDateKeys = const [],
  }) {
    final todayKey = dateKey(occurredAt);
    final localOccurredAt = occurredAt.toLocal();
    final previous = parseDateKey(previousDateKey);
    final today = DateTime(
      localOccurredAt.year,
      localOccurredAt.month,
      localOccurredAt.day,
    );
    var nextStreak = currentStreak;
    var incremented = false;
    var wasReset = false;

    if (previousDateKey == todayKey) {
      nextStreak = currentStreak;
    } else if (previous != null &&
        today.difference(previous).inDays == 1 &&
        currentStreak > 0) {
      nextStreak = currentStreak + 1;
      incremented = true;
    } else {
      nextStreak = 1;
      incremented = currentStreak == 0;
      wasReset = currentStreak > 0 && previousDateKey != todayKey;
    }

    final nextActiveKeys = <String>{
      ...activeDateKeys.where((key) => key.trim().isNotEmpty),
      todayKey,
    }.toList()..sort();

    return StreakUpdate(
      dayStreak: nextStreak,
      longestStreak: nextStreak > longestStreak ? nextStreak : longestStreak,
      lastActivityDateKey: todayKey,
      activeDateKeys: nextActiveKeys.length > 60
          ? nextActiveKeys.sublist(nextActiveKeys.length - 60)
          : nextActiveKeys,
      incremented: incremented,
      wasReset: wasReset,
    );
  }

  static String dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static DateTime? parseDateKey(String? key) {
    if (key == null || key.trim().isEmpty) return null;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }
}

class UserRepository {
  UserRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<UserModel?> fetchUserProfile(String uid) async {
    final data = await _firestoreService.getDocument(
      FirestoreCollections.users,
      uid,
    );
    if (data == null) return null;
    return UserModel.fromJson(data, id: uid);
  }

  Stream<UserModel?> watchUserProfile(String uid) {
    return _firestoreService
        .watchDocument(FirestoreCollections.users, uid)
        .map((data) => data == null ? null : UserModel.fromJson(data, id: uid));
  }

  Future<void> updateUserProfile(String uid, UserModel user) {
    return _firestoreService.updateDocument(
      FirestoreCollections.users,
      uid,
      user.toProfileUpdateJson(),
    );
  }

  Future<UserModel?> recordActivity(
    String uid,
    UserActivityType type, {
    DateTime? occurredAt,
  }) {
    final activityAt = occurredAt ?? DateTime.now();
    final todayKey = StreakCalculator.dateKey(activityAt);
    final ref = _firestoreService.firestore
        .collection(FirestoreCollections.users)
        .doc(uid);
    final activityRef = _firestoreService.firestore
        .collection(FirestoreCollections.userActivities)
        .doc();

    return _firestoreService.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      final update = StreakCalculator.calculate(
        occurredAt: activityAt,
        previousDateKey:
            data?['lastActivityDateKey']?.toString() ??
            data?['lastCheckInDate']?.toString(),
        currentStreak: _intOrZero(data?['dayStreak']),
        longestStreak: _intOrZero(data?['longestStreak']),
        activeDateKeys: _stringList(data?['activeDateKeys']),
      );

      transaction.set(activityRef, {
        'userId': uid,
        'type': type.storedValue,
        'dateKey': todayKey,
        'occurredAt': Timestamp.fromDate(activityAt),
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(ref, {
        'lastActiveAt': FieldValue.serverTimestamp(),
        'lastActivityDateKey': update.lastActivityDateKey,
        'activeDateKeys': update.activeDateKeys,
        'streakUpdatedAt': FieldValue.serverTimestamp(),
        'dayStreak': update.dayStreak,
        'longestStreak': update.longestStreak,
      }, SetOptions(merge: true));

      return UserModel.fromJson({
        ...?data,
        'id': uid,
        'dayStreak': update.dayStreak,
        'longestStreak': update.longestStreak,
        'lastActivityDateKey': update.lastActivityDateKey,
        'lastActiveAt': activityAt,
        'activeDateKeys': update.activeDateKeys,
      }, id: uid);
    });
  }

  Future<UserModel?> markUserActivity(String uid) {
    return recordActivity(uid, UserActivityType.quickAssessment);
  }

  static int _intOrZero(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
  }
}
