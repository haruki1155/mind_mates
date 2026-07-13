import '../../../models/journal_model.dart';

class JournalPromptModel {
  const JournalPromptModel({
    required this.id,
    required this.mode,
    required this.question,
  });
  final String id;
  final JournalMode mode;
  final String question;
}

const journalPrompts = <JournalMode, List<JournalPromptModel>>{
  JournalMode.freeWrite: [
    JournalPromptModel(
      id: 'free_01',
      mode: JournalMode.freeWrite,
      question: 'What is on your mind?',
    ),
  ],
  JournalMode.understandFeelings: [
    JournalPromptModel(
      id: 'feel_trigger_01',
      mode: JournalMode.understandFeelings,
      question: 'What happened before you started feeling this way?',
    ),
    JournalPromptModel(
      id: 'feel_hardest_01',
      mode: JournalMode.understandFeelings,
      question: 'What part of this situation feels hardest right now?',
    ),
    JournalPromptModel(
      id: 'feel_step_01',
      mode: JournalMode.understandFeelings,
      question: 'What would make things even 1% easier?',
    ),
  ],
  JournalMode.letItOut: [
    JournalPromptModel(
      id: 'release_01',
      mode: JournalMode.letItOut,
      question:
          'Write what you are feeling. You do not have to make it sound nice.',
    ),
  ],
  JournalMode.findSomethingGood: [
    JournalPromptModel(
      id: 'good_01',
      mode: JournalMode.findSomethingGood,
      question: 'Was there one small thing today that felt okay?',
    ),
    JournalPromptModel(
      id: 'good_matter_01',
      mode: JournalMode.findSomethingGood,
      question: 'Why did that moment matter to you?',
    ),
  ],
  JournalMode.sortOutThoughts: [
    JournalPromptModel(
      id: 'thought_01',
      mode: JournalMode.sortOutThoughts,
      question: 'What is the thought that keeps coming back?',
    ),
    JournalPromptModel(
      id: 'thought_true_01',
      mode: JournalMode.sortOutThoughts,
      question: 'What is making you think this right now?',
    ),
    JournalPromptModel(
      id: 'thought_view_01',
      mode: JournalMode.sortOutThoughts,
      question: 'Could there be another possible way to see this?',
    ),
    JournalPromptModel(
      id: 'thought_step_01',
      mode: JournalMode.sortOutThoughts,
      question: 'What is one realistic thing you can do next?',
    ),
  ],
  JournalMode.reflectOnDay: [
    JournalPromptModel(
      id: 'day_energy_01',
      mode: JournalMode.reflectOnDay,
      question: 'What took most of your energy today?',
    ),
    JournalPromptModel(
      id: 'day_remember_01',
      mode: JournalMode.reflectOnDay,
      question: 'What is one moment you want to remember?',
    ),
    JournalPromptModel(
      id: 'day_need_01',
      mode: JournalMode.reflectOnDay,
      question: 'What do you need tomorrow?',
    ),
  ],
};
