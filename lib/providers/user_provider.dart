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

  Future<void> recordActivity(
    String uid,
    UserActivityType type, {
    DateTime? occurredAt,
  }) async {
    try {
      final updatedUser = await _repository.recordActivity(
        uid,
        type,
        occurredAt: occurredAt,
      );
      final current = _user;
      if (updatedUser != null) {
        _user = current == null
            ? updatedUser
            : current.copyWith(
                dayStreak: updatedUser.dayStreak,
                longestStreak: updatedUser.longestStreak,
                lastActivityDateKey: updatedUser.lastActivityDateKey,
                lastActiveAt: updatedUser.lastActiveAt,
                activeDateKeys: updatedUser.activeDateKeys,
              );
        notifyListeners();
      }
    } catch (_) {
      // Streak sync should never block the user from completing an action.
    }
  }

  Future<void> markActivity(String uid) {
    return recordActivity(uid, UserActivityType.quickAssessment);
  }

  Future<void> markQuickAssessment(String uid) {
    return recordActivity(uid, UserActivityType.quickAssessment);
  }

  Future<void> markFullAssessment(String uid) {
    return recordActivity(uid, UserActivityType.fullAssessment);
  }

  Future<void> markMindAidMessage(String uid) {
    return recordActivity(uid, UserActivityType.mindAidMessage);
  }

  Future<void> markMoodCheckIn(String uid) {
    return recordActivity(uid, UserActivityType.moodCheckIn);
  }

  Future<void> markJournalEntry(String uid) {
    return recordActivity(uid, UserActivityType.journalEntry);
  }

  Future<void> markBreathingSession(String uid) {
    return recordActivity(uid, UserActivityType.breathingSession);
  }

  Future<void> markSecretChatPost(String uid) {
    return recordActivity(uid, UserActivityType.secretChatPost);
  }

  Future<void> markSecretChatComment(String uid) {
    return recordActivity(uid, UserActivityType.secretChatComment);
  }
}
