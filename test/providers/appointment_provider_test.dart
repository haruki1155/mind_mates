import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/models/appointment_model.dart';
import 'package:mind_mates/providers/appointment_provider.dart';
import 'package:mind_mates/repositories/appointment_repository.dart';

void main() {
  test('appointment status parsing preserves pending and rejects unknown values', () {
    expect(
      AppointmentLifecycleStatus.parse('pending'),
      AppointmentLifecycleStatus.pending,
    );
    expect(
      AppointmentLifecycleStatus.parse('unexpected-state'),
      AppointmentLifecycleStatus.unknown,
    );
  });

  test('loads appointments for the requested user', () async {
    final repository = _FakeAppointmentRepository([
      _appointment('a1', 'user_1'),
      _appointment('a2', 'user_2'),
    ])..returnAllUsers = true;
    final provider = AppointmentProvider(repository);

    await provider.loadAppointments('user_1');

    expect(provider.appointments.map((item) => item.id), ['a1']);
    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, isNull);
  });

  test(
    'load failure preserves existing appointments and exposes an error',
    () async {
      final repository = _FakeAppointmentRepository([
        _appointment('a1', 'user_1'),
      ]);
      final provider = AppointmentProvider(repository);
      await provider.loadAppointments('user_1');

      repository.shouldFail = true;
      await provider.loadAppointments('user_1');

      expect(provider.appointments.single.id, 'a1');
      expect(provider.errorMessage, 'Unable to load appointments.');
    },
  );

  test('save failure does not add an appointment', () async {
    final repository = _FakeAppointmentRepository([])..shouldFail = true;
    final provider = AppointmentProvider(repository);

    final saved = await provider.createAppointment(
      _appointment('new', 'user_1'),
    );

    expect(saved, isFalse);
    expect(provider.appointments, isEmpty);
    expect(provider.errorMessage, 'Unable to save appointment.');
    expect(provider.isSaving, isFalse);
  });

  test(
    'switching users clears the previous user appointments immediately',
    () async {
      final repository = _FakeAppointmentRepository([
        _appointment('a1', 'user_1'),
        _appointment('a2', 'user_2'),
      ]);
      final provider = AppointmentProvider(repository);
      await provider.loadAppointments('user_1');

      final loading = provider.loadAppointments('user_2');

      expect(provider.appointments, isEmpty);
      await loading;
      expect(provider.appointments.single.id, 'a2');
    },
  );

  test('duplicate save attempts produce only one repository write', () async {
    final repository = _FakeAppointmentRepository([])
      ..saveCompleter = Completer<AppointmentModel>();
    final provider = AppointmentProvider(repository);
    final appointment = _appointment('new', 'user_1');

    final first = provider.createAppointment(appointment);
    final second = await provider.createAppointment(appointment);

    expect(second, isFalse);
    expect(repository.createCalls, 1);
    repository.saveCompleter!.complete(appointment.copyWith(id: 'created_1'));
    expect(await first, isTrue);
    expect(provider.appointments, hasLength(1));
  });

  test('failed appointment retry retains the same submission ID', () async {
    final repository = _FakeAppointmentRepository([])..shouldFail = true;
    final provider = AppointmentProvider(repository);
    final appointment = _appointment('new', 'user_1');

    expect(await provider.createAppointment(appointment), isFalse);
    repository.shouldFail = false;
    expect(await provider.createAppointment(appointment), isTrue);

    expect(repository.submissionIds, hasLength(2));
    expect(repository.submissionIds.first, repository.submissionIds.last);
  });

  test('reschedule response uses server-confirmed status and schedule', () async {
    final proposed = _appointment('a1', 'user_1').copyWith(
      status: 'reschedule_proposed',
      proposedScheduledAt: DateTime(2026, 5, 5, 14),
      proposedScheduledTime: '2:00 PM',
    );
    final repository = _FakeAppointmentRepository([proposed]);
    final provider = AppointmentProvider(repository);
    await provider.loadAppointments('user_1');
    repository.rescheduleResult = AppointmentRescheduleResult(
      status: 'confirmed',
      scheduledAt: DateTime(2026, 5, 5, 14),
      scheduledTime: '2:00 PM',
    );

    expect(
      await provider.respondToReschedule(proposed, accept: true),
      isTrue,
    );

    expect(provider.appointments.single.status, 'confirmed');
    expect(provider.appointments.single.scheduledTime, '2:00 PM');
    expect(provider.appointments.single.scheduledAt, DateTime(2026, 5, 5, 14));
  });

  test('failed reschedule retry retains the same operation ID', () async {
    final proposed = _appointment('a1', 'user_1').copyWith(
      status: 'reschedule_proposed',
      proposedScheduledAt: DateTime(2026, 5, 5, 14),
    );
    final repository = _FakeAppointmentRepository([proposed])
      ..respondShouldFail = true;
    final provider = AppointmentProvider(repository);
    await provider.loadAppointments('user_1');

    expect(await provider.respondToReschedule(proposed, accept: false), isFalse);
    repository.respondShouldFail = false;
    expect(await provider.respondToReschedule(proposed, accept: false), isTrue);

    expect(repository.rescheduleOperationIds, hasLength(2));
    expect(
      repository.rescheduleOperationIds.first,
      repository.rescheduleOperationIds.last,
    );
  });
}

AppointmentModel _appointment(String id, String userId) {
  return AppointmentModel(
    id: id,
    userId: userId,
    fullName: 'Test User',
    concern: 'Needs support.',
    scheduledAt: DateTime(2026, 4, 30, 11),
    scheduledTime: '11:00 AM',
    location: 'PACC Office',
    status: 'Upcoming',
    contactNumber: '123',
    email: 'test@example.com',
    preferredContactMethod: 'Email',
    createdAt: DateTime(2026, 4, 1),
  );
}

class _FakeAppointmentRepository extends AppointmentRepository {
  _FakeAppointmentRepository(this.items);

  final List<AppointmentModel> items;
  bool shouldFail = false;
  bool returnAllUsers = false;
  int createCalls = 0;
  Completer<AppointmentModel>? saveCompleter;
  final List<String?> submissionIds = [];
  final List<String> rescheduleOperationIds = [];
  bool respondShouldFail = false;
  AppointmentRescheduleResult rescheduleResult = AppointmentRescheduleResult(
    status: 'pending',
    scheduledAt: DateTime(2026, 4, 30, 11),
    scheduledTime: '11:00 AM',
  );

  @override
  Future<List<AppointmentModel>> fetchAppointments(String userId) async {
    if (shouldFail) throw StateError('load failed');
    if (returnAllUsers) return List.of(items);
    return items.where((item) => item.userId == userId).toList();
  }

  @override
  Future<AppointmentModel> createAppointment(
    AppointmentModel appointment, {
    String? submissionId,
  }) async {
    createCalls += 1;
    submissionIds.add(submissionId);
    if (shouldFail) throw StateError('save failed');
    if (saveCompleter != null) return saveCompleter!.future;
    return appointment.copyWith(id: 'created_1');
  }

  @override
  Future<AppointmentRescheduleResult> respondToReschedule({
    required String appointmentId,
    required bool accept,
    required String operationId,
  }) async {
    rescheduleOperationIds.add(operationId);
    if (respondShouldFail) throw StateError('response failed');
    return rescheduleResult;
  }
}
