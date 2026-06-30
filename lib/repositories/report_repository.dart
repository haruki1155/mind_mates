import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../models/report_model.dart';
import '../services/firebase/firestore_service.dart';

class ReportRepository {
  ReportRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<ReportModel?> fetchLatestReport(String userId) async {
    final docs = await _firestoreService.getDocuments(
      FirestoreCollections.reports,
      whereEquals: {'userId': userId},
      orderBy: 'generatedAt',
      limit: 1,
    );
    if (docs.isEmpty) return null;
    return ReportModel.fromJson(docs.first, id: docs.first['id']?.toString());
  }

  Stream<List<ReportModel>> watchReports(String userId, {int limit = 12}) {
    return _firestoreService
        .watchDocuments(
          FirestoreCollections.reports,
          whereEquals: {'userId': userId},
          orderBy: 'generatedAt',
          limit: limit,
        )
        .map(
          (docs) => docs
              .map(
                (doc) => ReportModel.fromJson(doc, id: doc['id']?.toString()),
              )
              .toList(growable: false),
        );
  }

  Future<String> createPlaceholderWeeklyReport(String userId) {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    return _firestoreService.createDocument(FirestoreCollections.reports, {
      'userId': userId,
      'title': 'Mental Health Summary',
      'description': "This week's positive moods",
      'generatedAt': FieldValue.serverTimestamp(),
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekStart.add(const Duration(days: 6))),
      'positiveMoodCount': 0,
      'assessmentCount': 0,
      'topConcernAreas': <String>[],
      'recommendedNextActions': <String>[
        'Continue daily check-ins',
        'Use MindAid when you want guided support',
      ],
      'hasEnoughData': false,
    });
  }
}
