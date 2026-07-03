import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/providers/mind_aid_provider.dart';
import '/providers/assessment_provider.dart';
import '/providers/auth_provider.dart';
import '/providers/user_provider.dart';
import '/features/counseling/screens/mind_aid_screen.dart';
import '/features/mind_aid/domain/mind_aid_context.dart';
import '/routes/route_names.dart';

class MindAidPage extends StatefulWidget {
  const MindAidPage({super.key});

  @override
  State<MindAidPage> createState() => _MindAidPageState();
}

class _MindAidPageState extends State<MindAidPage> {
  String? _loadedContextKey;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MindAidProvider>();
    final assessmentProvider = context.watch<AssessmentProvider>();
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.userId ?? 'guest';
    final mindAidContext = _buildMindAidContext(assessmentProvider);
    _loadChatWhenContextChanges(userId, mindAidContext);

    return MindAidScreen(
      messages: provider.messages,
      suggestions: provider.suggestions,
      isAssistantTyping: provider.isSending,
      onSendMessage: (text) {
        _sendAndRecordActivity(userId, text, mindAidContext);
      },
      onSuggestionSelected: (suggestion) {
        _selectSuggestionAndRecordActivity(userId, suggestion, mindAidContext);
      },
      onHomeTap: () {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
      },
      onNotificationTap: () {},
      disclaimerText: "AI assistant support only",
    );
  }

  Future<void> _sendAndRecordActivity(
    String userId,
    String text,
    MindAidContext contextValue,
  ) async {
    final sent = await context.read<MindAidProvider>().sendMessage(
      userId,
      text,
      context: contextValue,
    );
    if (!mounted || !sent || userId == 'guest') return;
    await context.read<UserProvider>().markMindAidMessage(userId);
  }

  Future<void> _selectSuggestionAndRecordActivity(
    String userId,
    MindAidSuggestion suggestion,
    MindAidContext contextValue,
  ) async {
    final sent = await context.read<MindAidProvider>().selectSuggestion(
      suggestion,
      userId,
      context: contextValue,
    );
    if (!mounted || !sent || userId == 'guest') return;
    await context.read<UserProvider>().markMindAidMessage(userId);
  }

  MindAidContext _buildMindAidContext(AssessmentProvider provider) {
    final fullResult = provider.studentResult;
    if (fullResult != null) {
      return MindAidContext(
        assessment: MindAidAssessmentContext(
          userType: fullResult.userType,
          overallScore: fullResult.overallScore,
          status: fullResult.status,
          mainConcernAreas: fullResult.mainConcernAreas,
          subscaleScores: fullResult.subscaleScores,
          summaryMessage: fullResult.message,
        ),
      );
    }

    final quickResult = provider.quickResult;
    if (quickResult != null) {
      return MindAidContext(
        quickAssessment: MindAidQuickAssessmentContext(
          score: quickResult.concernScore.round(),
          level: quickResult.overallLevel.label,
          signal: quickResult.mentalStatusSignal.name,
          summary: quickResult.summary,
          topConcernAreas: quickResult.topConcernAreas,
          recommendedNextStep: quickResult.recommendedNextStep,
          createdAt: quickResult.createdAt,
        ),
      );
    }

    return const MindAidContext();
  }

  void _loadChatWhenContextChanges(String userId, MindAidContext contextValue) {
    final key = '$userId:${_contextKey(contextValue)}';
    if (_loadedContextKey == key) return;

    _loadedContextKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MindAidProvider>().loadChat(userId, context: contextValue);
    });
  }

  String _contextKey(MindAidContext contextValue) {
    final assessment = contextValue.assessment;
    if (assessment != null) {
      final categoryKey = assessment.subscaleScores.entries
          .map((entry) => '${entry.key}:${entry.value.round()}')
          .join('|');
      return [
        'full',
        assessment.userType,
        assessment.status,
        assessment.overallScore.round(),
        assessment.mainConcernAreas.join('|'),
        categoryKey,
      ].join(':');
    }

    final quick = contextValue.quickAssessment;
    if (quick != null) {
      return [
        'quick',
        quick.score,
        quick.level,
        quick.signal,
        quick.topConcernAreas.join('|'),
      ].join(':');
    }

    return 'quick:${contextValue.assessmentScore ?? 'none'}';
  }
}
