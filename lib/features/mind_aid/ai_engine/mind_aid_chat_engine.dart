import '../../../models/mind_aid_suggestion_model.dart';
import '../domain/mind_aid_chat_models.dart';
import '../domain/mind_aid_context.dart';
import '../domain/mind_aid_dataset_models.dart';
import 'mind_aid_dialogue_manager.dart';
import 'mind_aid_knowledge_retriever.dart';
import 'mind_aid_response_composer.dart';
import 'score_engine.dart';

class MindAidChatEngine {
  MindAidChatEngine({
    MindAidKnowledgeRetriever? retriever,
    MindAidDialogueManager? dialogueManager,
    MindAidResponseComposer? responseComposer,
  }) : _retriever = retriever ?? const MindAidKnowledgeRetriever(),
       _dialogueManager = dialogueManager ?? const MindAidDialogueManager(),
       _responseComposer = responseComposer ?? const MindAidResponseComposer();

  final MindAidKnowledgeRetriever _retriever;
  final MindAidDialogueManager _dialogueManager;
  final MindAidResponseComposer _responseComposer;
  MindAidConversationState _state = const MindAidConversationState();

  Future<MindAidChatResponse> respond(
    MindAidChatRequest request,
    MindAidDatasetBundle dataset,
  ) async {
    final normalizedInput = ScoreEngine.normalize(request.text);
    final requestState = MindAidConversationState.fromMessages(
      request.recentMessages,
    );
    final state = _mergeState(_state, requestState);
    final context = MindAidContext(
      recentMessages: request.recentMessages
          .map((message) => message.text)
          .toList(growable: false),
      moodLevel: request.moodLevel,
      assessmentScore: request.assessmentScore,
      journalText: request.journalText,
    );

    final matches = normalizedInput.isEmpty
        ? <MindAidIntentMatch>[]
        : _retriever.retrieve(normalizedInput, dataset, context: context);
    final activeFollowUpMatch = state.activeIntent == null
        ? null
        : _retriever.matchByIntent(state.activeIntent!, dataset);
    final decision = _dialogueManager.decide(
      normalizedInput: normalizedInput,
      matches: matches,
      state: state,
      activeFollowUpMatch: activeFollowUpMatch,
    );
    final responseText = await _responseComposer.compose(
      action: decision.action,
      normalizedInput: normalizedInput,
      originalInput: request.text,
      matches: decision.matches,
      dataset: dataset,
      state: state,
    );
    final severity = _highestSeverity(decision.matches);
    final followUps = _followUpsFor(decision, state);
    final nextState = state.updateFromResponse(
      matches: decision.matches,
      response: responseText,
      followUpQuestions: followUps,
      severity: severity,
    );
    _state = nextState;

    return MindAidChatResponse(
      text: responseText,
      intentMatches: decision.matches,
      severity: severity,
      suggestions: _suggestionsFor(followUps, dataset),
      followUpQuestions: followUps,
      recommendations: _recommendationsFor(decision.matches, dataset),
      requiresEscalation:
          decision.action == MindAidDialogueAction.escalate ||
          decision.matches.any((match) => match.requiresEscalation),
      conversationState: nextState,
      status: decision.action == MindAidDialogueAction.escalate
          ? 'urgent'
          : 'sent',
    );
  }

  MindAidConversationState _mergeState(
    MindAidConversationState current,
    MindAidConversationState fromMessages,
  ) {
    return MindAidConversationState(
      activeIntent: current.activeIntent ?? fromMessages.activeIntent,
      activeCategory: current.activeCategory ?? fromMessages.activeCategory,
      lastQuestion: current.lastQuestion ?? fromMessages.lastQuestion,
      unresolvedConcern:
          current.unresolvedConcern ?? fromMessages.unresolvedConcern,
      severity: current.severity,
      recentIntents: current.recentIntents,
      recentResponses: [
        ...current.recentResponses,
        ...fromMessages.recentResponses,
      ].take(8).toList(growable: false),
      awaitingFollowUp:
          current.awaitingFollowUp || fromMessages.awaitingFollowUp,
      turnCount: current.turnCount > fromMessages.turnCount
          ? current.turnCount
          : fromMessages.turnCount,
    );
  }

  MindAidSeverity _highestSeverity(List<MindAidIntentMatch> matches) {
    if (matches.any(
      (match) => match.record.severity == MindAidSeverity.crisis,
    )) {
      return MindAidSeverity.crisis;
    }
    if (matches.any((match) => match.record.severity == MindAidSeverity.high)) {
      return MindAidSeverity.high;
    }
    if (matches.any(
      (match) => match.record.severity == MindAidSeverity.medium,
    )) {
      return MindAidSeverity.medium;
    }
    return MindAidSeverity.low;
  }

  List<String> _followUpsFor(
    MindAidDialogueDecision decision,
    MindAidConversationState state,
  ) {
    if (decision.action == MindAidDialogueAction.clarify) {
      return [
        state.lastQuestion ??
            'Is this mostly about school, relationships, stress, anxiety, or something else?',
      ];
    }
    final questions = <String>[];
    for (final match in decision.matches) {
      questions.addAll(match.record.followUpQuestions);
    }
    return questions.take(3).toList(growable: false);
  }

  List<MindAidResource> _recommendationsFor(
    List<MindAidIntentMatch> matches,
    MindAidDatasetBundle dataset,
  ) {
    final resources = <MindAidResource>[];
    for (final match in matches) {
      for (final id in match.record.recommendations) {
        final resource = dataset.resourceById(id);
        if (resource != null &&
            !resources.any((item) => item.id == resource.id)) {
          resources.add(resource);
        }
      }
    }
    return resources;
  }

  List<MindAidSuggestionModel> _suggestionsFor(
    List<String> followUps,
    MindAidDatasetBundle dataset,
  ) {
    if (followUps.isNotEmpty) {
      return followUps
          .take(3)
          .map(
            (question) => MindAidSuggestionModel(
              id: 'follow_up_${question.hashCode.abs()}',
              label: question,
            ),
          )
          .toList(growable: false);
    }
    return dataset.suggestions.take(5).toList(growable: false);
  }
}
