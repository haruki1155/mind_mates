import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/firebase/firebase_error_message.dart';

class UserProvider extends ChangeNotifier {
  UserProvider(this._repository);

  final UserRepository _repository;

  UserModel? _user;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  void clear() {
    _user = null;
    _isLoading = false;
    _isSaving = false;
    _errorMessage = null;
    notifyListeners();
  }

  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  Future<void> loadProfile(String uid) async {
    _user = null;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetchedUser = await _repository.fetchUserProfile(uid);
      _user = fetchedUser;
    } catch (error, stackTrace) {
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Loading profile failed.',
      );
      _errorMessage = FirebaseErrorMessage.describe(
        error,
        fallback: 'Unable to load profile.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(UserModel updatedUser) async {
    final previous = _user;
    _user = updatedUser;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateUserProfile(updatedUser.id, updatedUser);
      return true;
    } catch (error, stackTrace) {
      _user = previous;
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Updating profile failed.',
      );
      _errorMessage = FirebaseErrorMessage.describe(
        error,
        fallback: 'Unable to update profile.',
      );
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> recordAppOpen(String uid) async {
    try {
      final updatedUser = await _repository.recordAppOpen(uid);
      if (updatedUser != null) {
        _user = updatedUser;
        notifyListeners();
      }
    } catch (_) {
      // Analytics must not prevent the Home screen from loading.
    }
  }
}
