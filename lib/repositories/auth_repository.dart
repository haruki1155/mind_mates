import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../database/firestore_collections.dart';
import '../features/quick_assessment/models/quick_assessment_models.dart';
import '../services/auth/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/firebase_app_check_service.dart';
import '../services/firebase/firebase_runtime_diagnostics.dart';

class AuthRepository {
  AuthRepository(this._authService, {FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final AuthService _authService;
  final FirestoreService _firestoreService;

  String? get currentUserId => _authService.currentUser?.uid;
  String? get currentUserEmail => _authService.currentUser?.email;
  Stream<String?> watchAuthenticatedUserIds() =>
      _authService.authStateChanges.map((user) => user?.uid);

  Future<String?> restoreCurrentUser() async {
    final user = await _authService.restoreCurrentUser();
    return user?.uid;
  }

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
    String? employeeId,
    String? yearLevel,
    String? position,
    String? middleName,
    AssessmentRole? role,
  }) async {
    final authEmail = authEmailForSchoolId(schoolId);
    // Avoid creating an Auth-only account when this installation cannot call
    // the App Check-enforced profile provisioning backend.
    FirebaseRuntimeDiagnostics.log(event: 'signup_app_check_preflight_started');
    try {
      await FirebaseAppCheckService.refreshToken();
      await FirebaseAppCheckService.requireToken();
      FirebaseRuntimeDiagnostics.log(
        event: 'signup_app_check_preflight_succeeded',
      );
    } catch (error, stackTrace) {
      FirebaseRuntimeDiagnostics.log(
        event: 'signup_app_check_preflight_failed',
        error: error,
        errorCode: 'app-check',
      );
      Error.throwWithStackTrace(SignupAppCheckException(error), stackTrace);
    }
    late final UserCredential credential;
    try {
      FirebaseRuntimeDiagnostics.log(event: 'signup_auth_creation_started');
      credential = await _authService.signUp(
        email: authEmail,
        password: password,
      );
      FirebaseRuntimeDiagnostics.log(event: 'signup_auth_creation_succeeded');
    } on FirebaseAuthException catch (error) {
      FirebaseRuntimeDiagnostics.log(
        event: 'signup_auth_creation_failed',
        error: error,
      );
      if (error.code != 'email-already-in-use') rethrow;

      // A previous signup may have created the Auth account before profile
      // provisioning was interrupted. Authenticate that account and repair it
      // only when its Firestore profile is genuinely missing.
      credential = await _authService.signIn(
        email: authEmail,
        password: password,
      );
      final recoveredUser = credential.user;
      Map<String, dynamic>? existingProfile;
      if (recoveredUser != null) {
        try {
          existingProfile = await _firestoreService.getDocument(
            FirestoreCollections.users,
            recoveredUser.uid,
          );
        } catch (profileError, stackTrace) {
          Error.throwWithStackTrace(
            SignupProfileLookupException(recoveredUser.uid, profileError),
            stackTrace,
          );
        }
      }
      if (existingProfile != null) {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'An account already exists for this School ID.',
        );
      }
    }
    final user = credential.user;

    if (user != null) {
      try {
        await _saveProfile(
          uid: user.uid,
          authEmail: authEmail,
          firstName: firstName,
          lastName: lastName,
          schoolId: schoolId,
          department: department,
          course: course,
          sector: sector,
          employeeId: employeeId,
          yearLevel: yearLevel,
          position: position,
          middleName: middleName,
          role: role,
        );
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          SignupProfileProvisioningException(user.uid, error),
          stackTrace,
        );
      }
    }

    return credential;
  }

  Future<String> completeProfileSetup({
    required String firstName,
    required String lastName,
    required String schoolId,
    required String department,
    required String course,
    String? sector,
    String? employeeId,
    String? yearLevel,
    String? position,
    String? middleName,
    AssessmentRole? role,
  }) async {
    final uid = currentUserId;
    final expectedEmail = authEmailForSchoolId(schoolId);
    if (uid == null || currentUserEmail != expectedEmail) {
      throw StateError('The pending signup session is no longer available.');
    }
    try {
      await _saveProfile(
        uid: uid,
        authEmail: expectedEmail,
        firstName: firstName,
        lastName: lastName,
        schoolId: schoolId,
        department: department,
        course: course,
        sector: sector,
        employeeId: employeeId,
        yearLevel: yearLevel,
        position: position,
        middleName: middleName,
        role: role,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SignupProfileProvisioningException(uid, error),
        stackTrace,
      );
    }
    return uid;
  }

  Future<void> _saveProfile({
    required String uid,
    required String authEmail,
    required String firstName,
    required String lastName,
    required String schoolId,
    required String department,
    required String course,
    String? sector,
    String? employeeId,
    String? yearLevel,
    String? position,
    String? middleName,
    AssessmentRole? role,
  }) async {
    final populationRole = role?.populationRole;
    if (populationRole == null) {
      throw StateError('Choose an account role before creating the profile.');
    }
    if (_authService.currentUser?.uid != uid) {
      throw StateError('The authenticated signup session is unavailable.');
    }
    await _authService.currentUser!.getIdToken(true);
    await FirebaseAppCheckService.refreshToken();
    await FirebaseAppCheckService.requireToken();
    final response = await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('provisionAppUserProfile')
        .call({
          'firstName': firstName.trim(),
          'middleName': middleName?.trim() ?? '',
          'lastName': lastName.trim(),
          'name': [
            firstName.trim(),
            if ((middleName ?? '').trim().isNotEmpty) middleName!.trim(),
            lastName.trim(),
          ].join(' '),
          'employeeId': employeeId?.trim() ?? '',
          'department': department.trim(),
          'course': course.trim(),
          'yearLevel': yearLevel?.trim() ?? '',
          'sector': sector?.trim() ?? '',
          'position': position?.trim() ?? '',
          'populationRole': populationRole.storedValue,
        });
    final responseData = response.data;
    FirebaseRuntimeDiagnostics.log(
      event: 'signup_profile_provisioned',
      correlationId: responseData is Map
          ? responseData['correlationId']?.toString()
          : null,
    );
  }

  Future<void> signOut() {
    return _authService.signOut();
  }
}

class SignupProfileProvisioningException implements Exception {
  const SignupProfileProvisioningException(this.userId, this.cause);

  final String userId;
  final Object cause;

  @override
  String toString() => 'Account created, but profile setup failed: $cause';
}

class SignupAppCheckException implements Exception {
  const SignupAppCheckException(this.cause);

  final Object cause;

  @override
  String toString() => 'Firebase App Check preflight failed (code=app-check).';
}

class SignupProfileLookupException implements Exception {
  const SignupProfileLookupException(this.userId, this.cause);

  final String userId;
  final Object cause;

  @override
  String toString() =>
      'Signed in, but the existing profile check failed: $cause';
}
