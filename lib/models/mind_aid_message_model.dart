class MindAidMessageModel {
  final String id;
  final String conversationId;
  final String sender; // user | bot
  final String text;
  final DateTime createdAt;
  final String status;

  MindAidMessageModel({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.text,
    required this.createdAt,
    required this.status,
  });

  factory MindAidMessageModel.fromMap(Map<String, dynamic> map) {
    return MindAidMessageModel(
      id: map['id'],
      conversationId: map['conversationId'],
      sender: map['sender'],
      text: map['text'],
      createdAt: DateTime.parse(map['createdAt']),
      status: map['status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'sender': sender,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
    };
  }
}
