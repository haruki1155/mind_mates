import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../models/journal_model.dart';
import '../services/firebase/firestore_service.dart';
import 'user_repository.dart';

class JournalRepository {
  JournalRepository({
    FirestoreService? firestoreService,
    UserRepository? userRepository,
  }) : _firestoreService = firestoreService ?? FirestoreService(),
       _userRepository = userRepository ?? UserRepository();

  final FirestoreService _firestoreService;
  final UserRepository _userRepository;

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
  }) async {
    final id = await _firestoreService
        .createDocument(FirestoreCollections.journals, {
          'userId': userId,
          'content': content.trim(),
          'moodLevel': moodLevel,
          'tags': tags,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    await _tryRecordActivity(userId);
    return id;
  }

  Future<String> createEntry(JournalModel entry) async {
    final data = entry.toJson(userId: entry.userId)
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    final id = await _firestoreService.createDocument(
      FirestoreCollections.journals,
      data,
    );
    if (entry.userId != null) await _tryRecordActivity(entry.userId!);
    return id;
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

  Future<void> updateEntry(JournalModel entry) {
    final data = entry.toJson()
      ..remove('createdAt')
      ..remove('userId')
      ..['updatedAt'] = FieldValue.serverTimestamp();
    return _firestoreService.updateDocument(
      FirestoreCollections.journals,
      entry.id,
      data,
    );
  }

  Future<void> deleteJournal(String journalId) {
    return _firestoreService.deleteDocument(
      FirestoreCollections.journals,
      journalId,
    );
  }

  Future<void> _tryRecordActivity(String userId) async {
    try {
      await _userRepository.recordActivity(
        userId,
        UserActivityType.journalEntry,
      );
    } catch (_) {
      // Journal saving should remain successful even if streak sync is unavailable.
    }
  }
}
