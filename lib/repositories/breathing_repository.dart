import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../features/breathing/models/breathing_models.dart';
import '../repositories/user_repository.dart';
import '../services/firebase/firestore_service.dart';

class BreathingSessionRecord {
  const BreathingSessionRecord({
    required this.userId,
    required this.technique,
    required this.completedSeconds,
    required this.startedAt,
    required this.completedAt,
  });

  final String userId;
  final BreathingTechnique technique;
  final int completedSeconds;
  final DateTime startedAt;
  final DateTime completedAt;
}

class BreathingRepository {
  BreathingRepository({
    FirestoreService? firestoreService,
    UserRepository? userRepository,
  }) : _firestoreService = firestoreService ?? FirestoreService(),
       _userRepository = userRepository ?? UserRepository();

  final FirestoreService _firestoreService;
  final UserRepository _userRepository;

  Future<String> completeSession(BreathingSessionRecord record) async {
    final id = await _firestoreService
        .createDocument(FirestoreCollections.breathingSessions, {
          'userId': record.userId,
          'techniqueId': record.technique.id,
          'techniqueTitle': record.technique.title,
          'durationSeconds': record.technique.durationSeconds,
          'completedSeconds': record.completedSeconds,
          'completed': true,
          'startedAt': Timestamp.fromDate(record.startedAt),
          'completedAt': Timestamp.fromDate(record.completedAt),
          'createdAt': FieldValue.serverTimestamp(),
        });

    await _userRepository.recordActivity(
      record.userId,
      UserActivityType.breathingSession,
      occurredAt: record.completedAt,
    );
    return id;
  }
}
