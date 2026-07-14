import 'package:flutter/foundation.dart';

import '../features/quick_assessment/models/quick_assessment_models.dart';
import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository);

  final AuthRepository _repository;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _userId;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get userId => _userId ?? _repository.currentUserId;
  String? get currentUserEmail => _repository.currentUserEmail;
  String? get errorMessage => _errorMessage;

  String? hydrateCurrentUser() {
    final id = _repository.currentUserId;
    if (id == null || id.isEmpty) return null;

    _userId = id;
    _isAuthenticated = true;
    notifyListeners();
    return id;
  }

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    notifyListeners();
  }

  Future<String?> signIn({
    required String schoolId,
    required String password,
  }) async {
    return _runAuthAction(() async {
      final credential = await _repository.signIn(
        schoolId: schoolId,
        password: password,
      );
      return credential.user?.uid ?? _repository.currentUserId;
    });
  }

  Future<String?> signUp({
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
    return _runAuthAction(() async {
      final credential = await _repository.signUp(
        password: password,
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
      return credential.user?.uid ?? _repository.currentUserId;
    });
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _isAuthenticated = false;
    _userId = null;
    notifyListeners();
  }

  Future<String?> _runAuthAction(Future<String?> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final id = await action();
      if (id == null || id.isEmpty) {
        throw StateError('Unable to identify authenticated user.');
      }

      _userId = id;
      _isAuthenticated = true;
      return id;
    } catch (error) {
      _isAuthenticated = false;
      _userId = null;
      _errorMessage = _friendlyError(error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('invalid-credential') ||
        message.contains('wrong-password') ||
        message.contains('user-not-found')) {
      return 'School ID or password is incorrect.';
    }
    if (message.contains('email-already-in-use')) {
      return 'An account already exists for this School ID.';
    }
    if (message.contains('weak-password')) {
      return 'Password should be at least 6 characters.';
    }
    if (message.contains('invalid-email')) {
      return 'Enter a valid School ID.';
    }
    return 'Something went wrong. Please try again.';
  }
}
