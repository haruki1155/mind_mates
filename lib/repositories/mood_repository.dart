import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../models/mood_model.dart';
import '../services/firebase/firestore_service.dart';
import 'user_repository.dart';

class MoodRepository {
  MoodRepository({
    FirestoreService? firestoreService,
    UserRepository? userRepository,
  }) : _firestoreService = firestoreService ?? FirestoreService(),
       _userRepository = userRepository ?? UserRepository();

  final FirestoreService _firestoreService;
  final UserRepository _userRepository;

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
  }) async {
    final id = await _firestoreService
        .createDocument(FirestoreCollections.moods, {
          'userId': userId,
          'level': level,
          'label': label?.trim() ?? '',
          'note': note?.trim() ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
    await _tryRecordActivity(userId);
    return id;
  }

  Future<void> _tryRecordActivity(String userId) async {
    try {
      await _userRepository.recordActivity(
        userId,
        UserActivityType.moodCheckIn,
      );
    } catch (_) {
      // Mood saving should remain successful even if streak sync is unavailable.
    }
  }
}
