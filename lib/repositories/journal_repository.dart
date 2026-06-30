import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../models/journal_model.dart';
import '../services/firebase/firestore_service.dart';

class JournalRepository {
  JournalRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<List<JournalModel>> fetchRecentJournals(
    String userId, {
    int limit = 20,
  }) {
    return _firestoreService
        .getDocuments(
          FirestoreCollections.journals,
          whereEquals: {'userId': userId},
          orderBy: 'createdAt',
          limit: limit,
        )
        .then(
          (docs) => docs
              .map(
                (doc) => JournalModel.fromJson(doc, id: doc['id']?.toString()),
              )
              .toList(growable: false),
        );
  }

  Future<String> createJournal({
    required String userId,
    required String content,
    int? moodLevel,
    List<String> tags = const [],
  }) {
    return _firestoreService.createDocument(FirestoreCollections.journals, {
      'userId': userId,
      'content': content.trim(),
      'moodLevel': moodLevel,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateJournal({
    required String journalId,
    required String content,
    int? moodLevel,
    List<String> tags = const [],
  }) {
    return _firestoreService
        .updateDocument(FirestoreCollections.journals, journalId, {
          'content': content.trim(),
          'moodLevel': moodLevel,
          'tags': tags,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
}
