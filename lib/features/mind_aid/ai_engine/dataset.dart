import '../models/mind_aid_dataset.dart';

final List<MindAidDataset> mindAidDataset = [
  MindAidDataset(
    intent: "academic_stress",
    keywords: ["school", "exam", "homework", "deadline", "study"],
    responses: [
      "You are under pressure from school tasks. Focus on one step first.",
      "Break tasks into smaller parts. Start simple.",
      "Do one task only. Progress matters more than speed.",
    ],
  ),

  MindAidDataset(
    intent: "burnout",
    keywords: ["tired", "exhausted", "burnout", "drained"],
    responses: [
      "You feel exhausted. Rest is part of recovery.",
      "Your mind needs pause, not more pressure.",
      "Slow down. Recovery improves clarity.",
    ],
  ),

  MindAidDataset(
    intent: "loneliness",
    keywords: ["alone", "lonely", "no friends", "isolated"],
    responses: [
      "Feeling alone is heavy. Small connection helps.",
      "You are not invisible. Connection matters.",
      "Reach out to one person you trust.",
    ],
  ),

  MindAidDataset(
    intent: "anxiety",
    keywords: ["anxious", "worried", "panic", "nervous"],
    responses: [
      "Slow your thoughts. Focus on what you control.",
      "Anxiety grows from uncertainty. Ground yourself.",
      "Breathe slowly. One thought at a time.",
    ],
  ),
];
