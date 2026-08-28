import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {authenticatedUid, requireApprovedPortalActor} from "./portal_access";
import {manilaDateKey, writeQualifyingWellnessState} from "./wellness";

const db = getFirestore();
const timezone = "Asia/Manila";
const currentSchemaVersion = 2;
const contributorTags = new Set([
  "late_caffeine", "alcohol", "nicotine", "naps", "exercise", "late_screens", "stress", "environment", "late_meal", "schedule_change", "illness_pain", "medication",
  "schedule_early_class", "schedule_late_class", "schedule_night_shift", "schedule_overtime", "academic_exam", "academic_deadline", "academic_heavy_workload", "academic_late_study", "environment_noise", "environment_temperature", "wellness_unwell",
]);
const concernTags = new Set(["breathing_pauses_gasping", "loud_snoring_tiredness", "dangerous_sleepiness", "persistent_problems", "worsening_symptoms"]);

function string(value: unknown, name: string, max = 160): string {
  const result = typeof value === "string" ? value.trim() : "";
  if (!result || result.length > max) throw new HttpsError("invalid-argument", `${name} is invalid.`);
  return result;
}

function uid(request: CallableRequest): string { return authenticatedUid(request); }
function number(value: unknown, name: string, min: number, max: number): number {
  if (!Number.isInteger(value) || Number(value) < min || Number(value) > max) {
    throw new HttpsError("invalid-argument", `${name} is invalid.`);
  }
  return Number(value);
}

function wallTimestamp(value: unknown, name: string): Timestamp {
  const raw = string(value, name, 40);
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(raw);
  if (!match) throw new HttpsError("invalid-argument", `${name} is invalid.`);
  const [, year, month, day, hour, minute] = match.map(Number);
  const date = new Date(Date.UTC(year, month - 1, day, hour - 8, minute));
  if (Number.isNaN(date.valueOf())) throw new HttpsError("invalid-argument", `${name} is invalid.`);
  return Timestamp.fromDate(date);
}

function instant(value: unknown, name: string): Timestamp {
  const raw = string(value, name, 40);
  const date = new Date(raw);
  if (Number.isNaN(date.valueOf())) throw new HttpsError("invalid-argument", `${name} is invalid.`);
  return Timestamp.fromDate(date);
}

function dateKey(timestamp: Timestamp): string {
  const shifted = new Date(timestamp.toMillis() + 8 * 60 * 60 * 1000);
  return shifted.toISOString().slice(0, 10).replaceAll("-", "");
}

function clockIso(timestamp: Timestamp): string {
  return new Date(timestamp.toMillis() + 8 * 60 * 60 * 1000).toISOString().replace("Z", "");
}

function timestampIso(value: unknown): string | null {
  return value instanceof Timestamp ? value.toDate().toISOString() : null;
}

function tags(value: unknown, allowed: Set<string>, name: string): string[] {
  if (!Array.isArray(value) || value.length > allowed.size || value.some((tag) => typeof tag !== "string" || !allowed.has(tag))) {
    throw new HttpsError("invalid-argument", `${name} contains an unsupported value.`);
  }
  const result = [...new Set(value)];
  if (result.length !== value.length) throw new HttpsError("invalid-argument", `${name} contains duplicates.`);
  return result.sort();
}

function parseEntry(userId: string, raw: unknown): Record<string, unknown> {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new HttpsError("invalid-argument", "Sleep entry is invalid.");
  const entry = raw as Record<string, unknown>;
  if (entry.userId !== userId) throw new HttpsError("permission-denied", "Sleep entry ownership is invalid.");
  const wakeDateKey = string(entry.wakeDateKey, "Wake date", 8);
  if (!/^\d{8}$/.test(wakeDateKey)) throw new HttpsError("invalid-argument", "Wake date is invalid.");
  const schemaVersion = number(entry.schemaVersion ?? 1, "Schema version", 1, currentSchemaVersion);
  const attemptedSleepAt = wallTimestamp(entry.attemptedSleepAt, "Attempted sleep time");
  const sleepOnsetAt = wallTimestamp(entry.sleepOnsetAt, "Sleep onset time");
  const finalWakeAt = wallTimestamp(entry.finalWakeAt, "Wake time");
  const outOfBedAt = wallTimestamp(entry.outOfBedAt, "Out of bed time");
  if (attemptedSleepAt.toMillis() > sleepOnsetAt.toMillis() || sleepOnsetAt.toMillis() > finalWakeAt.toMillis() || finalWakeAt.toMillis() > outOfBedAt.toMillis()) {
    throw new HttpsError("invalid-argument", "Sleep times must be chronological.");
  }
  const timeInBed = outOfBedAt.toMillis() - attemptedSleepAt.toMillis();
  const sleepWindow = finalWakeAt.toMillis() - sleepOnsetAt.toMillis();
  if (timeInBed <= 0 || timeInBed > 24 * 60 * 60 * 1000 || dateKey(finalWakeAt) !== wakeDateKey) {
    throw new HttpsError("invalid-argument", "Sleep times must match the wake date and be within 24 hours.");
  }
  const awakeningCount = number(entry.awakeningCount, "Awakening count", 0, 50);
  const awakeMinutes = number(entry.awakeMinutes, "Awake minutes", 0, 1440);
  if ((awakeningCount === 0 && awakeMinutes !== 0) || (awakeningCount > 0 && awakeMinutes <= 0) || awakeMinutes * 60000 > sleepWindow) {
    throw new HttpsError("invalid-argument", "Awake minutes are inconsistent with the sleep entry.");
  }
  const clientUpdatedAt = instant(entry.clientUpdatedAt, "Client update time");
  if (clientUpdatedAt.toMillis() > Date.now() + 5 * 60 * 1000) throw new HttpsError("invalid-argument", "Client update time cannot be in the future.");
  const createdAt = instant(entry.createdAt, "Created time");
  const optionalRating = (value: unknown, label: string) => value == null ? null : number(value, label, 1, 5);
  const id = `sleep_${userId}_${wakeDateKey}`;
  if (entry.id != null && entry.id !== id) throw new HttpsError("invalid-argument", "Sleep entry identifier is invalid.");
  return {
    userId, wakeDateKey, timezone, schemaVersion, attemptedSleepAt, sleepOnsetAt, finalWakeAt, outOfBedAt,
    awakeningCount, awakeMinutes, napCount: number(entry.napCount, "Nap count", 0, 10), napMinutes: number(entry.napMinutes, "Nap minutes", 0, 720),
    restfulness: number(entry.restfulness, "Restfulness", 1, 5), daytimeSleepiness: number(entry.daytimeSleepiness, "Daytime sleepiness", 1, 5), perceivedQuality: number(entry.perceivedQuality, "Sleep quality", 1, 5),
    energy: optionalRating(entry.energy, "Energy"), focus: optionalRating(entry.focus, "Focus"),
    contributorTags: tags(entry.contributorTags, contributorTags, "Contributor tags"), concernTags: tags(entry.concernTags, concernTags, "Concern tags"),
    createdAt, clientUpdatedAt,
  };
}

function serializeEntry(id: string, data: Record<string, unknown>) {
  return {
    id, userId: data.userId, wakeDateKey: data.wakeDateKey, timezone: data.timezone,
    schemaVersion: data.schemaVersion ?? 1,
    attemptedSleepAt: clockIso(data.attemptedSleepAt as Timestamp), sleepOnsetAt: clockIso(data.sleepOnsetAt as Timestamp),
    finalWakeAt: clockIso(data.finalWakeAt as Timestamp), outOfBedAt: clockIso(data.outOfBedAt as Timestamp),
    awakeningCount: data.awakeningCount, awakeMinutes: data.awakeMinutes, napCount: data.napCount, napMinutes: data.napMinutes,
    restfulness: data.restfulness, daytimeSleepiness: data.daytimeSleepiness, perceivedQuality: data.perceivedQuality,
    energy: data.energy ?? null, focus: data.focus ?? null, contributorTags: data.contributorTags ?? [], concernTags: data.concernTags ?? [],
    createdAt: timestampIso(data.createdAt), clientUpdatedAt: timestampIso(data.clientUpdatedAt), revision: data.revision ?? 0,
    serverUpdatedAt: timestampIso(data.serverUpdatedAt),
  };
}

async function setSleepCloudConsentHandler(request: CallableRequest) {
  const userId = uid(request);
  await db.collection("sleep_preferences").doc(userId).set({userId, consentVersion: "sleep-v1", cloudConsent: true, grantedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  return {ok: true};
}

async function saveSleepEntryHandler(request: CallableRequest) {
  const userId = uid(request);
  const parsed = parseEntry(userId, request.data?.entry);
  const id = `sleep_${userId}_${parsed.wakeDateKey}`;
  const reference = db.collection("sleep_entries").doc(id);
  const activity = db.collection("user_activities").doc(`sleepQuality_${id}`);
  const user = db.collection("users").doc(userId);
  const occurredAt = Timestamp.now();
  const qualifyingDateKey = manilaDateKey(occurredAt);
  const submittedRevision = number((request.data?.entry as Record<string, unknown> | undefined)?.revision ?? 0, "Revision", 0, 1e9);
  let response: Record<string, unknown> = {};
  await db.runTransaction(async (transaction) => {
    const [existing, activitySnapshot, userSnapshot] = await Promise.all([
      transaction.get(reference), transaction.get(activity), transaction.get(user),
    ]);
    if (!userSnapshot.exists) {
      throw new HttpsError("failed-precondition", "Your account profile is unavailable.");
    }
    const currentRevision = existing.exists ? Number(existing.data()?.revision ?? 0) : 0;
    if (existing.exists && submittedRevision !== currentRevision) {
      response = {status: "conflict", entry: serializeEntry(id, existing.data()!)};
      return;
    }
    const createdAt = existing.exists ? existing.data()!.createdAt : parsed.createdAt;
    const stored = {...parsed, createdAt, revision: currentRevision + 1, serverUpdatedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()};
    transaction.set(reference, stored);
    if (!activitySnapshot.exists) {
      transaction.create(activity, {
        userId,
        type: "sleepQuality",
        sourceId: id,
        dateKey: qualifyingDateKey,
        occurredAt,
        createdAt: FieldValue.serverTimestamp(),
      });
      writeQualifyingWellnessState(
        transaction, user, userSnapshot.data() ?? {}, occurredAt, qualifyingDateKey,
      );
    }
    response = {status: "saved"};
  });
  if (response.status === "conflict") return response;
  const saved = await reference.get();
  return {status: "saved", entry: serializeEntry(id, saved.data()!)};
}

async function deleteSleepEntryHandler(request: CallableRequest) {
  const userId = uid(request); const wakeDateKey = string(request.data?.wakeDateKey, "Wake date", 8);
  const ref = db.collection("sleep_entries").doc(`sleep_${userId}_${wakeDateKey}`);
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(ref);
    if (!current.exists) return;
    const revision = number(request.data?.revision ?? 0, "Revision", 0, 1e9);
    if (revision !== Number(current.data()?.revision ?? 0)) throw new HttpsError("aborted", "This entry changed on another device.");
    transaction.delete(ref);
  });
  return {ok: true};
}

async function deleteAllSleepEntriesHandler(request: CallableRequest) {
  const userId = uid(request); const entries = await db.collection("sleep_entries").where("userId", "==", userId).get();
  for (let offset = 0; offset < entries.docs.length; offset += 450) { const batch = db.batch(); entries.docs.slice(offset, offset + 450).forEach((doc) => batch.delete(doc.ref)); await batch.commit(); }
  return {ok: true};
}

async function revokeSleepCloudHandler(request: CallableRequest) {
  const userId = uid(request); await deleteAllSleepEntriesHandler(request);
  await db.collection("sleep_preferences").doc(userId).delete();
  const shares = await db.collection("sleep_shared_summaries").where("ownerId", "==", userId).get();
  await Promise.all(shares.docs.map((doc) => doc.ref.update({revokedAt: FieldValue.serverTimestamp()})));
  return {ok: true};
}

async function setCounselorAssignmentHandler(request: CallableRequest) {
  const actor = await requireApprovedPortalActor(request, ["counselor", "admin"]);
  const studentId = string(request.data?.studentId, "Student ID");
  const counselorId = string(request.data?.counselorId, "Counselor ID");
  const active = request.data?.active === true;
  if (actor.accessRole === "counselor" && actor.uid !== counselorId) throw new HttpsError("permission-denied", "Counselors can only manage their own assignments.");
  const counselor = await db.collection("users").doc(counselorId).get();
  if (!counselor.exists || counselor.data()?.accessRole !== "counselor" || counselor.data()?.staffAccountStatus !== "approved") throw new HttpsError("failed-precondition", "The selected counselor is not approved.");
  if (active) {
    const appointment = await db.collection("appointments").where("userId", "==", studentId).get();
    if (!appointment.docs.some((doc) => doc.data().assignedStaffId === counselorId && (doc.data().status === "confirmed" || doc.data().status === "ongoing"))) throw new HttpsError("failed-precondition", "A confirmed appointment is required before assigning counselor access.");
  }
  const ref = db.collection("active_counselor_assignments").doc(`${studentId}_${counselorId}`);
  if (active) {
    const existing = await db.collection("active_counselor_assignments").where("studentId", "==", studentId).where("status", "==", "active").get();
    const batch = db.batch();
    for (const assignment of existing.docs) {
      if (assignment.id !== ref.id) batch.update(assignment.ref, {status: "ended", endedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(), updatedBy: actor.uid});
    }
    await batch.commit();
  }
  await ref.set({studentId, counselorId, status: active ? "active" : "ended", startedAt: active ? FieldValue.serverTimestamp() : FieldValue.delete(), endedAt: active ? FieldValue.delete() : FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(), updatedBy: actor.uid}, {merge: true});
  return {ok: true};
}

function sleepSummary(entries: FirebaseFirestore.QueryDocumentSnapshot[], windowDays: number) {
  const end = Date.now(); const start = end - windowDays * 86400000;
  const sample = entries.filter((doc) => (doc.data().finalWakeAt as Timestamp).toMillis() >= start && (doc.data().finalWakeAt as Timestamp).toMillis() <= end);
  const average = (values: number[]) => values.length ? values.reduce((total, value) => total + value, 0) / values.length : null;
  const sleepMinutes = sample.map((doc) => { const data = doc.data(); return ((data.finalWakeAt as Timestamp).toMillis() - (data.sleepOnsetAt as Timestamp).toMillis()) / 60000 - Number(data.awakeMinutes ?? 0); });
  const clockMinutes = (timestamp: Timestamp) => { const date = new Date(timestamp.toMillis() + 8 * 60 * 60 * 1000); return date.getUTCHours() * 60 + date.getUTCMinutes(); };
  const bedtime = sample.map((doc) => { const minute = clockMinutes(doc.data().attemptedSleepAt as Timestamp); return minute < 720 ? minute + 1440 : minute; });
  const wake = sample.map((doc) => clockMinutes(doc.data().finalWakeAt as Timestamp));
  const meanDeviation = (values: number[]) => { const center = average(values); return center == null ? null : average(values.map((value) => Math.abs(value - center))); };
  const tagCounts = new Map<string, number>();
  for (const doc of sample) for (const tag of (doc.data().contributorTags ?? [])) tagCounts.set(String(tag), (tagCounts.get(String(tag)) ?? 0) + 1);
  const patterns = [...tagCounts.entries()].filter(([, count]) => count >= 3).sort((a, b) => b[1] - a[1]).slice(0, 3).map(([tag, count]) => ({tag, count, message: `${tag.replaceAll("_", " ")} was recorded on ${count} logged nights. This is an observation from self-reported entries, not proof of cause.`}));
  return {loggedDays: sample.length, windowDays, averageEstimatedSleepMinutes: average(sleepMinutes), averageQuality: average(sample.map((doc) => Number(doc.data().perceivedQuality))), averageSleepiness: average(sample.map((doc) => Number(doc.data().daytimeSleepiness))), averageEnergy: average(sample.map((doc) => Number(doc.data().energy)).filter(Boolean)), averageFocus: average(sample.map((doc) => Number(doc.data().focus)).filter(Boolean)), typicalBedtimeMinutes: sample.length >= 3 ? average(bedtime) : null, typicalWakeMinutes: sample.length >= 3 ? average(wake) : null, bedtimeVariationMinutes: sample.length >= 3 ? meanDeviation(bedtime) : null, wakeVariationMinutes: sample.length >= 3 ? meanDeviation(wake) : null, patterns, guidanceShown: {dangerousSleepiness: sample.some((doc) => (doc.data().concernTags ?? []).includes("dangerous_sleepiness")), breathingConcern: sample.some((doc) => (doc.data().concernTags ?? []).some((tag: string) => tag === "breathing_pauses_gasping" || tag === "loud_snoring_tiredness"))}};
}

async function createSleepShareHandler(request: CallableRequest) {
  const ownerId = uid(request); const summaryWindowDays = number(request.data?.summaryWindowDays, "Summary window", 7, 30);
  if (![7, 14, 30].includes(summaryWindowDays)) throw new HttpsError("invalid-argument", "Choose a 7, 14, or 30 day summary.");
  const preference = await db.collection("sleep_preferences").doc(ownerId).get();
  if (!preference.exists || preference.data()?.cloudConsent !== true) throw new HttpsError("failed-precondition", "Enable cloud sync before sharing a server-generated summary.");
  const assignments = await db.collection("active_counselor_assignments").where("studentId", "==", ownerId).where("status", "==", "active").get();
  if (assignments.empty) throw new HttpsError("failed-precondition", "An active assigned counselor is required before sharing.");
  const counselorId = String(assignments.docs[0].data().counselorId);
  const entries = await db.collection("sleep_entries").where("userId", "==", ownerId).get();
  const ref = db.collection("sleep_shared_summaries").doc();
  const now = Timestamp.now(); const expiresAt = Timestamp.fromMillis(now.toMillis() + 30 * 86400000);
  await ref.set({ownerId, counselorId, assignmentId: assignments.docs[0].id, summaryWindowDays, periodEnd: now, periodStart: Timestamp.fromMillis(now.toMillis() - summaryWindowDays * 86400000), ...sleepSummary(entries.docs, summaryWindowDays), summaryVersion: 1, insightAlgorithmVersion: 1, generatedAt: FieldValue.serverTimestamp(), expiresAt, revokedAt: null});
  return {ok: true, shareId: ref.id, accessExpiresAt: expiresAt.toDate().toISOString()};
}

async function revokeSleepShareHandler(request: CallableRequest) {
  const ownerId = uid(request); const shareId = string(request.data?.shareId, "Share ID"); const ref = db.collection("sleep_shared_summaries").doc(shareId); const share = await ref.get();
  if (!share.exists || share.data()?.ownerId !== ownerId) throw new HttpsError("not-found", "Shared summary not found.");
  await ref.update({revokedAt: FieldValue.serverTimestamp()}); return {ok: true};
}

export const setSleepCloudConsent = onCall({enforceAppCheck: true}, setSleepCloudConsentHandler);
export const setSleepCloudConsentDev = onCall({enforceAppCheck: false}, setSleepCloudConsentHandler);
export const saveSleepEntry = onCall({enforceAppCheck: true}, saveSleepEntryHandler);
export const saveSleepEntryDev = onCall({enforceAppCheck: false}, saveSleepEntryHandler);
export const deleteSleepEntry = onCall({enforceAppCheck: true}, deleteSleepEntryHandler);
export const deleteSleepEntryDev = onCall({enforceAppCheck: false}, deleteSleepEntryHandler);
export const deleteAllSleepEntries = onCall({enforceAppCheck: true}, deleteAllSleepEntriesHandler);
export const deleteAllSleepEntriesDev = onCall({enforceAppCheck: false}, deleteAllSleepEntriesHandler);
export const revokeSleepCloud = onCall({enforceAppCheck: true}, revokeSleepCloudHandler);
export const revokeSleepCloudDev = onCall({enforceAppCheck: false}, revokeSleepCloudHandler);
export const setCounselorAssignment = onCall({enforceAppCheck: true}, setCounselorAssignmentHandler);
export const setCounselorAssignmentDev = onCall({enforceAppCheck: false}, setCounselorAssignmentHandler);
export const createSleepShare = onCall({enforceAppCheck: true}, createSleepShareHandler);
export const createSleepShareDev = onCall({enforceAppCheck: false}, createSleepShareHandler);
export const revokeSleepShare = onCall({enforceAppCheck: true}, revokeSleepShareHandler);
export const revokeSleepShareDev = onCall({enforceAppCheck: false}, revokeSleepShareHandler);
