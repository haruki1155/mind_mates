import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({this.firebaseAuth});

  final FirebaseAuth? firebaseAuth;

  FirebaseAuth get _instance => firebaseAuth ?? FirebaseAuth.instance;

  User? get currentUser => _instance.currentUser;
  Stream<User?> get authStateChanges => _instance.authStateChanges();

  Future<User?> restoreCurrentUser({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final existing = _instance.currentUser;
    if (existing != null) return existing;
    try {
      return await _instance.authStateChanges().first.timeout(timeout);
    } on TimeoutException {
      return _instance.currentUser;
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() {
    return _instance.signOut();
  }
}
