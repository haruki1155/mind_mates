import 'package:flutter/foundation.dart';

import '../models/appointment_model.dart';
import '../repositories/appointment_repository.dart';
import '../services/firebase/firebase_error_message.dart';

class AppointmentProvider extends ChangeNotifier {
  AppointmentProvider(this._repository);

  final AppointmentRepository _repository;

  List<AppointmentModel> _appointments = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _loadedUserId;
  int _loadGeneration = 0;
  String? _pendingSubmissionId;
  final Map<String, String> _pendingRescheduleOperations = {};

  List<AppointmentModel> get appointments => List.unmodifiable(_appointments);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get loadedUserId => _loadedUserId;

  Future<void> loadAppointments(String userId) async {
    final generation = ++_loadGeneration;
    if (_loadedUserId != userId) {
      _loadedUserId = userId;
      _appointments = [];
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final appointments = await _repository.fetchAppointments(userId);
      if (generation != _loadGeneration || _loadedUserId != userId) return;
      _appointments = appointments
          .where((appointment) => appointment.userId == userId)
          .toList(growable: false);
    } catch (error, stackTrace) {
      if (generation != _loadGeneration || _loadedUserId != userId) return;
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Loading appointments failed.',
      );
      _errorMessage = FirebaseErrorMessage.describe(
        error,
        fallback: 'Unable to load appointments.',
      );
    } finally {
      if (generation == _loadGeneration && _loadedUserId == userId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> createAppointment(AppointmentModel appointment) async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _pendingSubmissionId ??= AppointmentRepository.newOperationId(
        'appointment',
      );
      final created = await _repository.createAppointment(
        appointment,
        submissionId: _pendingSubmissionId,
      );
      if (created.userId != appointment.userId) {
        throw StateError('Appointment owner mismatch.');
      }
      final existing = _loadedUserId == appointment.userId
          ? _appointments
          : const <AppointmentModel>[];
      _loadedUserId = appointment.userId;
      _appointments =
          [
              created,
              ...existing,
            ].where((item) => item.userId == appointment.userId).toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      _pendingSubmissionId = null;
      return true;
    } catch (error, stackTrace) {
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Saving appointment failed.',
      );
      _errorMessage = FirebaseErrorMessage.describe(
        error,
        fallback: 'Unable to save appointment.',
      );
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> respondToReschedule(
    AppointmentModel appointment, {
    required bool accept,
  }) async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    final key = '${appointment.id}_${accept ? 'accept' : 'decline'}';
    _pendingRescheduleOperations[key] ??=
        AppointmentRepository.newOperationId('reschedule');
    notifyListeners();
    try {
      final result = await _repository.respondToReschedule(
        appointmentId: appointment.id,
        accept: accept,
        operationId: _pendingRescheduleOperations[key]!,
      );
      _pendingRescheduleOperations.remove(key);
      _appointments = _appointments
          .map(
            (item) => item.id == appointment.id
                ? item.copyWith(
                    status: result.status,
                    scheduledAt: result.scheduledAt,
                    scheduledTime: result.scheduledTime,
                    updatedAt: DateTime.now(),
                  )
                : item,
          )
          .toList(growable: false);
      return true;
    } catch (error, stackTrace) {
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Responding to appointment reschedule failed.',
      );
      _errorMessage = FirebaseErrorMessage.describe(
        error,
        fallback:
            'Your response was not saved. Check your connection and retry.',
      );
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
