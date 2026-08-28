import 'package:flutter/foundation.dart';

import '../features/sleep/models/sleep_models.dart';
import '../repositories/sleep_repository.dart';
import '../services/firebase/firebase_error_message.dart';

class SleepProvider extends ChangeNotifier {
  SleepProvider(this._repository);

  final SleepRepository _repository;
  List<SleepEntry> _entries = const [];
  SleepConsent? _consent;
  SleepSyncState _syncState = SleepSyncState.idle;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  SleepEntry? _conflictingEntry;
  String? _loadedUserId;

  List<SleepEntry> get entries => List.unmodifiable(_entries);
  SleepConsent? get consent => _consent;
  SleepSyncState get syncState => _syncState;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  SleepEntry? get conflictingEntry => _conflictingEntry;
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
    } catch (error, stackTrace) {
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Loading sleep diary failed.',
      );
      _errorMessage = FirebaseErrorMessage.describe(
        error,
        fallback: 'Unable to load your sleep diary.',
      );
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
    } catch (error, stackTrace) {
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Saving sleep consent failed.',
      );
      _syncState = SleepSyncState.error;
      _errorMessage = FirebaseErrorMessage.describe(
        error,
        fallback: 'Your storage choice could not be saved. Please try again.',
      );
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<SleepSaveResult> save(SleepEntry entry) async {
    final validation = SleepCalculator.validate(entry);
    if (validation != null) {
      _errorMessage = validation;
      notifyListeners();
      return SleepSaveResult(
        status: SleepSaveStatus.localSaveFailed,
        message: validation,
      );
    }
    _isSaving = true;
    _errorMessage = null;
    _conflictingEntry = null;
    notifyListeners();
    try {
      final result = await _repository.save(entry, cloudEnabled: cloudEnabled);
      if (result.localSaved && result.savedEntry != null) {
        _entries = [
          ..._entries.where(
            (value) => value.wakeDateKey != result.savedEntry!.wakeDateKey,
          ),
          result.savedEntry!,
        ]..sort((a, b) => b.wakeDateKey.compareTo(a.wakeDateKey));
      }
      _conflictingEntry = result.conflictingEntry;
      if (result.status == SleepSaveStatus.savedLocallySyncPending) {
        _syncState = SleepSyncState.pending;
      } else if (result.status == SleepSaveStatus.localSaveFailed) {
        _syncState = cloudEnabled
            ? SleepSyncState.pending
            : SleepSyncState.idle;
      } else {
        _syncState = SleepSyncState.idle;
      }
      _errorMessage = result.message;
      return result;
    } catch (error, stackTrace) {
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Saving sleep entry failed.',
      );
      _syncState = SleepSyncState.error;
      _errorMessage = FirebaseErrorMessage.describe(
        error,
        fallback: 'We could not save this entry. Please try again.',
      );
      return SleepSaveResult(
        status: SleepSaveStatus.localSaveFailed,
        message: _errorMessage,
      );
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
    } catch (error, stackTrace) {
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Deleting sleep entry failed.',
      );
      final result = await _repository.load(userId);
      _entries = result.entries;
      if (result.pendingSync) {
        _syncState = SleepSyncState.pending;
        _errorMessage =
            'Deleted on this device. Cloud deletion will be retried.';
        return true;
      }
      _errorMessage = FirebaseErrorMessage.describe(
        error,
        fallback: 'Unable to delete this sleep entry.',
      );
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
    } catch (error, stackTrace) {
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Deleting sleep diary failed.',
      );
      _errorMessage = FirebaseErrorMessage.describe(
        error,
        fallback: 'Unable to delete all sleep entries.',
      );
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
    } catch (error, stackTrace) {
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Revoking sleep cloud storage failed.',
      );
      _syncState = SleepSyncState.error;
      _errorMessage = FirebaseErrorMessage.describe(
        error,
        fallback: 'Cloud deletion is incomplete. Please retry while online.',
      );
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

  Future<void> keepCloudConflict(SleepEntry cloudEntry) async {
    _entries = await _repository.keepCloudVersion(cloudEntry);
    _conflictingEntry = null;
    _errorMessage = 'Kept the version saved on the other device.';
    notifyListeners();
  }

  Future<SleepSaveResult> replaceCloudConflict(
    SleepEntry localEntry,
    SleepEntry cloudEntry,
  ) => save(localEntry.copyWith(revision: cloudEntry.revision));

  Future<SleepShareGrant> createCounselorShare(int summaryWindowDays) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _repository.createCounselorShare(summaryWindowDays);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<List<SleepShareGrant>> loadCounselorShares(String userId) =>
      _repository.loadCounselorShares(userId);

  Future<void> revokeCounselorShare(String shareId) =>
      _repository.revokeCounselorShare(shareId);
}
