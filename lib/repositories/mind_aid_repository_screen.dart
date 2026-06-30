import '../features/mind_aid/ai_engine/mind_aid_chat_engine.dart';
import '../features/mind_aid/ai_engine/mind_aid_engine.dart';
import '../features/mind_aid/data/mind_aid_dataset_loader.dart';
import '../features/mind_aid/domain/mind_aid_chat_models.dart';
import '../features/mind_aid/domain/mind_aid_context.dart';
import '../features/mind_aid/domain/mind_aid_engine_result.dart';
import '../models/mind_aid_message_model.dart';
import '../models/mind_aid_suggestion_model.dart';

class MindAidSendResult {
  const MindAidSendResult({
    required this.message,
    required this.suggestions,
    required this.chatResponse,
  });

  final MindAidMessageModel message;
  final List<MindAidSuggestionModel> suggestions;
  final MindAidChatResponse chatResponse;
}

class MindAidRepository {
  MindAidRepository({
    MindAidDatasetLoader? datasetLoader,
    MindAidEngine? engine,
    MindAidChatEngine? chatEngine,
  }) : _datasetLoader = datasetLoader ?? MindAidDatasetLoader(),
       _engine = engine ?? MindAidEngine(),
       _chatEngine = chatEngine ?? MindAidChatEngine();

  final MindAidDatasetLoader _datasetLoader;
  final MindAidEngine _engine;
  final MindAidChatEngine _chatEngine;

  Future<List<MindAidMessageModel>> fetchMessages(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return [];
  }

  Future<MindAidSendResult> sendMessage({
    required String userId,
    required String text,
    List<MindAidMessageModel> recentMessages = const [],
    MindAidContext context = const MindAidContext(),
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));

    final dataset = await _datasetLoader.load();
    final result = await _chatEngine.respond(
      MindAidChatRequest(
        userId: userId,
        text: text,
        recentMessages: recentMessages,
        moodLevel: context.moodLevel,
        assessmentScore: context.effectiveAssessmentScore,
        assessment: context.assessment,
        conversationSummary: context.conversationSummary,
        preferredSupportStyle: context.preferredSupportStyle,
        journalText: context.journalText,
      ),
      dataset,
    );

    final message = MindAidMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: userId,
      sender: 'assistant',
      text: result.text,
      createdAt: DateTime.now(),
      status: result.status,
    );

    return MindAidSendResult(
      message: message,
      suggestions: result.suggestions,
      chatResponse: result,
    );
  }

  Future<MindAidEngineResult> analyzeMessage({
    required String text,
    MindAidContext context = const MindAidContext(),
  }) async {
    final dataset = await _datasetLoader.load();
    return _engine.process(text, dataset, context: context);
  }

  Future<List<MindAidSuggestionModel>> fetchSuggestions() async {
    final dataset = await _datasetLoader.load();
    return dataset.suggestions;
  }
}
