import 'package:flutter/foundation.dart';

import '../features/sleep/models/sleep_models.dart';
import '../repositories/sleep_repository.dart';

class SleepProvider extends ChangeNotifier {
  SleepProvider(this._repository);

  final SleepRepository _repository;
  List<SleepEntry> _entries = const [];
  SleepConsent? _consent;
  SleepSyncState _syncState = SleepSyncState.idle;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _loadedUserId;

  List<SleepEntry> get entries => List.unmodifiable(_entries);
  SleepConsent? get consent => _consent;
  SleepSyncState get syncState => _syncState;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get needsConsent => _consent == null || !_consent!.isCurrent;
  bool get cloudEnabled =>
      _consent?.isCurrent == true && _consent!.cloudEnabled;
  double? get profileAverage => SleepCalculator.latestSevenAverage(_entries);

  SleepWindowSummary summary(int days, {DateTime? now}) =>
      SleepCalculator.summarize(_entries, days: days, now: now);
  List<SleepContributorObservation> observations({DateTime? now}) =>
      SleepCalculator.observations(_entries, now: now);

  Future<void> load(String userId, {bool force = false}) async {
    if (!force && _loadedUserId == userId && !_isLoading) return;
    _loadedUserId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.load(userId);
      _entries = result.entries;
      _consent = result.consent;
      _syncState = result.pendingSync
          ? SleepSyncState.pending
          : SleepSyncState.idle;
    } catch (_) {
      _errorMessage = 'Unable to load your sleep diary.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> chooseStorage(String userId, SleepConsentChoice choice) async {
    _isSaving = true;
    _errorMessage = null;
    _syncState = choice == SleepConsentChoice.cloud
        ? SleepSyncState.syncing
        : SleepSyncState.idle;
    notifyListeners();
    try {
      await _repository.setConsent(userId, choice);
      _consent = SleepConsent(
        choice: choice,
        version: SleepConsent.currentVersion,
        decidedAt: DateTime.now(),
      );
      await load(userId, force: true);
      return true;
    } catch (_) {
      _syncState = SleepSyncState.error;
      _errorMessage =
          'Your storage choice could not be saved. Please try again.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> save(SleepEntry entry) async {
    final validation = SleepCalculator.validate(entry);
    if (validation != null) {
      _errorMessage = validation;
      notifyListeners();
      return false;
    }
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _entries = await _repository.save(entry, cloudEnabled: cloudEnabled);
      _syncState = SleepSyncState.idle;
      return true;
    } catch (_) {
      // The local write succeeds before cloud synchronization is attempted.
      final result = await _repository.load(entry.userId);
      _entries = result.entries;
      _syncState = SleepSyncState.pending;
      _errorMessage = 'Saved on this device. Cloud sync will be retried.';
      return true;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteEntry(String userId, String wakeDateKey) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _entries = await _repository.delete(
        userId,
        wakeDateKey,
        cloudEnabled: cloudEnabled,
      );
      return true;
    } catch (_) {
      final result = await _repository.load(userId);
      _entries = result.entries;
      if (result.pendingSync) {
        _syncState = SleepSyncState.pending;
        _errorMessage =
            'Deleted on this device. Cloud deletion will be retried.';
        return true;
      }
      _errorMessage = 'Unable to delete this sleep entry.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAll(String userId) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.deleteAll(userId, cloudEnabled: cloudEnabled);
      _entries = const [];
      return true;
    } catch (_) {
      _errorMessage = 'Unable to delete all sleep entries.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> revokeCloud(String userId) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.revokeCloud(userId);
      _consent = SleepConsent(
        choice: SleepConsentChoice.localOnly,
        version: SleepConsent.currentVersion,
        decidedAt: DateTime.now(),
      );
      _syncState = SleepSyncState.idle;
      return true;
    } catch (_) {
      _syncState = SleepSyncState.error;
      _errorMessage =
          'Cloud deletion is incomplete. Please retry while online.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> retrySync(String userId) async {
    if (!cloudEnabled) return;
    _syncState = SleepSyncState.syncing;
    _errorMessage = null;
    notifyListeners();
    try {
      _entries = await _repository.retrySync(userId);
      _syncState = SleepSyncState.idle;
    } catch (_) {
      _syncState = SleepSyncState.pending;
      _errorMessage = 'Cloud sync is still pending.';
    }
    notifyListeners();
  }
}
