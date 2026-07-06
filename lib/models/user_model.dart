import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/quick_assessment/models/quick_assessment_models.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.firstName,
    this.middleName,
    this.lastName,
    this.schoolId,
    this.department,
    this.course,
    this.role,
    this.createdAt,
    this.dayStreak = 0,
    this.longestStreak = 0,
    this.lastActivityDateKey,
    this.lastActiveAt,
    this.activeDateKeys = const [],
    this.avatarAssetName,
  });

  final String id;
  final String email;
  final String? name;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? schoolId;
  final String? department;
  final String? course;
  final String? role;
  final DateTime? createdAt;
  final int dayStreak;
  final int longestStreak;
  final String? lastActivityDateKey;
  final DateTime? lastActiveAt;
  final List<String> activeDateKeys;
  final String? avatarAssetName;

  String get displayName {
    final parts =
        [
              firstName,
              if ((middleName ?? '').trim().isNotEmpty) middleName,
              lastName,
            ]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();

    if (parts.isNotEmpty) return parts.join(' ');
    if ((name ?? '').trim().isNotEmpty) return name!.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return 'MindMate User';
  }

  String get roleLabel {
    return AssessmentRole.fromStoredValue(role)?.label ?? 'User';
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? firstName,
    String? middleName,
    String? lastName,
    String? schoolId,
    String? department,
    String? course,
    String? role,
    DateTime? createdAt,
    int? dayStreak,
    int? longestStreak,
    String? lastActivityDateKey,
    DateTime? lastActiveAt,
    List<String>? activeDateKeys,
    String? avatarAssetName,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      schoolId: schoolId ?? this.schoolId,
      department: department ?? this.department,
      course: course ?? this.course,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      dayStreak: dayStreak ?? this.dayStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityDateKey: lastActivityDateKey ?? this.lastActivityDateKey,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      activeDateKeys: activeDateKeys ?? this.activeDateKeys,
      avatarAssetName: avatarAssetName ?? this.avatarAssetName,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return UserModel(
      id: (json['id'] ?? id ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: _stringOrNull(json['name']),
      firstName: _stringOrNull(json['firstName']),
      middleName: _stringOrNull(json['middleName']),
      lastName: _stringOrNull(json['lastName']),
      schoolId: _stringOrNull(json['schoolId']),
      department: _stringOrNull(json['department']),
      course: _stringOrNull(json['course']),
      role: _stringOrNull(json['role']),
      createdAt: _dateOrNull(json['createdAt']),
      dayStreak: _intOrZero(json['dayStreak']),
      longestStreak: _intOrZero(json['longestStreak']),
      lastActivityDateKey: _stringOrNull(json['lastActivityDateKey']),
      lastActiveAt: _dateOrNull(json['lastActiveAt']),
      activeDateKeys: _stringList(json['activeDateKeys']),
      avatarAssetName: _stringOrNull(json['avatarAssetName']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': displayName,
      'firstName': firstName ?? '',
      'middleName': middleName ?? '',
      'lastName': lastName ?? '',
      'schoolId': schoolId ?? '',
      'department': department ?? '',
      'course': course ?? '',
      'role': role ?? '',
      'createdAt': createdAt?.toIso8601String(),
      'dayStreak': dayStreak,
      'longestStreak': longestStreak,
      'lastActivityDateKey': lastActivityDateKey ?? '',
      'lastActiveAt': lastActiveAt?.toIso8601String(),
      'activeDateKeys': activeDateKeys,
      'avatarAssetName': avatarAssetName ?? '',
    };
  }

  Map<String, dynamic> toProfileUpdateJson() {
    return {
      'name': displayName,
      'firstName': firstName?.trim() ?? '',
      'middleName': middleName?.trim() ?? '',
      'lastName': lastName?.trim() ?? '',
      'schoolId': schoolId?.trim() ?? '',
      'department': department?.trim() ?? '',
      'course': course?.trim() ?? '',
      'role': role?.trim() ?? '',
      'avatarAssetName': avatarAssetName?.trim() ?? '',
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) return null;
    final text = value.toString();
    return text.trim().isEmpty ? null : text;
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }

  static int _intOrZero(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
  }
}
