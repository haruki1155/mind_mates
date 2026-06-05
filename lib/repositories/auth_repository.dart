import '../services/auth/auth_service.dart';

class AuthRepository {
  const AuthRepository(this._authService);

  final AuthService _authService;

  Future<void> signIn({required String email, required String password}) {
    return _authService.signIn(email: email, password: password);
  }
}
