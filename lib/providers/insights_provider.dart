import 'package:flutter/foundation.dart';

import '../features/insights/models/insights_models.dart';
import '../repositories/insights_repository.dart';

class InsightsProvider extends ChangeNotifier {
  InsightsProvider(this._repository);

  final InsightsRepository _repository;

  InsightsDashboardData? _data;
  String? _loadedUserId;
  bool _isLoading = false;
  String? _errorMessage;

  InsightsDashboardData? get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadInsights(String userId, {bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (!forceRefresh && _data != null && _loadedUserId == userId) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _data = await _repository.fetchInsights(userId);
      _loadedUserId = userId;
    } catch (_) {
      _errorMessage = 'Unable to load insights.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
