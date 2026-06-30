import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../models/mood_model.dart';
import '../services/firebase/firestore_service.dart';

class MoodRepository {
  MoodRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

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
  }) {
    return _firestoreService.createDocument(FirestoreCollections.moods, {
      'userId': userId,
      'level': level,
      'label': label?.trim() ?? '',
      'note': note?.trim() ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
