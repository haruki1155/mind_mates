import '../core/utils/firestore_mapper.dart';

class MindAidMessageModel {
  final String id;
  final String conversationId;
  final String sender; // user | assistant
  final String text;
  final DateTime createdAt;
  final String status;
  final String? safetyLevel;
  final String? primaryIntent;
  final bool requiresEscalation;

  MindAidMessageModel({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.text,
    required this.createdAt,
    required this.status,
    this.safetyLevel,
    this.primaryIntent,
    this.requiresEscalation = false,
  });

  factory MindAidMessageModel.fromMap(Map<String, dynamic> map) {
    return MindAidMessageModel(
      id: (map['id'] ?? '').toString(),
      conversationId: (map['conversationId'] ?? '').toString(),
      sender: (map['sender'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      createdAt: dateTimeFromFirestoreOrNow(map['createdAt']),
      status: (map['status'] ?? '').toString(),
      safetyLevel: map['safetyLevel']?.toString(),
      primaryIntent: map['primaryIntent']?.toString(),
      requiresEscalation: boolFromFirestore(map['requiresEscalation']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'sender': sender,
      'text': text,
      'createdAt': createdAt,
      'status': status,
      'safetyLevel': safetyLevel,
      'primaryIntent': primaryIntent,
      'requiresEscalation': requiresEscalation,
    };
  }
}
