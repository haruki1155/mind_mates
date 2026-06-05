class AppointmentModel {
  const AppointmentModel({
    required this.id,
    required this.scheduledAt,
    this.counselorName,
  });

  final String id;
  final DateTime scheduledAt;
  final String? counselorName;
}
