import '../core/utils/firestore_mapper.dart';

class JournalModel {
  const JournalModel({
    required this.id,
    required this.content,
    required this.createdAt,
    this.userId,
    this.moodLevel,
    this.tags = const [],
    this.updatedAt,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final String? userId;
  final int? moodLevel;
  final List<String> tags;
  final DateTime? updatedAt;

  factory JournalModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return JournalModel(
      id: (json['id'] ?? id ?? '').toString(),
      userId: json['userId']?.toString(),
      content: (json['content'] ?? '').toString(),
      moodLevel: json['moodLevel'] == null
          ? null
          : intFromFirestore(json['moodLevel']),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag.toString())
          .toList(growable: false),
      createdAt: dateTimeFromFirestoreOrNow(json['createdAt']),
      updatedAt: dateTimeFromFirestore(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson({String? userId}) {
    return {
      'userId': userId ?? this.userId,
      'content': content,
      'moodLevel': moodLevel,
      'tags': tags,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
