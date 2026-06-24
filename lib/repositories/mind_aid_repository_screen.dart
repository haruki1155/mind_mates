import '/models/mind_aid_message_model.dart';
import '/models/mind_aid_suggestion_model.dart';

class MindAidRepository {
  Future<List<MindAidMessageModel>> fetchMessages(String userId) async {
    await Future.delayed(Duration(milliseconds: 300));

    return [];
  }

  Future<MindAidMessageModel> sendMessage({
    required String userId,
    required String text,
  }) async {
    await Future.delayed(Duration(milliseconds: 300));

    return MindAidMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: userId,
      sender: "bot",
      text: "Sample AI response",
      createdAt: DateTime.now(),
      status: "sent",
    );
  }

  Future<List<MindAidSuggestionModel>> fetchSuggestions() async {
    return [
      MindAidSuggestionModel(
        id: "1",
        label: "Stress",
        iconAsset: "assets/stress.png",
      ),
      MindAidSuggestionModel(
        id: "2",
        label: "Burnout",
        iconAsset: "assets/burnout.png",
      ),
    ];
  }
}
