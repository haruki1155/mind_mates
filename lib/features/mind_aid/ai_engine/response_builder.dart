import '../domain/mind_aid_dataset_models.dart';

class ResponseBuilder {
  static const fallbackResponse =
      'I am here with you. I may not fully understand yet, but we can slow this down together. What feels hardest right now?';

  static String build({
    required MindAidDatasetRecord record,
    required MindAidDatasetBundle dataset,
    required String normalizedInput,
    List<String> recentResponses = const [],
    bool includeExercise = true,
    bool includeFollowUp = true,
  }) {
    final base = _pickStable(
      record.responses,
      normalizedInput,
      recentResponses: recentResponses,
    );
    final buffer = StringBuffer(base);

    if (record.escalation.required && record.escalation.message.isNotEmpty) {
      buffer.write('\n\n${record.escalation.message}');
      return buffer.toString();
    }

    final exercise = includeExercise ? _firstExercise(record, dataset) : null;
    if (exercise != null) {
      buffer.write('\n\nTry this: ${exercise.description}');
    }

    if (includeFollowUp && record.followUpQuestions.isNotEmpty) {
      buffer.write(
        '\n\n${_pickStable(record.followUpQuestions, normalizedInput)}',
      );
    }

    return buffer.toString();
  }

  static String _pickStable(
    List<String> values,
    String seed, {
    List<String> recentResponses = const [],
  }) {
    if (values.isEmpty) return fallbackResponse;
    final seedValue = seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    for (var offset = 0; offset < values.length; offset++) {
      final value = values[(seedValue + offset) % values.length];
      final wasRecentlyUsed = recentResponses.any((response) {
        return response == value || response.startsWith(value);
      });
      if (!wasRecentlyUsed) return value;
    }
    return values[seedValue % values.length];
  }

  static MindAidCopingExercise? _firstExercise(
    MindAidDatasetRecord record,
    MindAidDatasetBundle dataset,
  ) {
    for (final id in record.copingSteps) {
      final exercise = dataset.copingById(id);
      if (exercise != null) return exercise;
    }
    return null;
  }
}
