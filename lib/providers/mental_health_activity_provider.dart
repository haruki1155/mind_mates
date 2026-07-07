import 'package:flutter/foundation.dart';

import '../models/mental_health_activity_summary.dart';
import '../repositories/mental_health_activity_repository.dart';

class MentalHealthActivityProvider extends ChangeNotifier {
  MentalHealthActivityProvider(this._repository);

  final MentalHealthActivityRepository _repository;

  MentalHealthActivitySummary? _summary;
  bool _isLoading = false;
  String? _errorMessage;

  MentalHealthActivitySummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadDailySummary(String userId, {DateTime? date}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summary = await _repository.fetchDailySummary(userId, date: date);
    } catch (error, stackTrace) {
      debugPrint('Unable to load daily mental health activity: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'Unable to load today\'s activity.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
