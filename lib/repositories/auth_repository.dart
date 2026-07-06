import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../database/firestore_collections.dart';
import '../features/quick_assessment/models/quick_assessment_models.dart';
import '../services/auth/auth_service.dart';
import '../services/firebase/firestore_service.dart';

class AuthRepository {
  AuthRepository(this._authService, {FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final AuthService _authService;
  final FirestoreService _firestoreService;

  String? get currentUserId => _authService.currentUser?.uid;
  String? get currentUserEmail => _authService.currentUser?.email;

  static const _authEmailDomain = 'mindmate.local';

  static String authEmailForSchoolId(String schoolId) {
    final normalized = schoolId
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
        .replaceAll(RegExp(r'\.+'), '.')
        .replaceAll(RegExp(r'^\.|\.$'), '');
    final localPart = normalized.isEmpty ? 'user' : normalized;
    return '$localPart@$_authEmailDomain';
  }

  Future<UserCredential> signIn({
    required String schoolId,
    required String password,
  }) {
    return _authService.signIn(
      email: authEmailForSchoolId(schoolId),
      password: password,
    );
  }

  Future<UserCredential> signUp({
    required String password,
    required String firstName,
    required String lastName,
    required String schoolId,
    required String department,
    required String course,
    String? sector,
    String? middleName,
    AssessmentRole? role,
  }) async {
    final authEmail = authEmailForSchoolId(schoolId);
    final credential = await _authService.signUp(
      email: authEmail,
      password: password,
    );
    final user = credential.user;

    if (user != null) {
      try {
        await _firestoreService.setDocument(
          FirestoreCollections.users,
          user.uid,
          {
            'id': user.uid,
            'email': authEmail,
            'firstName': firstName.trim(),
            'middleName': middleName?.trim() ?? '',
            'lastName': lastName.trim(),
            'name': [
              firstName.trim(),
              if ((middleName ?? '').trim().isNotEmpty) middleName!.trim(),
              lastName.trim(),
            ].join(' '),
            'schoolId': schoolId.trim(),
            'department': department.trim(),
            'course': course.trim(),
            'sector': sector?.trim() ?? '',
            if (role != null) 'role': role.name,
            'dayStreak': 0,
            'longestStreak': 0,
            'lastActivityDateKey': '',
            'activeDateKeys': <String>[],
            'avatarAssetName': '',
            'lastActiveAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      } catch (error, stackTrace) {
        developer.log(
          'User profile sync failed after signup.',
          name: 'AuthRepository',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return credential;
  }

  Future<void> signOut() {
    return _authService.signOut();
  }
}
