import '../domain/mind_aid_chat_models.dart';
import '../domain/mind_aid_dataset_models.dart';
import '../domain/mind_aid_model_provider.dart';
import 'mind_aid_dialogue_manager.dart';
import 'response_builder.dart';

class MindAidResponseComposer {
  const MindAidResponseComposer({
    this.modelProvider = const LocalMindAidModelProvider(),
  });

  final MindAidModelProvider modelProvider;

  Future<String> compose({
    required MindAidDialogueAction action,
    required String normalizedInput,
    required String originalInput,
    required List<MindAidIntentMatch> matches,
    required MindAidDatasetBundle dataset,
    required MindAidConversationState state,
  }) async {
    final modelText = await modelProvider.generate(
      MindAidModelPrompt(
        userText: originalInput,
        matches: matches,
        state: state,
        dataset: dataset,
        requiresEscalation: action == MindAidDialogueAction.escalate,
      ),
    );
    if (modelText.trim().isNotEmpty) return modelText.trim();

    switch (action) {
      case MindAidDialogueAction.clarify:
        return _clarify(state);
      case MindAidDialogueAction.followUp:
        return _followUp(normalizedInput, matches.first, dataset, state);
      case MindAidDialogueAction.escalate:
        return ResponseBuilder.build(
          record: matches.first.record,
          dataset: dataset,
          normalizedInput: normalizedInput,
        );
      case MindAidDialogueAction.answer:
        return _answer(normalizedInput, matches, dataset, state);
    }
  }

  String _answer(
    String normalizedInput,
    List<MindAidIntentMatch> matches,
    MindAidDatasetBundle dataset,
    MindAidConversationState state,
  ) {
    final primary = matches.first.record;
    final buffer = StringBuffer(
      ResponseBuilder.build(
        record: primary,
        dataset: dataset,
        normalizedInput: normalizedInput,
        recentResponses: state.recentResponses,
      ),
    );

    if (matches.length > 1) {
      final secondary = matches[1].record;
      buffer.write(
        '\n\nI also hear some ${_readable(secondary.intent)} in what you said. '
        '${_shortSupportLine(secondary, dataset, normalizedInput)}',
      );
    }

    return buffer.toString();
  }

  String _followUp(
    String normalizedInput,
    MindAidIntentMatch match,
    MindAidDatasetBundle dataset,
    MindAidConversationState state,
  ) {
    final record = match.record;
    final topic = _readable(record.intent);
    final buffer = StringBuffer();

    if (_isYes(normalizedInput)) {
      buffer.write('Okay. Let us stay with $topic and keep it manageable.');
    } else if (_isNo(normalizedInput)) {
      buffer.write(
        'That is okay. We can change direction and focus on what feels more useful now.',
      );
    } else {
      buffer.write(
        'Thanks for telling me. I will connect that back to $topic so we can make the next step clearer.',
      );
    }

    MindAidCopingExercise? exercise;
    for (final id in record.copingSteps) {
      exercise = dataset.copingById(id);
      if (exercise != null) break;
    }
    if (exercise != null) {
      buffer.write('\n\nA small next step: ${exercise.description}');
    }

    final question = record.followUpQuestions.isNotEmpty
        ? record.followUpQuestions.first
        : state.lastQuestion;
    if (question != null && question.trim().isNotEmpty) {
      buffer.write('\n\n$question');
    }

    return buffer.toString();
  }

  String _clarify(MindAidConversationState state) {
    if (state.lastQuestion != null) {
      return 'I want to understand you better. ${state.lastQuestion}';
    }
    return 'I want to support you well, but I need a little more detail. Is this mostly about school, relationships, stress, anxiety, or something else?';
  }

  String _shortSupportLine(
    MindAidDatasetRecord record,
    MindAidDatasetBundle dataset,
    String normalizedInput,
  ) {
    final response = ResponseBuilder.build(
      record: record,
      dataset: dataset,
      normalizedInput: normalizedInput,
      includeFollowUp: false,
      includeExercise: false,
    );
    final firstSentence = response.split(RegExp(r'(?<=[.!?])\s+')).first;
    return firstSentence;
  }

  String _readable(String value) => value.replaceAll('_', ' ');

  bool _isYes(String value) => value == 'yes' || value.startsWith('yes ');

  bool _isNo(String value) => value == 'no' || value.startsWith('no ');
}
