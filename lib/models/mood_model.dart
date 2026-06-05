class MoodModel {
  const MoodModel({
    required this.id,
    required this.level,
    required this.createdAt,
  });

  final String id;
  final int level;
  final DateTime createdAt;
}
