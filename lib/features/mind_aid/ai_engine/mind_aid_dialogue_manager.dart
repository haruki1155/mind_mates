import '../domain/mind_aid_chat_models.dart';

enum MindAidDialogueAction { answer, clarify, followUp, escalate }

class MindAidDialogueDecision {
  const MindAidDialogueDecision({
    required this.action,
    required this.matches,
    this.reason = '',
  });

  final MindAidDialogueAction action;
  final List<MindAidIntentMatch> matches;
  final String reason;
}

class MindAidDialogueManager {
  const MindAidDialogueManager();

  MindAidDialogueDecision decide({
    required String normalizedInput,
    required List<MindAidIntentMatch> matches,
    required MindAidConversationState state,
    MindAidIntentMatch? activeFollowUpMatch,
  }) {
    final escalationMatches = matches
        .where((match) {
          return match.requiresEscalation ||
              match.record.severity.name == 'high';
        })
        .toList(growable: false);
    if (escalationMatches.isNotEmpty) {
      return MindAidDialogueDecision(
        action: MindAidDialogueAction.escalate,
        matches: [escalationMatches.first],
        reason: 'safety_override',
      );
    }

    if (_looksLikeFollowUp(normalizedInput, state) &&
        activeFollowUpMatch != null &&
        matches.isEmpty) {
      return MindAidDialogueDecision(
        action: MindAidDialogueAction.followUp,
        matches: [activeFollowUpMatch],
        reason: 'short_follow_up',
      );
    }

    if (matches.isEmpty || matches.first.confidence < 0.18) {
      return const MindAidDialogueDecision(
        action: MindAidDialogueAction.clarify,
        matches: [],
        reason: 'low_confidence',
      );
    }

    return MindAidDialogueDecision(
      action: MindAidDialogueAction.answer,
      matches: matches.take(2).toList(growable: false),
    );
  }

  bool _looksLikeFollowUp(
    String normalizedInput,
    MindAidConversationState state,
  ) {
    if (!state.awaitingFollowUp && state.activeIntent == null) return false;
    final words = normalizedInput.split(' ').where((word) => word.isNotEmpty);
    if (words.length <= 4) return true;
    return normalizedInput == 'yes' ||
        normalizedInput == 'no' ||
        normalizedInput.startsWith('yes ') ||
        normalizedInput.startsWith('no ');
  }
}
