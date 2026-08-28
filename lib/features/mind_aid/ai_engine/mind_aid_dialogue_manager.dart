import '../domain/mind_aid_chat_models.dart';
import '../domain/mind_aid_safety.dart';
import 'mind_aid_small_talk.dart';

enum MindAidDialogueAction { answer, clarify, followUp, smallTalk, escalate }

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
    required MindAidSafetyLevel safetyLevel,
    MindAidIntentMatch? activeFollowUpMatch,
  }) {
    if (safetyLevel.blocksCloud) {
      return MindAidDialogueDecision(
        action: MindAidDialogueAction.escalate,
        matches: matches
            .where(
              (match) =>
                  match.requiresEscalation ||
                  match.record.severity.name == 'high' ||
                  match.record.severity.name == 'crisis',
            )
            .take(1)
            .toList(growable: false),
        reason: 'safety_override',
      );
    }

    final smallTalk = MindAidSmallTalk.classify(normalizedInput);
    if (smallTalk != null) {
      return MindAidDialogueDecision(
        action: MindAidDialogueAction.smallTalk,
        matches: const [],
        reason: smallTalk.name,
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
