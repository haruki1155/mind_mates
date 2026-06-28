import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/mind_aid/ai_engine/mind_aid_chat_engine.dart';
import 'package:mind_mates/features/mind_aid/ai_engine/mind_aid_engine.dart';
import 'package:mind_mates/features/mind_aid/data/mind_aid_dataset_loader.dart';
import 'package:mind_mates/features/mind_aid/domain/mind_aid_chat_models.dart';
import 'package:mind_mates/features/mind_aid/domain/mind_aid_dataset_models.dart';
import 'package:mind_mates/models/mind_aid_message_model.dart';
import 'package:mind_mates/repositories/mind_aid_repository_screen.dart';

void main() {
  group('MindAidDatasetLoader', () {
    test('loads and validates dataset assets', () async {
      final loader = MindAidDatasetLoader(bundle: _MindAidTestBundle());

      final dataset = await loader.load();

      expect(dataset.records, hasLength(4));
      expect(dataset.crisisRecords, hasLength(1));
      expect(dataset.suggestions, hasLength(2));
      expect(dataset.copingExercises, isNotEmpty);
      expect(dataset.resources, isNotEmpty);
    });

    test('throws when the intent dataset is empty', () async {
      final loader = MindAidDatasetLoader(
        bundle: _MindAidTestBundle(
          overrides: {MindAidDatasetLoader.intentsPath: _jsonRecords([])},
        ),
      );

      expect(loader.load, throwsFormatException);
    });
  });

  group('MindAidEngine', () {
    late MindAidDatasetBundle dataset;

    setUp(() async {
      dataset = await MindAidDatasetLoader(bundle: _MindAidTestBundle()).load();
    });

    test('matches academic stress', () {
      final result = MindAidEngine().process(
        'I am stressed about exams and deadlines',
        dataset,
      );

      expect(result.intent, 'academic_stress');
      expect(result.severity, MindAidSeverity.medium);
      expect(result.response, contains('Try this:'));
    });

    test('matches burnout', () {
      final result = MindAidEngine().process(
        'I feel exhausted and drained',
        dataset,
      );

      expect(result.intent, 'burnout');
    });

    test('matches loneliness', () {
      final result = MindAidEngine().process(
        'I feel alone and invisible',
        dataset,
      );

      expect(result.intent, 'loneliness');
    });

    test('matches anxiety', () {
      final result = MindAidEngine().process(
        'I am panicking and worried',
        dataset,
      );

      expect(result.intent, 'anxiety');
    });

    test('returns fallback for unknown input', () {
      final result = MindAidEngine().process(
        'The sky looks clear today',
        dataset,
      );

      expect(result.isFallback, isTrue);
      expect(result.response, contains('I am here with you'));
    });

    test('prioritizes crisis safety routing', () {
      final result = MindAidEngine().process('I want to end my life', dataset);

      expect(result.intent, 'crisis_self_harm');
      expect(result.requiresEscalation, isTrue);
      expect(result.severity, MindAidSeverity.crisis);
      expect(result.riskFlags, contains('self_harm'));
      expect(result.response, contains('immediate'));
    });
  });

  group('MindAidChatEngine', () {
    late MindAidDatasetBundle dataset;

    setUp(() async {
      dataset = await MindAidDatasetLoader(bundle: _MindAidTestBundle()).load();
    });

    test('blends the top two relevant intents', () async {
      final result = await MindAidChatEngine().respond(
        const MindAidChatRequest(
          userId: 'user_1',
          text: 'I am exhausted and worried about exams',
        ),
        dataset,
      );

      expect(result.intentMatches.map((match) => match.record.intent), [
        'academic_stress',
        'burnout',
      ]);
      expect(result.text, contains('I also hear some burnout'));
      expect(result.suggestions, isNotEmpty);
    });

    test('handles short follow-up replies with active topic', () async {
      final engine = MindAidChatEngine();
      final first = await engine.respond(
        const MindAidChatRequest(
          userId: 'user_1',
          text: 'I am stressed about exams',
        ),
        dataset,
      );
      final second = await engine.respond(
        MindAidChatRequest(
          userId: 'user_1',
          text: 'yes',
          recentMessages: [
            _message('1', 'user', 'I am stressed about exams'),
            _message('2', 'assistant', first.text),
          ],
        ),
        dataset,
      );

      expect(second.primaryIntent, 'academic_stress');
      expect(second.text, contains('stay with academic stress'));
    });

    test('asks a clarifying question for low-confidence input', () async {
      final result = await MindAidChatEngine().respond(
        const MindAidChatRequest(userId: 'user_1', text: 'clouds are moving'),
        dataset,
      );

      expect(result.primaryIntent, 'general_support');
      expect(result.text, contains('need a little more detail'));
    });

    test('safety override wins over other matched concerns', () async {
      final result = await MindAidChatEngine().respond(
        const MindAidChatRequest(
          userId: 'user_1',
          text: 'I have exams but I want to end my life',
        ),
        dataset,
      );

      expect(result.primaryIntent, 'crisis_self_harm');
      expect(result.requiresEscalation, isTrue);
      expect(result.status, 'urgent');
    });

    test(
      'avoids repeating the same response when alternatives exist',
      () async {
        final engine = MindAidChatEngine();
        final first = await engine.respond(
          const MindAidChatRequest(userId: 'user_1', text: 'exam deadline'),
          dataset,
        );
        final second = await engine.respond(
          const MindAidChatRequest(userId: 'user_1', text: 'exam deadline'),
          dataset,
        );

        expect(second.text, isNot(first.text));
      },
    );
  });

  group('MindAidRepository', () {
    test('returns typed suggestions and assistant message models', () async {
      final repository = MindAidRepository(
        datasetLoader: MindAidDatasetLoader(bundle: _MindAidTestBundle()),
        engine: MindAidEngine(),
      );

      final suggestions = await repository.fetchSuggestions();
      final result = await repository.sendMessage(
        userId: 'user_1',
        text: 'I feel anxious',
      );
      final message = result.message;

      expect(suggestions.first.id, 'stress');
      expect(message.conversationId, 'user_1');
      expect(message.sender, 'assistant');
      expect(message.text, isNotEmpty);
      expect(result.suggestions, isNotEmpty);
    });
  });
}

MindAidMessageModel _message(String id, String sender, String text) {
  return MindAidMessageModel(
    id: id,
    conversationId: 'user_1',
    sender: sender,
    text: text,
    createdAt: DateTime(2026),
    status: 'sent',
  );
}

class _MindAidTestBundle extends CachingAssetBundle {
  _MindAidTestBundle({Map<String, String> overrides = const {}})
    : _assets = {..._defaultAssets, ...overrides};

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw StateError('Missing test asset: $key');
    }
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.view(bytes.buffer);
  }
}

final Map<String, String> _defaultAssets = {
  MindAidDatasetLoader.intentsPath: _jsonRecords([
    _record(
      id: 'academic_stress_v1',
      intent: 'academic_stress',
      category: 'school',
      keywords: ['exam', 'deadline'],
      phrases: ['stressed about exams'],
      responses: [
        'School pressure is real.',
        'Exams can feel heavy when deadlines are close.',
      ],
      copingSteps: ['task_breakdown'],
      recommendations: ['study-plan-reset'],
    ),
    _record(
      id: 'burnout_v1',
      intent: 'burnout',
      category: 'energy',
      keywords: ['exhausted', 'drained'],
      phrases: ['no energy'],
      responses: ['You sound worn down.'],
      copingSteps: ['rest_plan'],
    ),
    _record(
      id: 'loneliness_v1',
      intent: 'loneliness',
      category: 'connection',
      keywords: ['alone', 'invisible'],
      phrases: ['no one understands'],
      responses: ['Feeling alone is heavy.'],
    ),
    _record(
      id: 'anxiety_v1',
      intent: 'anxiety',
      category: 'anxiety',
      keywords: ['worried', 'panicking'],
      phrases: ['feel anxious'],
      responses: ['Let us slow this down.'],
    ),
  ]),
  MindAidDatasetLoader.crisisPath: _jsonRecords([
    _record(
      id: 'self_harm_v1',
      intent: 'crisis_self_harm',
      category: 'safety',
      keywords: ['end my life'],
      phrases: ['end my life'],
      severity: 'crisis',
      riskFlags: ['self_harm', 'urgent'],
      responses: ['Please get immediate human support.'],
      escalation: {
        'required': true,
        'message': 'Contact emergency support immediately.',
      },
    ),
  ]),
  MindAidDatasetLoader.suggestionsPath: _jsonRecords([
    {
      'id': 'stress',
      'label': "I'm stressed about exams",
      'iconAsset': 'assets/images/MESSAGE/stress.png',
    },
    {
      'id': 'anxiety',
      'label': "I'm feeling anxious",
      'iconAsset': 'assets/images/MESSAGE/anxiety.png',
    },
  ]),
  MindAidDatasetLoader.copingPath: _jsonRecords([
    {
      'id': 'task_breakdown',
      'title': 'One-task reset',
      'description': 'Choose one tiny task.',
    },
    {
      'id': 'rest_plan',
      'title': 'Rest plan',
      'description': 'Pause and recover for a moment.',
    },
  ]),
  MindAidDatasetLoader.resourcesPath: _jsonRecords([
    {
      'id': 'study-plan-reset',
      'title': 'Study plan reset',
      'description': 'Break academic stress into one action.',
      'routeName': '',
      'tags': ['school'],
    },
  ]),
};

Map<String, dynamic> _record({
  required String id,
  required String intent,
  required String category,
  required List<String> keywords,
  required List<String> phrases,
  required List<String> responses,
  String severity = 'medium',
  List<String> riskFlags = const [],
  List<String> copingSteps = const [],
  List<String> recommendations = const [],
  Map<String, dynamic> escalation = const {'required': false, 'message': ''},
}) {
  return {
    'id': id,
    'intent': intent,
    'category': category,
    'keywords': keywords,
    'phrases': phrases,
    'severity': severity,
    'riskFlags': riskFlags,
    'responses': responses,
    'copingSteps': copingSteps,
    'recommendations': recommendations,
    'followUpQuestions': ['What feels hardest right now?'],
    'escalation': escalation,
  };
}

String _jsonRecords(List<Map<String, dynamic>> records) {
  return jsonEncode({'version': 1, 'records': records});
}
