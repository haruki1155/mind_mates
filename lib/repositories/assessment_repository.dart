import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../features/quick_assessment/models/quick_assessment_models.dart';
import '../features/student_assessment/models/student_assessment_models.dart';
import '../services/firebase/firestore_service.dart';

class AssessmentRepository {
  AssessmentRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<Map<String, Object>> saveQuickAssessment({
    required String userId,
    required QuickAssessmentResult result,
  }) async {
    final payload = <String, Object>{
      'userId': userId,
      'type': 'quick',
      ...result.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestoreService.createDocument(
      FirestoreCollections.assessments,
      Map<String, dynamic>.from(payload),
    );

    return payload;
  }

  Future<Map<String, Object>> saveStudentAssessment({
    required String userId,
    required StudentAssessmentResult result,
    List<StudentAssessmentAnswer> answers = const [],
  }) async {
    final payload = <String, Object>{
      'userId': userId,
      'type': result.userType.toLowerCase(),
      'role': result.userType.toLowerCase(),
      ...result.toJson(),
      'responses': answers.map((answer) => answer.toJson()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestoreService.createDocument(
      FirestoreCollections.assessments,
      Map<String, dynamic>.from(payload),
    );

    return payload;
  }

  Future<Map<String, dynamic>?> fetchLatestAssessment(String userId) async {
    final docs = await _firestoreService.getDocuments(
      FirestoreCollections.assessments,
      whereEquals: {'userId': userId},
      orderBy: 'createdAt',
      limit: 1,
    );
    if (docs.isEmpty) return null;
    return docs.first;
  }

  Future<int> countAssessmentsSince({
    required String userId,
    required DateTime since,
  }) async {
    final snapshot = await _firestoreService.firestore
        .collection(FirestoreCollections.assessments)
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();
    return snapshot.docs.length;
  }
}
