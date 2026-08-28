import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firebase/firebase_app_check_service.dart';
import '../firebase/firebase_callable_router.dart';

abstract interface class RecoveryService {
  Future<void> requestPasswordRecovery(String schoolId);

  Future<void> requestRecoveryEmailVerification(String email);

  Future<void> confirmRecoveryEmailVerification(String token);

  Future<void> confirmPasswordRecovery({
    required String token,
    required String password,
  });
}

class FirebaseRecoveryService implements RecoveryService {
  FirebaseRecoveryService({this.firebaseAuth});

  final FirebaseAuth? firebaseAuth;

  FirebaseAuth get _auth => firebaseAuth ?? FirebaseAuth.instance;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  Future<void> requestPasswordRecovery(String schoolId) async {
    await FirebaseAppCheckService.requireToken();
    await FirebaseCallableRouter.callable(_functions, 'requestPasswordRecovery').call({
      'schoolId': schoolId,
    });
  }

  @override
  Future<void> requestRecoveryEmailVerification(String email) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before configuring account recovery.');
    }
    await user.getIdToken(true);
    await FirebaseAppCheckService.requireToken();
    await FirebaseCallableRouter.callable(_functions, 'requestRecoveryEmailVerification').call({
      'email': email,
    });
  }

  @override
  Future<void> confirmRecoveryEmailVerification(String token) async {
    await FirebaseAppCheckService.requireToken();
    await FirebaseCallableRouter.callable(_functions, 'confirmRecoveryEmailVerification').call({
      'token': token,
    });
  }

  @override
  Future<void> confirmPasswordRecovery({
    required String token,
    required String password,
  }) async {
    await FirebaseAppCheckService.requireToken();
    await FirebaseCallableRouter.callable(_functions, 'confirmPasswordRecovery').call({
      'token': token,
      'password': password,
    });
  }
}
