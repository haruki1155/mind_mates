import 'package:flutter/material.dart';

import '../../../models/appointment_model.dart';

enum AppointmentDisplayStatus {
  pending,
  upcoming,
  confirmed,
  rescheduleProposed,
  declined,
  completed,
  cancelled,
  other,
}

AppointmentDisplayStatus appointmentDisplayStatus(String value) {
  return switch (value.trim().toLowerCase()) {
    'pending' => AppointmentDisplayStatus.pending,
    'upcoming' => AppointmentDisplayStatus.upcoming,
    'confirmed' => AppointmentDisplayStatus.confirmed,
    'reschedule_proposed' => AppointmentDisplayStatus.rescheduleProposed,
    'declined' => AppointmentDisplayStatus.declined,
    'completed' => AppointmentDisplayStatus.completed,
    'cancelled' || 'canceled' => AppointmentDisplayStatus.cancelled,
    _ => AppointmentDisplayStatus.other,
  };
}

bool isSameAppointmentDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String formatAppointmentDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

Color appointmentStatusColor(AppointmentDisplayStatus status) =>
    switch (status) {
      AppointmentDisplayStatus.pending => const Color(0xFFF0A400),
      AppointmentDisplayStatus.upcoming => const Color(0xFFE5AC00),
      AppointmentDisplayStatus.confirmed => const Color(0xFF3D8B68),
      AppointmentDisplayStatus.rescheduleProposed => const Color(0xFF61738A),
      AppointmentDisplayStatus.declined => const Color(0xFFB54A4A),
      AppointmentDisplayStatus.completed => const Color(0xFF3D8B68),
      AppointmentDisplayStatus.cancelled => const Color(0xFF8A8173),
      AppointmentDisplayStatus.other => const Color(0xFF61738A),
    };

Future<void> showAppointmentDetailsSheet(
  BuildContext context,
  AppointmentModel appointment,
) {
  final contactSummary = [
    appointment.preferredContactMethod.trim(),
    appointment.contactNumber.trim(),
  ].where((value) => value.isNotEmpty).join(' | ');
  final details = <({IconData icon, String text})>[
    (icon: Icons.person_outline, text: appointment.fullName),
    (
      icon: Icons.calendar_today_outlined,
      text: formatAppointmentDate(appointment.scheduledAt),
    ),
    (icon: Icons.schedule, text: appointment.scheduledTime),
    (icon: Icons.place_outlined, text: appointment.location),
    if (appointment.status.trim().isNotEmpty)
      (icon: Icons.info_outline, text: appointment.status),
    if ((appointment.counselorName ?? '').trim().isNotEmpty)
      (icon: Icons.badge_outlined, text: appointment.counselorName!.trim()),
    if ((appointment.staffReply ?? '').trim().isNotEmpty)
      (icon: Icons.message_outlined, text: appointment.staffReply!.trim()),
    if (appointment.proposedScheduledAt != null)
      (
        icon: Icons.event_repeat_outlined,
        text:
            'Proposed: ${formatAppointmentDate(appointment.proposedScheduledAt!)} ${appointment.proposedScheduledTime ?? ''}',
      ),
    if (contactSummary.isNotEmpty)
      (icon: Icons.contact_phone_outlined, text: contactSummary),
    if (appointment.email.trim().isNotEmpty)
      (icon: Icons.email_outlined, text: appointment.email.trim()),
    if ((appointment.address ?? '').trim().isNotEmpty)
      (icon: Icons.home_outlined, text: appointment.address!.trim()),
    if ((appointment.facebook ?? '').trim().isNotEmpty)
      (icon: Icons.public, text: appointment.facebook!.trim()),
    if ((appointment.sex ?? '').trim().isNotEmpty)
      (icon: Icons.person, text: appointment.sex!.trim()),
    if ((appointment.course ?? '').trim().isNotEmpty)
      (icon: Icons.school_outlined, text: appointment.course!.trim()),
    if ((appointment.yearLevel ?? '').trim().isNotEmpty)
      (icon: Icons.auto_graph_outlined, text: appointment.yearLevel!.trim()),
    if ((appointment.therapyBefore ?? '').trim().isNotEmpty)
      (
        icon: Icons.history,
        text: 'Therapy before: ${appointment.therapyBefore!.trim()}',
      ),
    if ((appointment.bestTime ?? '').trim().isNotEmpty)
      (
        icon: Icons.access_time,
        text: 'Best contact time: ${appointment.bestTime!.trim()}',
      ),
  ];

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFFFFBF0),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Appointment Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              for (final detail in details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        detail.icon,
                        size: 20,
                        color: const Color(0xFF8A6500),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          detail.text,
                          style: const TextStyle(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              if (appointment.concern.trim().isNotEmpty) ...[
                const Divider(height: 26),
                const Text(
                  'Concern',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  appointment.concern.trim(),
                  style: const TextStyle(height: 1.45),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
