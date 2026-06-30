import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.role,
    this.createdAt,
    this.dayStreak = 0,
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
  final String? role;
  final DateTime? createdAt;
  final int dayStreak;
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
    switch ((role ?? '').trim().toLowerCase()) {
      case 'student':
        return 'Student';
      case 'faculty':
        return 'Faculty';
      case 'staff':
        return 'Staff';
      default:
        return 'User';
    }
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
    String? role,
    DateTime? createdAt,
    int? dayStreak,
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
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      dayStreak: dayStreak ?? this.dayStreak,
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
      role: _stringOrNull(json['role']),
      createdAt: _dateOrNull(json['createdAt']),
      dayStreak: _intOrZero(json['dayStreak']),
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
      'role': role ?? '',
      'createdAt': createdAt?.toIso8601String(),
      'dayStreak': dayStreak,
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
}
