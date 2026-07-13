import '../database/firestore_collections.dart';
import '../models/admin_status_summary_model.dart';
import '../services/firebase/firestore_service.dart';

class AdminStatusRepository {
  AdminStatusRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<List<Map<String, dynamic>>> fetchUserAssessments(String userId) {
    return _firestoreService.getDocuments(
      FirestoreCollections.assessments,
      whereEquals: {'userId': userId},
      orderBy: 'createdAt',
      descending: true,
    );
  }

  Stream<List<AdminStatusSummaryModel>> watchUserStatuses({int limit = 200}) {
    return _firestoreService
        .watchDocuments(
          FirestoreCollections.adminStatusSummaries,
          orderBy: 'updatedAt',
          limit: limit,
        )
        .map((docs) {
          final statuses = docs
              .map(
                (doc) => AdminStatusSummaryModel.fromJson(
                  doc,
                  id: doc['id']?.toString(),
                ),
              )
              .toList(growable: false);
          return [...statuses]..sort(_sortStatus);
        });
  }

  int _sortStatus(
    AdminStatusSummaryModel first,
    AdminStatusSummaryModel second,
  ) {
    final statusSort = first.status.rank.compareTo(second.status.rank);
    if (statusSort != 0) return statusSort;
    final activitySort = second.totalActivityCount.compareTo(
      first.totalActivityCount,
    );
    if (activitySort != 0) return activitySort;
    return first.userLabel.toLowerCase().compareTo(
      second.userLabel.toLowerCase(),
    );
  }
}
