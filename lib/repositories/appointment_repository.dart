import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../models/appointment_model.dart';
import '../services/firebase/firestore_service.dart';
import 'user_repository.dart';

class AppointmentRepository {
  AppointmentRepository({
    FirestoreService? firestoreService,
    UserRepository? userRepository,
  }) : _firestoreService = firestoreService ?? FirestoreService(),
       _userRepository = userRepository ?? UserRepository();

  final FirestoreService _firestoreService;
  final UserRepository _userRepository;

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
              .map(
                (doc) =>
                    AppointmentModel.fromJson(doc, id: doc['id']?.toString()),
              )
              .toList(growable: false),
        );
  }

  Future<AppointmentModel> createAppointment(
    AppointmentModel appointment,
  ) async {
    final profile = await _userRepository.fetchUserProfile(appointment.userId);
    final data = appointment.toJson()
      ..['populationRole'] = profile?.effectivePopulationRole?.storedValue ?? ''
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    final id = await _firestoreService.createDocument(
      FirestoreCollections.appointments,
      data,
    );
    await _userRepository.recordActivity(
      appointment.userId,
      UserActivityType.appointmentRequested,
    );
    return appointment.copyWith(id: id, updatedAt: DateTime.now());
  }
}
