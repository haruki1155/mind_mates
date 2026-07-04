import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({this.firebaseAuth});

  final FirebaseAuth? firebaseAuth;

  FirebaseAuth get _instance => firebaseAuth ?? FirebaseAuth.instance;

  User? get currentUser => _instance.currentUser;

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
