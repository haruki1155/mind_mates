import '../core/utils/firestore_mapper.dart';

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.appointmentId,
    this.readAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final String? appointmentId;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory AppNotificationModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
  }) => AppNotificationModel(
    id: (json['id'] ?? id ?? '').toString(),
    userId: json['userId']?.toString() ?? '',
    title: json['title']?.toString() ?? 'MindMate update',
    body: json['body']?.toString() ?? '',
    type: json['type']?.toString() ?? 'general',
    appointmentId: _text(json['appointmentId']),
    createdAt: dateTimeFromFirestoreOrNow(json['createdAt']),
    readAt: dateTimeFromFirestore(json['readAt']),
  );

  static String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
