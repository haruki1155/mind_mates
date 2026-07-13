import '../core/utils/firestore_mapper.dart';

class AdminActivityAnalyticsModel {
  const AdminActivityAnalyticsModel({
    required this.dateKey,
    required this.activeUserCount,
    required this.eventCount,
    required this.activityCounts,
  });

  final String dateKey;
  final int activeUserCount;
  final int eventCount;
  final Map<String, int> activityCounts;

  factory AdminActivityAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['activityCounts'];
    return AdminActivityAnalyticsModel(
      dateKey: json['dateKey']?.toString() ?? '',
      activeUserCount: intFromFirestore(json['activeUserCount']),
      eventCount: intFromFirestore(json['eventCount']),
      activityCounts: rawCounts is Map
          ? Map<String, int>.fromEntries(
              rawCounts.entries.map(
                (entry) => MapEntry(
                  entry.key.toString(),
                  intFromFirestore(entry.value),
                ),
              ),
            )
          : const {},
    );
  }
}
