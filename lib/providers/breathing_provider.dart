import 'package:flutter/foundation.dart';

import '../features/breathing/models/breathing_models.dart';
import '../repositories/breathing_repository.dart';

class BreathingProvider extends ChangeNotifier {
  BreathingProvider(this._repository);

  final BreathingRepository _repository;

  bool _isSaving = false;
  String? _errorMessage;

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<bool> startSession({
    required String userId,
    required String sessionId,
    required BreathingTechnique technique,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (userId.trim().isEmpty) throw StateError('Sign in is required.');
      await _repository.startSession(
        BreathingSessionRecord(sessionId: sessionId, technique: technique),
      );
      return true;
    } catch (_) {
      _errorMessage =
          'Unable to start the breathing session. Check your connection and try again.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> completeSession({
    required String userId,
    required String sessionId,
    required BreathingTechnique technique,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.completeSession(
        BreathingSessionRecord(sessionId: sessionId, technique: technique),
      );
      return true;
    } catch (_) {
      _errorMessage = 'Unable to save breathing session.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
