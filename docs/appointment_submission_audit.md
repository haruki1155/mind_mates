# Appointment Submission Audit

Date: 2026-08-14  
Scope: student appointment intake, client provider/repository, Firebase callable, and appointment security boundary.

## Executive finding

Appointment creation is implemented as a server-owned Firebase callable. The submission failure was caused by a client/server schedule mismatch: the client allowed every time slot for the current day, while `createAppointmentRequest` rejects timestamps earlier than the current server time. Once the current time passed the final available slot, every slot shown for today was invalid.

A related client defect kept the previously selected time when the user changed dates. That could submit a time from the old date unless the user manually selected a new time.

## Submission path

1. `PaccCounselingScreen` validates the intake form and builds an `AppointmentModel`.
2. `AppointmentProvider.createAppointment` prevents duplicate concurrent saves and keeps a retry-safe submission ID.
3. `AppointmentRepository` requests App Check, routes to `createAppointmentRequest` (or the development alias), and sends the schedule as epoch milliseconds.
4. `createAppointmentRequestHandler` authenticates the caller, validates the schedule and required fields, verifies the app-user profile, and creates the appointment transactionally.
5. The provider adds the server-confirmed appointment and the screen shows confirmation.

## Evidence and risk

- The client calendar previously enabled today based only on the date.
- The client exposed all fixed time slots for today.
- The callable applies `scheduledAt < Date.now() - 60_000` rejection.
- The visible error is intentionally generalized, so the scheduling rejection looked like a generic save failure.
- Firestore appointment writes are denied to clients; creation is callable-owned, which is the correct security design.

Impact: appointments attempted after a displayed slot had passed could not be submitted. Severity: High for same-day booking availability; data integrity risk: Medium, because the server correctly prevented invalid appointments.

## Fix applied

- Filter time slots for the selected date against the current time.
- Disable today when no future slot remains.
- Clear the selected time whenever the date changes.
- Show a clear message when the selected date has no remaining slots.

## Fix plan / release checklist

- Run Flutter analysis and the counseling/provider tests.
- Build the Functions TypeScript source.
- Deploy the client and the matching callable exports together.
- Verify App Check configuration for the target platform and `APP_ENV` routing.
- Test a future date, a remaining same-day slot, a past same-day slot, retry after a network failure, and an incomplete profile.
- Monitor Firebase callable errors and appointment creation counts after release.

## Remaining operational note

The server remains the final authority for time validity. If staff availability becomes dynamic, replace the fixed client slot list with server-provided availability; keep the server-side schedule validation and transactional idempotency.
