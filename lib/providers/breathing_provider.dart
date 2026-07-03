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

  Future<bool> completeSession({
    required String userId,
    required BreathingTechnique technique,
    required int completedSeconds,
    required DateTime startedAt,
    DateTime? completedAt,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.completeSession(
        BreathingSessionRecord(
          userId: userId,
          technique: technique,
          completedSeconds: completedSeconds,
          startedAt: startedAt,
          completedAt: completedAt ?? DateTime.now(),
        ),
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
