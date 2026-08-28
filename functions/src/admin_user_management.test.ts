import assert from "node:assert/strict";
import test from "node:test";
import {Timestamp} from "firebase-admin/firestore";
import {inactiveAppUserDecision, newPublicUserId} from "./index";
import {
  canTransitionAppointment,
  canonicalAppointmentStatus,
  rescheduleRestoreStatus,
} from "./appointment_workflow";

test("public app user IDs use the privacy-safe format", () => {
  const values = Array.from({length: 200}, () => newPublicUserId());
  assert.ok(values.every((value) => /^USR-[A-HJ-NP-Z2-9]{6}$/.test(value)));
  assert.equal(new Set(values).size, values.length);
});

test("inactive app users include the exact cutoff boundary", () => {
  const cutoff = Timestamp.fromMillis(1_000_000);
  assert.equal(inactiveAppUserDecision({
    accessRole: "appUser",
    lastActiveAt: cutoff,
    createdAt: Timestamp.fromMillis(900_000),
  }, cutoff), "eligible");
  assert.equal(inactiveAppUserDecision({
    accessRole: "appUser",
    lastActiveAt: Timestamp.fromMillis(1_000_001),
  }, cutoff), "active");
});

test("inactivity falls back to createdAt and skips missing or malformed dates", () => {
  const cutoff = Timestamp.fromMillis(1_000_000);
  assert.equal(inactiveAppUserDecision({
    accessRole: "appUser",
    createdAt: Timestamp.fromMillis(999_999),
  }, cutoff), "eligible");
  assert.equal(inactiveAppUserDecision({accessRole: "appUser"}, cutoff), "missing-activity");
  assert.equal(inactiveAppUserDecision({
    accessRole: "appUser",
    lastActiveAt: "2026-01-01",
    createdAt: "2025-01-01",
  }, cutoff), "missing-activity");
});

test("staff, counselors, administrators, and staff registrations are protected", () => {
  const cutoff = Timestamp.fromMillis(1_000_000);
  const old = Timestamp.fromMillis(1);
  for (const accessRole of ["portalStaff", "counselor", "admin", undefined]) {
    assert.equal(inactiveAppUserDecision({accessRole, lastActiveAt: old}, cutoff), "protected-account");
  }
  for (const staffAccountStatus of ["pending", "approved", "rejected", "disabled"]) {
    assert.equal(inactiveAppUserDecision({
      accessRole: "appUser",
      staffAccountStatus,
      lastActiveAt: old,
    }, cutoff), "protected-account");
  }
});

test("appointment lifecycle maps legacy values and rejects terminal transitions", () => {
  assert.equal(canonicalAppointmentStatus("Upcoming"), "confirmed");
  assert.equal(canonicalAppointmentStatus("complete"), "completed");
  assert.equal(canonicalAppointmentStatus("unexpected_state"), null);
  assert.ok(canTransitionAppointment("pending", "confirmed"));
  assert.ok(canTransitionAppointment("confirmed", "ongoing"));
  assert.ok(canTransitionAppointment("ongoing", "completed"));
  assert.equal(canTransitionAppointment("completed", "confirmed"), false);
  assert.equal(canTransitionAppointment("declined", "ongoing"), false);
  assert.equal(canTransitionAppointment("reschedule_proposed", "confirmed"), false);
  assert.equal(canTransitionAppointment("reschedule_proposed", "declined"), false);
});

test("legacy reschedule proposals restore the most recent supported prior state", () => {
  assert.equal(rescheduleRestoreStatus("confirmed"), "confirmed");
  assert.equal(rescheduleRestoreStatus(undefined, [
    {previousStatus: "unsupported"},
    {previousStatus: "Upcoming"},
  ]), "confirmed");
  assert.equal(rescheduleRestoreStatus(undefined, []), "pending");
});
