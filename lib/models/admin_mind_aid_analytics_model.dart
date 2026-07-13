import '../core/utils/firestore_mapper.dart';

class AdminMindAidAnalyticsModel {
  const AdminMindAidAnalyticsModel({
    required this.dateKey,
    required this.turnCount,
    required this.fallbackCount,
    required this.latencyTotalMs,
    required this.helpfulCount,
    required this.unhelpfulCount,
    required this.intentCounts,
    required this.sourceCounts,
    required this.safetyCounts,
  });

  final String dateKey;
  final int turnCount;
  final int fallbackCount;
  final int latencyTotalMs;
  final int helpfulCount;
  final int unhelpfulCount;
  final Map<String, int> intentCounts;
  final Map<String, int> sourceCounts;
  final Map<String, int> safetyCounts;

  factory AdminMindAidAnalyticsModel.fromJson(Map<String, dynamic> json) {
    Map<String, int> counts(String key) {
      final value = json[key];
      if (value is! Map) return const {};
      return Map.fromEntries(
        value.entries.map(
          (entry) =>
              MapEntry(entry.key.toString(), intFromFirestore(entry.value)),
        ),
      );
    }

    return AdminMindAidAnalyticsModel(
      dateKey: json['dateKey']?.toString() ?? '',
      turnCount: intFromFirestore(json['turnCount']),
      fallbackCount: intFromFirestore(json['fallbackCount']),
      latencyTotalMs: intFromFirestore(json['latencyTotalMs']),
      helpfulCount: intFromFirestore(json['helpfulCount']),
      unhelpfulCount: intFromFirestore(json['unhelpfulCount']),
      intentCounts: counts('intentCounts'),
      sourceCounts: counts('sourceCounts'),
      safetyCounts: counts('safetyCounts'),
    );
  }
}
