import '../models/recommendation_model.dart';

class DummyData {
  const DummyData._();

  static const recommendations = [
    RecommendationModel(
      id: 'breathing-01',
      title: 'Two-minute breathing reset',
      description: 'A short grounding exercise for stressful moments.',
    ),
  ];
}
