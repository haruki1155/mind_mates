import 'package:flutter/material.dart';

import '/features/counseling/screens/mind_aid_screen.dart';
import '/features/mind_aid/domain/mind_aid_context.dart';
import '/features/mind_aid/domain/mind_aid_safety.dart';
import '/models/mind_aid_message_model.dart';
import '/repositories/mind_aid_repository_screen.dart';

class MindAidAnalyticsSnapshot {
  const MindAidAnalyticsSnapshot({
    required this.selectedSuggestionCount,
    required this.highRiskTriggerCount,
    required this.fallbackCount,
    required this.commonIntentCounts,
  });

  final int selectedSuggestionCount;
  final int highRiskTriggerCount;
  final int fallbackCount;
  final Map<String, int> commonIntentCounts;
}

class MindAidProvider extends ChangeNotifier {
  final MindAidRepository repository;

  MindAidProvider(this.repository);

  List<MindAidMessage> messages = [];
  List<MindAidSuggestion> suggestions = [];

  bool isLoading = false;
  bool isSending = false;
  String? errorMessage;
  String? _conversationSummary;
  int _selectedSuggestionCount = 0;
  int _highRiskTriggerCount = 0;
  int _fallbackCount = 0;
  final Map<String, int> _commonIntentCounts = {};

  MindAidAnalyticsSnapshot get analytics => MindAidAnalyticsSnapshot(
    selectedSuggestionCount: _selectedSuggestionCount,
    highRiskTriggerCount: _highRiskTriggerCount,
    fallbackCount: _fallbackCount,
    commonIntentCounts: Map.unmodifiable(_commonIntentCounts),
  );

  Future<void> loadChat(
    String userId, {
    MindAidContext context = const MindAidContext(),
  }) async {
    final effectiveContext = _contextWithSessionMemory(context);
    isLoading = true;
    notifyListeners();

    try {
      final msgResult = await repository.fetchMessages(userId);
      final sugResult = await repository.fetchSuggestions();

      messages = msgResult
          .map(
            (e) => MindAidMessage(
              id: e.id,
              sender: e.sender == "user"
                  ? MindAidSender.user
                  : MindAidSender.assistant,
              text: e.text,
              createdAt: e.createdAt,
              status: e.status,
              categoryLabel: null,
              supportCards: const [],
            ),
          )
          .toList();

      suggestions = _suggestionsWithAssessmentReview(
        sugResult
            .map(
              (e) => MindAidSuggestion(
                id: e.id,
                label: e.label,
                iconAsset: e.iconAsset,
              ),
            )
            .toList(growable: false),
        effectiveContext,
      );
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> sendMessage(
    String userId,
    String text, {
    MindAidContext context = const MindAidContext(),
  }) async {
    final effectiveContext = _contextWithSessionMemory(context);
    isSending = true;
    notifyListeners();

    try {
      final userMessage = MindAidMessage(
        id: DateTime.now().toString(),
        sender: MindAidSender.user,
        text: text,
        createdAt: DateTime.now(),
        status: "sent",
      );

      messages.add(userMessage);
      notifyListeners();

      final recentMessages = messages
          .map((message) {
            return message.toModel(conversationId: userId);
          })
          .toList(growable: false);
      final result = await repository.sendMessage(
        userId: userId,
        text: text,
        recentMessages: recentMessages,
        context: effectiveContext,
      );
      final bot = result.message;

      final botMessage = MindAidMessage(
        id: bot.id,
        sender: MindAidSender.assistant,
        text: bot.text,
        createdAt: bot.createdAt,
        status: bot.status,
        categoryLabel: _categoryLabelFor(result),
        supportCards: _supportCardsFor(result, context),
      );

      messages.add(botMessage);
      suggestions = _suggestionsWithAssessmentReview(
        result.suggestions
            .map(
              (suggestion) => MindAidSuggestion(
                id: suggestion.id,
                label: suggestion.label,
                iconAsset: suggestion.iconAsset,
              ),
            )
            .toList(growable: false),
        effectiveContext,
      );
      _trackChatResult(result);
      _conversationSummary = _summarizeConversation();
      isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      _fallbackCount += 1;
    }

    isSending = false;
    notifyListeners();
    return false;
  }

  Future<bool> selectSuggestion(
    MindAidSuggestion suggestion,
    String userId, {
    MindAidContext context = const MindAidContext(),
  }) {
    _selectedSuggestionCount += 1;
    return sendMessage(
      userId,
      suggestion.label,
      context: _contextWithSessionMemory(context),
    );
  }

  void _trackChatResult(MindAidSendResult result) {
    final response = result.chatResponse;
    if (response.safetyLevel == MindAidSafetyLevel.highDistress ||
        response.safetyLevel == MindAidSafetyLevel.crisisOrImmediateRisk) {
      _highRiskTriggerCount += 1;
    }

    final intent = response.primaryIntent;
    _commonIntentCounts[intent] = (_commonIntentCounts[intent] ?? 0) + 1;

    if (response.text.trim().isEmpty) {
      _fallbackCount += 1;
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  List<MindAidSuggestion> _suggestionsWithAssessmentReview(
    List<MindAidSuggestion> base,
    MindAidContext context,
  ) {
    if (!context.hasAssessment ||
        base.any((suggestion) => suggestion.id == 'review_assessment')) {
      return base;
    }

    return [
      const MindAidSuggestion(
        id: 'review_assessment',
        label: 'Review my assessment',
      ),
      ...base,
    ];
  }

  MindAidContext _contextWithSessionMemory(MindAidContext context) {
    return context.copyWith(
      conversationSummary: context.conversationSummary ?? _conversationSummary,
      recentMessages: messages.reversed
          .map((message) => message.text)
          .take(8)
          .toList(growable: false)
          .reversed
          .toList(growable: false),
    );
  }

  String? _summarizeConversation() {
    final userMessages = messages
        .where((message) => message.sender == MindAidSender.user)
        .map((message) => message.text.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    if (userMessages.isEmpty) return null;

    final latest = userMessages.reversed.take(3).toList().reversed.join(' | ');
    return 'Recent user concerns: $latest';
  }

  List<MindAidSupportCard> _supportCardsFor(
    MindAidSendResult result,
    MindAidContext context,
  ) {
    if (!result.chatResponse.requiresEscalation) {
      return const [];
    }

    final cards = <MindAidSupportCard>[];

    if (context.assessment?.highestCategory case final topConcern?) {
      cards.add(
        MindAidSupportCard(
          title: 'Assessment insight',
          description:
              '${topConcern.key} is one of your higher areas (${topConcern.value.round()}%).',
          icon: Icons.insights_rounded,
        ),
      );
    }

    cards.insert(
      0,
      const MindAidSupportCard(
        title: 'Immediate support',
        description:
            'If there is immediate danger, contact emergency services, campus security, PACC, or a trusted person now.',
        icon: Icons.health_and_safety_rounded,
      ),
    );

    final unique = <String, MindAidSupportCard>{};
    for (final card in cards) {
      unique.putIfAbsent('${card.title}:${card.description}', () => card);
    }
    return unique.values.take(3).toList(growable: false);
  }

  String? _categoryLabelFor(MindAidSendResult result) {
    final matches = result.chatResponse.intentMatches;
    if (matches.isEmpty) return null;

    final raw = matches.first.record.category.trim();
    if (raw.isEmpty) return null;

    return raw.replaceAll('_', ' ').toLowerCase();
  }
}

extension _MindAidMessageModelMapper on MindAidMessage {
  MindAidMessageModel toModel({required String conversationId}) {
    return MindAidMessageModel(
      id: id,
      conversationId: conversationId,
      sender: sender == MindAidSender.user ? 'user' : 'assistant',
      text: text,
      createdAt: createdAt,
      status: status ?? '',
    );
  }
}
