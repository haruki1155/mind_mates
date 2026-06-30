import '../core/utils/firestore_mapper.dart';

class MoodModel {
  const MoodModel({
    required this.id,
    required this.level,
    required this.createdAt,
    this.userId,
    this.label,
    this.note,
  });

  final String id;
  final int level;
  final DateTime createdAt;
  final String? userId;
  final String? label;
  final String? note;

  factory MoodModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return MoodModel(
      id: (json['id'] ?? id ?? '').toString(),
      userId: json['userId']?.toString(),
      level: intFromFirestore(json['level']),
      label: json['label']?.toString(),
      note: json['note']?.toString(),
      createdAt: dateTimeFromFirestoreOrNow(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson({String? userId}) {
    return {
      'userId': userId ?? this.userId,
      'level': level,
      'label': label ?? '',
      'note': note ?? '',
      'createdAt': createdAt,
    };
  }
}
