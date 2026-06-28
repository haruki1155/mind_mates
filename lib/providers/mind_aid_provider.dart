import 'package:flutter/material.dart';

import '/features/counseling/screens/mind_aid_screen.dart';
import '/models/mind_aid_message_model.dart';
import '/repositories/mind_aid_repository_screen.dart';

class MindAidProvider extends ChangeNotifier {
  final MindAidRepository repository;

  MindAidProvider(this.repository);

  List<MindAidMessage> messages = [];
  List<MindAidSuggestion> suggestions = [];

  bool isLoading = false;
  bool isSending = false;
  String? errorMessage;

  Future<void> loadChat(String userId) async {
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
            ),
          )
          .toList();

      suggestions = sugResult
          .map(
            (e) => MindAidSuggestion(
              id: e.id,
              label: e.label,
              iconAsset: e.iconAsset,
            ),
          )
          .toList();
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> sendMessage(String userId, String text) async {
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
      );
      final bot = result.message;

      final botMessage = MindAidMessage(
        id: bot.id,
        sender: MindAidSender.assistant,
        text: bot.text,
        createdAt: bot.createdAt,
        status: bot.status,
      );

      messages.add(botMessage);
      suggestions = result.suggestions
          .map(
            (suggestion) => MindAidSuggestion(
              id: suggestion.id,
              label: suggestion.label,
              iconAsset: suggestion.iconAsset,
            ),
          )
          .toList(growable: false);
    } catch (e) {
      errorMessage = e.toString();
    }

    isSending = false;
    notifyListeners();
  }

  void selectSuggestion(MindAidSuggestion suggestion, String userId) {
    sendMessage(userId, suggestion.label);
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
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
