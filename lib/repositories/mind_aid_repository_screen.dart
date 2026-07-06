import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../features/mind_aid/ai_engine/mind_aid_chat_engine.dart';
import '../features/mind_aid/ai_engine/mind_aid_engine.dart';
import '../features/mind_aid/data/mind_aid_dataset_loader.dart';
import '../features/mind_aid/domain/mind_aid_chat_models.dart';
import '../features/mind_aid/domain/mind_aid_context.dart';
import '../features/mind_aid/domain/mind_aid_engine_result.dart';
import '../models/mind_aid_message_model.dart';
import '../models/mind_aid_suggestion_model.dart';
import '../services/firebase/firestore_service.dart';

class MindAidSendResult {
  const MindAidSendResult({
    required this.message,
    required this.suggestions,
    required this.chatResponse,
    required this.userMessageSaved,
  });

  final MindAidMessageModel message;
  final List<MindAidSuggestionModel> suggestions;
  final MindAidChatResponse chatResponse;
  final bool userMessageSaved;
}

class MindAidRepository {
  MindAidRepository({
    MindAidDatasetLoader? datasetLoader,
    MindAidEngine? engine,
    MindAidChatEngine? chatEngine,
    FirestoreService? firestoreService,
  }) : _datasetLoader = datasetLoader ?? MindAidDatasetLoader(),
       _engine = engine ?? MindAidEngine(),
       _chatEngine = chatEngine ?? MindAidChatEngine(),
       _firestoreService = firestoreService ?? FirestoreService();

  final MindAidDatasetLoader _datasetLoader;
  final MindAidEngine _engine;
  final MindAidChatEngine _chatEngine;
  final FirestoreService _firestoreService;

  Future<List<MindAidMessageModel>> fetchMessages(String userId) async {
    try {
      final docs = await _firestoreService.getDocuments(
        FirestoreCollections.mindAidMessages,
        whereEquals: {'userId': userId},
        orderBy: 'createdAt',
        descending: false,
        limit: 50,
      );
      return docs
          .map((doc) => MindAidMessageModel.fromMap(doc))
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  Future<MindAidSendResult> sendMessage({
    required String userId,
    required String text,
    List<MindAidMessageModel> recentMessages = const [],
    MindAidContext context = const MindAidContext(),
  }) async {
    final dataset = await _datasetLoader.load();
    final userMessageSaved = await _trySaveMessage(
      userId: userId,
      message: MindAidMessageModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        conversationId: userId,
        sender: 'user',
        text: text,
        createdAt: DateTime.now(),
        status: 'sent',
      ),
    );

    final result = await _chatEngine.respond(
      MindAidChatRequest(
        userId: userId,
        text: text,
        recentMessages: recentMessages,
        moodLevel: context.moodLevel,
        assessmentScore: context.effectiveAssessmentScore,
        quickAssessment: context.quickAssessment,
        assessment: context.assessment,
        conversationSummary: context.conversationSummary,
        preferredSupportStyle: context.preferredSupportStyle,
        journalText: context.journalText,
        wellnessSnapshot: context.wellnessSnapshot,
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
      safetyLevel: result.safetyLevel.name,
      primaryIntent: result.primaryIntent,
      requiresEscalation: result.requiresEscalation,
    );

    await _trySaveMessage(userId: userId, message: message);

    return MindAidSendResult(
      message: message,
      suggestions: result.suggestions,
      chatResponse: result,
      userMessageSaved: userMessageSaved,
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

  Future<void> _saveMessage({
    required String userId,
    required MindAidMessageModel message,
  }) {
    return _firestoreService.createDocument(
      FirestoreCollections.mindAidMessages,
      {
        'userId': userId,
        ...message.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<bool> _trySaveMessage({
    required String userId,
    required MindAidMessageModel message,
  }) async {
    try {
      await _saveMessage(userId: userId, message: message);
      return true;
    } catch (_) {
      // Chat support remains available even while backend persistence is being
      // configured.
      return false;
    }
  }
}
