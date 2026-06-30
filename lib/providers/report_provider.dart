import 'package:flutter/foundation.dart';

import '../models/report_model.dart';
import '../repositories/report_repository.dart';

class ReportProvider extends ChangeNotifier {
  ReportProvider(this._repository);

  final ReportRepository _repository;

  ReportModel? _latestReport;
  bool _isLoading = false;
  String? _errorMessage;

  ReportModel? get latestReport => _latestReport;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadLatestReport(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _latestReport = await _repository.fetchLatestReport(userId);
    } catch (_) {
      _errorMessage = 'Unable to load mental health summary.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensureWeeklyPlaceholder(String userId) async {
    if (_latestReport != null) return;

    try {
      await _repository.createPlaceholderWeeklyReport(userId);
      await loadLatestReport(userId);
    } catch (_) {
      _errorMessage = 'Unable to prepare mental health summary.';
      notifyListeners();
    }
  }
}
