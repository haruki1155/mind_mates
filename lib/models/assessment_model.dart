class AssessmentModel {
  const AssessmentModel({
    required this.id,
    required this.score,
    required this.createdAt,
  });

  final String id;
  final int score;
  final DateTime createdAt;
}
