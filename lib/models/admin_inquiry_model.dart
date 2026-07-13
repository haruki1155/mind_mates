import '../core/utils/firestore_mapper.dart';

enum InquiryStatus {
  pending,
  inProgress,
  resolved;

  String get storedValue => switch (this) {
    InquiryStatus.pending => 'pending',
    InquiryStatus.inProgress => 'in_progress',
    InquiryStatus.resolved => 'resolved',
  };

  String get label => switch (this) {
    InquiryStatus.pending => 'Pending',
    InquiryStatus.inProgress => 'In Progress',
    InquiryStatus.resolved => 'Resolved',
  };

  static InquiryStatus fromValue(Object? value) =>
      switch (value?.toString().toLowerCase().replaceAll(' ', '_')) {
        'resolved' => InquiryStatus.resolved,
        'in_progress' || 'inprogress' => InquiryStatus.inProgress,
        _ => InquiryStatus.pending,
      };
}

class AdminInquiryModel {
  const AdminInquiryModel({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    required this.category,
    required this.email,
    required this.createdAt,
    required this.status,
    this.name,
    this.role,
  });

  final String id;
  final String userId;
  final String subject;
  final String message;
  final String category;
  final String email;
  final DateTime createdAt;
  final InquiryStatus status;
  final String? name;
  final String? role;

  String get displayName =>
      (name ?? '').trim().isNotEmpty ? name!.trim() : email;

  factory AdminInquiryModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return AdminInquiryModel(
      id: (json['id'] ?? id ?? '').toString(),
      userId: json['userId']?.toString() ?? '',
      subject: json['subject']?.toString() ?? 'Untitled inquiry',
      message: json['message']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      email: json['email']?.toString() ?? '',
      name: _optional(json['name']),
      role: _optional(json['role']),
      createdAt: dateTimeFromFirestoreOrNow(json['createdAt']),
      status: InquiryStatus.fromValue(json['status']),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'subject': subject,
    'message': message,
    'category': category,
    'email': email,
    'name': name ?? '',
    'role': role ?? '',
    'status': status.storedValue,
    'createdAt': createdAt,
  };

  static String? _optional(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
