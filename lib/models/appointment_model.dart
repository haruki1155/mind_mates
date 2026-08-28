import '../core/utils/firestore_mapper.dart';

enum AppointmentLifecycleStatus {
  pending,
  confirmed,
  ongoing,
  rescheduleProposed,
  completed,
  declined,
  cancelled,
  unknown;

  static AppointmentLifecycleStatus parse(Object? value) {
    final raw = '${value ?? 'pending'}'.trim().toLowerCase().replaceAll(RegExp(r'[ -]'), '_');
    return switch (raw) {
      'pending' || 'requested' => pending,
      'confirmed' || 'upcoming' || 'scheduled' => confirmed,
      'ongoing' || 'in_progress' || 'inprogress' => ongoing,
      'reschedule_proposed' || 'reschedule' || 'rescheduled' => rescheduleProposed,
      'completed' || 'complete' || 'done' => completed,
      'declined' || 'rejected' => declined,
      'cancelled' || 'canceled' => cancelled,
      _ => unknown,
    };
  }

  String get storedValue => switch (this) {
    pending => 'pending', confirmed => 'confirmed', ongoing => 'ongoing',
    rescheduleProposed => 'reschedule_proposed', completed => 'completed',
    declined => 'declined', cancelled => 'cancelled', unknown => 'unknown',
  };

  String get label => switch (this) {
    pending => 'Pending', confirmed => 'Confirmed', ongoing => 'Ongoing',
    rescheduleProposed => 'Reschedule proposed', completed => 'Completed',
    declined => 'Declined', cancelled => 'Cancelled', unknown => 'Unsupported',
  };

  bool get isTerminal => this == completed || this == declined || this == cancelled;
  bool get isActive => !isTerminal && this != unknown;
}

class AppointmentModel {
  const AppointmentModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.scheduledAt,
    required this.scheduledTime,
    required this.location,
    required this.status,
    required this.concern,
    required this.contactNumber,
    required this.email,
    required this.preferredContactMethod,
    required this.createdAt,
    this.age,
    this.address,
    this.facebook,
    this.sex,
    this.course,
    this.yearLevel,
    this.therapyBefore,
    this.bestTime,
    this.counselorName,
    this.updatedAt,
    this.assignedStaffId,
    this.staffReply,
    this.reviewedAt,
    this.proposedScheduledAt,
    this.proposedScheduledTime,
    this.parentAppointmentId,
    this.rootAppointmentId,
    this.startedAt,
    this.completedAt,
    this.statusBeforeReschedule,
    this.proposedBy,
    this.proposedAt,
  });

  final String id;
  final String userId;
  final String fullName;
  final int? age;
  final String? address;
  final String contactNumber;
  final String email;
  final String? facebook;
  final String? sex;
  final String? course;
  final String? yearLevel;
  final String preferredContactMethod;
  final String? therapyBefore;
  final String concern;
  final String? bestTime;
  final DateTime scheduledAt;
  final String scheduledTime;
  final String location;
  final String status;
  final String? counselorName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? assignedStaffId;
  final String? staffReply;
  final DateTime? reviewedAt;
  final DateTime? proposedScheduledAt;
  final String? proposedScheduledTime;
  final String? parentAppointmentId;
  final String? rootAppointmentId;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? statusBeforeReschedule;
  final String? proposedBy;
  final DateTime? proposedAt;
  AppointmentLifecycleStatus get lifecycleStatus => AppointmentLifecycleStatus.parse(status);

  factory AppointmentModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return AppointmentModel(
      id: (json['id'] ?? id ?? '').toString(),
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      age: _optionalInt(json['age']),
      address: _optionalString(json['address']),
      contactNumber: json['contactNumber']?.toString().trim() ?? '',
      email: json['email']?.toString().trim() ?? '',
      facebook: _optionalString(json['facebook']),
      sex: _optionalString(json['sex']),
      course: _optionalString(json['course']),
      yearLevel: _optionalString(json['yearLevel']),
      preferredContactMethod:
          json['preferredContactMethod']?.toString().trim() ?? '',
      therapyBefore: _optionalString(json['therapyBefore']),
      concern: json['concern']?.toString() ?? '',
      bestTime: _optionalString(json['bestTime']),
      scheduledAt: dateTimeFromFirestoreOrNow(json['scheduledAt']),
      scheduledTime: json['scheduledTime']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Upcoming',
      counselorName: _optionalString(json['counselorName']),
      createdAt: dateTimeFromFirestoreOrNow(json['createdAt']),
      updatedAt: dateTimeFromFirestore(json['updatedAt']),
      assignedStaffId: _optionalString(json['assignedStaffId']),
      staffReply: _optionalString(json['staffReply']),
      reviewedAt: dateTimeFromFirestore(json['reviewedAt']),
      proposedScheduledAt: dateTimeFromFirestore(json['proposedScheduledAt']),
      proposedScheduledTime: _optionalString(json['proposedScheduledTime']),
      parentAppointmentId: _optionalString(json['parentAppointmentId']),
      rootAppointmentId: _optionalString(json['rootAppointmentId']),
      startedAt: dateTimeFromFirestore(json['startedAt']),
      completedAt: dateTimeFromFirestore(json['completedAt']),
      statusBeforeReschedule: _optionalString(json['statusBeforeReschedule']),
      proposedBy: _optionalString(json['proposedBy']),
      proposedAt: dateTimeFromFirestore(json['proposedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fullName': fullName,
      'age': age,
      'address': address ?? '',
      'contactNumber': contactNumber,
      'email': email,
      'facebook': facebook ?? '',
      'sex': sex ?? '',
      'course': course ?? '',
      'yearLevel': yearLevel ?? '',
      'preferredContactMethod': preferredContactMethod,
      'therapyBefore': therapyBefore ?? '',
      'concern': concern,
      'bestTime': bestTime ?? '',
      'scheduledAt': scheduledAt,
      'scheduledTime': scheduledTime,
      'location': location,
      'status': status,
      'counselorName': counselorName ?? '',
      'assignedStaffId': assignedStaffId ?? '',
      'staffReply': staffReply ?? '',
      'reviewedAt': reviewedAt,
      'proposedScheduledAt': proposedScheduledAt,
      'proposedScheduledTime': proposedScheduledTime ?? '',
      'parentAppointmentId': parentAppointmentId ?? '',
      'rootAppointmentId': rootAppointmentId ?? '',
      'startedAt': startedAt,
      'completedAt': completedAt,
      'statusBeforeReschedule': statusBeforeReschedule ?? '',
      'proposedBy': proposedBy ?? '',
      'proposedAt': proposedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  AppointmentModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    int? age,
    String? address,
    String? contactNumber,
    String? email,
    String? facebook,
    String? sex,
    String? course,
    String? yearLevel,
    String? preferredContactMethod,
    String? therapyBefore,
    String? concern,
    String? bestTime,
    DateTime? scheduledAt,
    String? scheduledTime,
    String? location,
    String? status,
    String? counselorName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? assignedStaffId,
    String? staffReply,
    DateTime? reviewedAt,
    DateTime? proposedScheduledAt,
    String? proposedScheduledTime,
    String? parentAppointmentId,
    String? rootAppointmentId,
    DateTime? startedAt,
    DateTime? completedAt,
    String? statusBeforeReschedule,
    String? proposedBy,
    DateTime? proposedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      address: address ?? this.address,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      facebook: facebook ?? this.facebook,
      sex: sex ?? this.sex,
      course: course ?? this.course,
      yearLevel: yearLevel ?? this.yearLevel,
      preferredContactMethod:
          preferredContactMethod ?? this.preferredContactMethod,
      therapyBefore: therapyBefore ?? this.therapyBefore,
      concern: concern ?? this.concern,
      bestTime: bestTime ?? this.bestTime,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      location: location ?? this.location,
      status: status ?? this.status,
      counselorName: counselorName ?? this.counselorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedStaffId: assignedStaffId ?? this.assignedStaffId,
      staffReply: staffReply ?? this.staffReply,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      proposedScheduledAt: proposedScheduledAt ?? this.proposedScheduledAt,
      proposedScheduledTime:
          proposedScheduledTime ?? this.proposedScheduledTime,
      parentAppointmentId: parentAppointmentId ?? this.parentAppointmentId,
      rootAppointmentId: rootAppointmentId ?? this.rootAppointmentId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      statusBeforeReschedule:
          statusBeforeReschedule ?? this.statusBeforeReschedule,
      proposedBy: proposedBy ?? this.proposedBy,
      proposedAt: proposedAt ?? this.proposedAt,
    );
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int? _optionalInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class AppointmentHistoryEvent {
  const AppointmentHistoryEvent({
    required this.id,
    required this.eventType,
    required this.status,
    required this.reply,
    this.previousStatus,
    this.actorName,
    this.actorRole,
    this.createdAt,
    this.proposedScheduledAt,
    this.proposedScheduledTime,
    this.linkedAppointmentId,
  });

  final String id;
  final String eventType;
  final String status;
  final String reply;
  final String? previousStatus;
  final String? actorName;
  final String? actorRole;
  final DateTime? createdAt;
  final DateTime? proposedScheduledAt;
  final String? proposedScheduledTime;
  final String? linkedAppointmentId;

  factory AppointmentHistoryEvent.fromJson(
    Map<String, dynamic> json, {
    String? id,
  }) => AppointmentHistoryEvent(
    id: '${json['id'] ?? id ?? ''}',
    eventType: '${json['eventType'] ?? json['status'] ?? 'updated'}',
    status: '${json['status'] ?? ''}',
    reply: '${json['reply'] ?? ''}',
    previousStatus: AppointmentModel._optionalString(json['previousStatus']),
    actorName: AppointmentModel._optionalString(
      json['actorName'] ?? json['staffName'],
    ),
    actorRole: AppointmentModel._optionalString(json['actorRole']),
    createdAt: dateTimeFromFirestore(json['createdAt']),
    proposedScheduledAt: dateTimeFromFirestore(json['proposedScheduledAt']),
    proposedScheduledTime: AppointmentModel._optionalString(
      json['proposedScheduledTime'],
    ),
    linkedAppointmentId: AppointmentModel._optionalString(
      json['linkedAppointmentId'],
    ),
  );
}
