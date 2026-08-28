import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';

import '../database/firestore_collections.dart';
import '../models/appointment_model.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/firebase_app_check_service.dart';
import '../services/firebase/firebase_callable_router.dart';

class AppointmentRepository {
  AppointmentRepository({
    FirestoreService? firestoreService,
    FirebaseFunctions? functions,
  }) : _firestoreService = firestoreService ?? FirestoreService(),
       _functionsOverride = functions;

  final FirestoreService _firestoreService;
  final FirebaseFunctions? _functionsOverride;
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<List<AppointmentModel>> fetchAppointments(String userId) {
    return _firestoreService
        .getDocuments(
          FirestoreCollections.appointments,
          whereEquals: {'userId': userId},
          orderBy: 'scheduledAt',
          descending: false,
        )
        .then(
          (docs) => docs
              .where((doc) => doc['userId']?.toString() == userId)
              .map(
                (doc) =>
                    AppointmentModel.fromJson(doc, id: doc['id']?.toString()),
              )
              .toList(growable: false),
        );
  }

  Future<AppointmentModel> createAppointment(
    AppointmentModel appointment, {
    String? submissionId,
  }) async {
    await FirebaseAppCheckService.requireToken();
    final result = await _functions
        .routedCallable('createAppointmentRequest')
        .call<Map<String, dynamic>>({
          ...appointment.toJson(),
          'scheduledAt': appointment.scheduledAt.millisecondsSinceEpoch,
          'submissionId': submissionId ?? newOperationId('appointment'),
        });
    return appointment.copyWith(
      id: '${result.data['appointmentId'] ?? ''}',
      status: '${result.data['status'] ?? 'pending'}',
      updatedAt: DateTime.now(),
    );
  }

  Future<AppointmentRescheduleResult> respondToReschedule({
    required String appointmentId,
    required bool accept,
    required String operationId,
  }) async {
    await FirebaseAppCheckService.requireToken();
    final result = await _functions
        .routedCallable('respondToAppointmentReschedule')
        .call<Map<String, dynamic>>({
      'appointmentId': appointmentId,
      'response': accept ? 'accept' : 'decline',
      'operationId': operationId,
    });
    return AppointmentRescheduleResult.fromJson(result.data);
  }

  static String newOperationId(String prefix) {
    final random = Random.secure();
    final suffix = List.generate(
      12,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$suffix';
  }
}

class AppointmentRescheduleResult {
  const AppointmentRescheduleResult({
    required this.status,
    required this.scheduledAt,
    required this.scheduledTime,
  });

  final String status;
  final DateTime scheduledAt;
  final String scheduledTime;

  factory AppointmentRescheduleResult.fromJson(Map<String, dynamic> json) {
    final millis = (json['scheduledAt'] as num?)?.toInt();
    if (millis == null || millis <= 0) {
      throw const FormatException('Missing server-confirmed appointment date.');
    }
    return AppointmentRescheduleResult(
      status: '${json['status'] ?? ''}',
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(millis),
      scheduledTime: '${json['scheduledTime'] ?? ''}',
    );
  }
}
