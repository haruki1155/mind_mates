import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../repositories/user_repository.dart';

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

  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  Future<void> loadProfile(String uid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetchedUser = await _repository.fetchUserProfile(uid);
      if (fetchedUser != null) {
        _user = fetchedUser;
      }
    } catch (error) {
      _errorMessage = 'Unable to load profile.';
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
    } catch (error) {
      _user = previous;
      _errorMessage = 'Unable to update profile.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
