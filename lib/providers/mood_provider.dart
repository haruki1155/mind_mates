import 'package:flutter/foundation.dart';

import '../models/mood_model.dart';
import '../repositories/mood_repository.dart';

class MoodProvider extends ChangeNotifier {
  MoodProvider(this._repository);

  final MoodRepository _repository;

  List<MoodModel> _moods = [];
  bool _isLoading = false;
  bool _isLoadingToday = false;
  String? _errorMessage;
  MoodModel? _todayMood;
  DailyMoodSaveResult? _dailySaveResult;

  List<MoodModel> get moods => List.unmodifiable(_moods);
  bool get isLoading => _isLoading;
  bool get isLoadingToday => _isLoadingToday;
  String? get errorMessage => _errorMessage;
  MoodModel? get todayMood => _todayMood;
  bool get hasCheckedInToday => _todayMood != null;
  DailyMoodSaveResult? get dailySaveResult => _dailySaveResult;

  Future<void> loadRecentMoods(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _moods = await _repository.fetchRecentMoods(userId);
      if (_todayMood == null || !_matchesToday(_todayMood!)) {
        _todayMood = _moodForToday(_moods);
      }
    } catch (error) {
      _errorMessage = 'Unable to load moods.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTodayMood(String userId, {DateTime? now}) async {
    _isLoadingToday = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _todayMood = await _repository.fetchTodayMood(userId, now: now);
      if (_todayMood != null) _insertMood(_todayMood!);
    } catch (_) {
      _errorMessage = 'Unable to load today\'s mood.';
    } finally {
      _isLoadingToday = false;
      notifyListeners();
    }
  }

  Future<bool> logDailyMood({
    required String userId,
    required int level,
    String? label,
    String? note,
    DateTime? now,
  }) async {
    _errorMessage = null;
    try {
      final result = await _repository.saveDailyMood(
        userId: userId,
        level: level,
        label: label,
        note: note,
        now: now,
      );
      _dailySaveResult = result;
      _todayMood = result.mood;
      _insertMood(result.mood);
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Unable to save mood.';
      notifyListeners();
      return false;
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
      _todayMood = _moodForToday(_moods);
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = 'Unable to save mood.';
      notifyListeners();
      return false;
    }
  }

  void _insertMood(MoodModel mood) {
    _moods = [mood, ..._moods.where((item) => item.id != mood.id)];
  }

  MoodModel? _moodForToday(List<MoodModel> moods, {DateTime? now}) {
    final today = MoodRepository.dateKeyFor(now ?? DateTime.now());
    for (final mood in moods) {
      final key = (mood.dateKey ?? '').trim().isNotEmpty
          ? mood.dateKey
          : MoodRepository.dateKeyFor(mood.createdAt);
      if (key == today) return mood;
    }
    return null;
  }

  bool _matchesToday(MoodModel mood, {DateTime? now}) {
    final today = MoodRepository.dateKeyFor(now ?? DateTime.now());
    final key = (mood.dateKey ?? '').trim().isNotEmpty
        ? mood.dateKey
        : MoodRepository.dateKeyFor(mood.createdAt);
    return key == today;
  }
}
