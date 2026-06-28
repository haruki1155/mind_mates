import '../../../models/mind_aid_suggestion_model.dart';

enum MindAidSeverity {
  low,
  medium,
  high,
  crisis;

  static MindAidSeverity fromString(String? value) {
    return MindAidSeverity.values.firstWhere(
      (severity) => severity.name == value,
      orElse: () => MindAidSeverity.low,
    );
  }
}

class MindAidEscalation {
  const MindAidEscalation({required this.required, required this.message});

  final bool required;
  final String message;

  factory MindAidEscalation.fromMap(Map<String, dynamic>? map) {
    return MindAidEscalation(
      required: map?['required'] == true,
      message: (map?['message'] as String?)?.trim() ?? '',
    );
  }
}

class MindAidDatasetRecord {
  const MindAidDatasetRecord({
    required this.id,
    required this.intent,
    required this.category,
    required this.keywords,
    required this.phrases,
    required this.severity,
    required this.riskFlags,
    required this.responses,
    required this.copingSteps,
    required this.recommendations,
    required this.followUpQuestions,
    required this.escalation,
  });

  final String id;
  final String intent;
  final String category;
  final List<String> keywords;
  final List<String> phrases;
  final MindAidSeverity severity;
  final List<String> riskFlags;
  final List<String> responses;
  final List<String> copingSteps;
  final List<String> recommendations;
  final List<String> followUpQuestions;
  final MindAidEscalation escalation;

  bool get requiresEscalation =>
      escalation.required || severity == MindAidSeverity.crisis;

  factory MindAidDatasetRecord.fromMap(Map<String, dynamic> map) {
    return MindAidDatasetRecord(
      id: _requiredString(map, 'id'),
      intent: _requiredString(map, 'intent'),
      category: _requiredString(map, 'category'),
      keywords: _stringList(map['keywords']),
      phrases: _stringList(map['phrases']),
      severity: MindAidSeverity.fromString(map['severity'] as String?),
      riskFlags: _stringList(map['riskFlags']),
      responses: _stringList(map['responses']),
      copingSteps: _stringList(map['copingSteps']),
      recommendations: _stringList(map['recommendations']),
      followUpQuestions: _stringList(map['followUpQuestions']),
      escalation: MindAidEscalation.fromMap(
        map['escalation'] as Map<String, dynamic>?,
      ),
    );
  }
}

class MindAidCopingExercise {
  const MindAidCopingExercise({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;

  factory MindAidCopingExercise.fromMap(Map<String, dynamic> map) {
    return MindAidCopingExercise(
      id: _requiredString(map, 'id'),
      title: _requiredString(map, 'title'),
      description: _requiredString(map, 'description'),
    );
  }
}

class MindAidResource {
  const MindAidResource({
    required this.id,
    required this.title,
    required this.description,
    required this.routeName,
    required this.tags,
  });

  final String id;
  final String title;
  final String description;
  final String routeName;
  final List<String> tags;

  factory MindAidResource.fromMap(Map<String, dynamic> map) {
    return MindAidResource(
      id: _requiredString(map, 'id'),
      title: _requiredString(map, 'title'),
      description: _requiredString(map, 'description'),
      routeName: (map['routeName'] as String?)?.trim() ?? '',
      tags: _stringList(map['tags']),
    );
  }
}

class MindAidDatasetBundle {
  const MindAidDatasetBundle({
    required this.records,
    required this.crisisRecords,
    required this.suggestions,
    required this.copingExercises,
    required this.resources,
  });

  final List<MindAidDatasetRecord> records;
  final List<MindAidDatasetRecord> crisisRecords;
  final List<MindAidSuggestionModel> suggestions;
  final List<MindAidCopingExercise> copingExercises;
  final List<MindAidResource> resources;

  List<MindAidDatasetRecord> get allRecords => [...crisisRecords, ...records];

  MindAidCopingExercise? copingById(String id) {
    for (final exercise in copingExercises) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  MindAidResource? resourceById(String id) {
    for (final resource in resources) {
      if (resource.id == id) return resource;
    }
    return null;
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw FormatException('MindAid dataset field "$key" is required.');
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('MindAid dataset list field is invalid.');
  }
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) {
        return item.isNotEmpty;
      })
      .toList(growable: false);
}
