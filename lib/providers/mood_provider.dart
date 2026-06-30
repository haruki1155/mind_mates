import 'package:flutter/foundation.dart';

import '../models/mood_model.dart';
import '../repositories/mood_repository.dart';

class MoodProvider extends ChangeNotifier {
  MoodProvider(this._repository);

  final MoodRepository _repository;

  List<MoodModel> _moods = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<MoodModel> get moods => List.unmodifiable(_moods);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadRecentMoods(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _moods = await _repository.fetchRecentMoods(userId);
    } catch (error) {
      _errorMessage = 'Unable to load moods.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> logMood({
    required String userId,
    required int level,
    String? label,
    String? note,
  }) async {
    try {
      final id = await _repository.createMood(
        userId: userId,
        level: level,
        label: label,
        note: note,
      );
      _moods = [
        MoodModel(
          id: id,
          userId: userId,
          level: level,
          label: label,
          note: note,
          createdAt: DateTime.now(),
        ),
        ..._moods,
      ];
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = 'Unable to save mood.';
      notifyListeners();
      return false;
    }
  }
}
