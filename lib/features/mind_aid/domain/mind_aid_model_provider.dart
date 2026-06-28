import 'mind_aid_chat_models.dart';
import 'mind_aid_dataset_models.dart';

class MindAidModelPrompt {
  const MindAidModelPrompt({
    required this.userText,
    required this.matches,
    required this.state,
    required this.dataset,
    required this.requiresEscalation,
  });

  final String userText;
  final List<MindAidIntentMatch> matches;
  final MindAidConversationState state;
  final MindAidDatasetBundle dataset;
  final bool requiresEscalation;
}

abstract class MindAidModelProvider {
  Future<String> generate(MindAidModelPrompt prompt);
}

class LocalMindAidModelProvider implements MindAidModelProvider {
  const LocalMindAidModelProvider();

  @override
  Future<String> generate(MindAidModelPrompt prompt) async {
    return '';
  }
}
