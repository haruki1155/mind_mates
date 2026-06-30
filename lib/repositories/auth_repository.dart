import 'dart:developer' as developer;

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

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _authService.signIn(email: email, password: password);
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String schoolId,
    required String department,
    String? middleName,
    AssessmentRole? role,
  }) async {
    final credential = await _authService.signUp(
      email: email,
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
            'email': email.trim(),
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
            if (role != null) 'role': role.name,
            'dayStreak': 0,
            'avatarAssetName': '',
            'createdAt': DateTime.now().toIso8601String(),
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
