import 'package:flutter/foundation.dart';

import '../features/insights/models/insights_models.dart';
import '../repositories/insights_repository.dart';

class InsightsProvider extends ChangeNotifier {
  InsightsProvider(this._repository);

  final InsightsRepository _repository;

  InsightsDashboardData? _data;
  bool _isLoading = false;
  String? _errorMessage;

  InsightsDashboardData? get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadInsights() async {
    if (_isLoading || _data != null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _data = await _repository.fetchInsights();
    } catch (_) {
      _errorMessage = 'Unable to load insights.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
