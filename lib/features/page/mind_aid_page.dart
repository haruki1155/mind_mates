import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/providers/mind_aid_provider.dart';
import '/providers/assessment_provider.dart';
import '/providers/auth_provider.dart';
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
        provider.sendMessage(userId, text, context: mindAidContext);
      },
      onSuggestionSelected: (suggestion) {
        provider.selectSuggestion(suggestion, userId, context: mindAidContext);
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
      return MindAidContext(assessmentScore: quickResult.concernScore.round());
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

    return 'quick:${contextValue.assessmentScore ?? 'none'}';
  }
}
