import {createHash, randomUUID} from "node:crypto";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {authenticatedUid, requireApprovedPortalActor} from "./portal_access";

export type AppointmentLifecycleStatus =
  "pending" | "confirmed" | "ongoing" | "reschedule_proposed" |
  "completed" | "declined" | "cancelled";

export function canonicalAppointmentStatus(value: unknown): AppointmentLifecycleStatus | null {
  const status = String(value ?? "").trim().toLowerCase().replace(/[ -]/g, "_");
  if (["pending", "requested"].includes(status)) return "pending";
  if (["confirmed", "upcoming", "scheduled"].includes(status)) return "confirmed";
  if (["ongoing", "in_progress", "inprogress"].includes(status)) return "ongoing";
  if (["reschedule_proposed", "reschedule", "rescheduled"].includes(status)) return "reschedule_proposed";
  if (["completed", "complete", "done"].includes(status)) return "completed";
  if (["declined", "rejected"].includes(status)) return "declined";
  if (["cancelled", "canceled"].includes(status)) return "cancelled";
  return null;
}

export function canTransitionAppointment(before: AppointmentLifecycleStatus, action: AppointmentLifecycleStatus): boolean {
  const transitions: Record<AppointmentLifecycleStatus, AppointmentLifecycleStatus[]> = {
    pending: ["confirmed", "declined", "reschedule_proposed"],
    confirmed: ["ongoing", "declined", "reschedule_proposed"],
    ongoing: ["completed"],
    // Only the app user may accept or decline an outstanding proposal.
    // Staff may replace it or use withdraw_reschedule to restore the prior state.
    reschedule_proposed: ["reschedule_proposed"],
    completed: [], declined: [], cancelled: [],
  };
  return transitions[before].includes(action);
}

export function rescheduleRestoreStatus(
  stored: unknown,
  history: Array<{previousStatus?: unknown}> = [],
): "pending" | "confirmed" {
  const direct = canonicalAppointmentStatus(stored);
  if (direct === "confirmed" || direct === "pending") return direct;
  for (const event of history) {
    const previous = canonicalAppointmentStatus(event.previousStatus);
    if (previous === "confirmed" || previous === "pending") return previous;
  }
  return "pending";
}

function text(value: unknown, label: string, min: number, max: number): string {
  const result = String(value ?? "").trim().replace(/\s+/g, " ");
  if (result.length < min || result.length > max) {
    throw new HttpsError("invalid-argument", `${label} must contain ${min} to ${max} characters.`);
  }
  return result;
}

function optionalText(value: unknown, max: number): string {
  const result = String(value ?? "").trim().replace(/\s+/g, " ");
  if (result.length > max) throw new HttpsError("invalid-argument", "An appointment field is too long.");
  return result;
}

function identifier(value: unknown, label: string): string {
  const result = String(value ?? "").trim();
  if (!/^[A-Za-z0-9_-]{8,120}$/.test(result)) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  return result;
}

function schedule(input: Record<string, unknown>, prefix = ""): {at: Timestamp; time: string} {
  const atKey = prefix ? `${prefix}ScheduledAt` : "scheduledAt";
  const timeKey = prefix ? `${prefix}ScheduledTime` : "scheduledTime";
  const millis = Number(input[atKey] ?? 0);
  const time = text(input[timeKey], "Scheduled time", 3, 30);
  const maximum = Date.now() + 366 * 24 * 60 * 60 * 1000;
  if (!Number.isFinite(millis) || millis < Date.now() - 60_000 || millis > maximum) {
    throw new HttpsError("invalid-argument", "Choose a future appointment date within one year.");
  }
  if (!/^(?:[01]?\d|2[0-3]):[0-5]\d(?:\s?(?:AM|PM))?$|^(?:1[0-2]|0?[1-9]):[0-5]\d\s?(?:AM|PM)$/i.test(time)) {
    throw new HttpsError("invalid-argument", "Enter a valid appointment time.");
  }
  return {at: Timestamp.fromMillis(millis), time};
}

function hash(value: unknown): string {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function responseError(error: unknown, correlationId: string): never {
  if (error instanceof HttpsError) {
    throw new HttpsError(error.code, error.message, {correlationId});
  }
  console.error("Appointment callable failed", {correlationId, errorCode: "internal"});
  throw new HttpsError("internal", "The appointment operation could not be completed.", {correlationId});
}

async function createAppointmentRequestHandler(request: CallableRequest) {
  const correlationId = randomUUID();
  try {
    const uid = authenticatedUid(request);
    const input = request.data as Record<string, unknown>;
    const submissionId = identifier(input.submissionId, "Submission ID");
    const desired = schedule(input);
    const location = text(input.location, "Location", 2, 150);
    const concern = text(input.concern, "Concern", 3, 2000);
    const db = getFirestore();
    const [profileSnapshot, authUser] = await Promise.all([
      db.collection("users").doc(uid).get(), getAuth().getUser(uid),
    ]);
    const profile = profileSnapshot.data();
    if (!profileSnapshot.exists || profile?.accessRole !== "appUser" || profile.staffAccountStatus != null) {
      throw new HttpsError("failed-precondition", "A complete app-user profile is required.");
    }
    const appointmentId = `request_${uid}_${submissionId}`;
    const appointment = db.collection("appointments").doc(appointmentId);
    const canonicalInput = {
      scheduledAt: desired.at.toMillis(), scheduledTime: desired.time, location, concern,
      contactNumber: optionalText(input.contactNumber, 40),
      preferredContactMethod: optionalText(input.preferredContactMethod, 60),
      age: Number(input.age ?? 0), address: optionalText(input.address, 300),
      facebook: optionalText(input.facebook, 120), sex: optionalText(input.sex, 40),
      therapyBefore: optionalText(input.therapyBefore, 40), bestTime: optionalText(input.bestTime, 100),
    };
    if (!Number.isInteger(canonicalInput.age) || canonicalInput.age < 0 || canonicalInput.age > 130) {
      throw new HttpsError("invalid-argument", "Age is invalid.");
    }
    const submissionHash = hash(canonicalInput);
    let existing = false;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(appointment);
      if (snapshot.exists) {
        if (snapshot.data()?.submissionHash !== submissionHash) {
          throw new HttpsError("already-exists", "This appointment submission ID was already used with different details.");
        }
        existing = true;
        return;
      }
      transaction.create(appointment, {
        ...canonicalInput,
        scheduledAt: desired.at,
        fullName: String(profile.name ?? `${profile.firstName ?? ""} ${profile.lastName ?? ""}`).trim(),
        email: String(authUser.email ?? "").trim(), userId: uid,
        course: String(profile.course ?? ""), yearLevel: String(profile.yearLevel ?? ""),
        populationRole: String(profile.populationRole ?? profile.declaredRole ?? ""),
        status: "pending", submissionId, submissionHash,
        createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(db.collection("user_activities").doc(`appointment_${appointmentId}`), {
        userId: uid, type: "appointmentRequested", createdAt: FieldValue.serverTimestamp(),
      });
    });
    return {ok: true, appointmentId, existing, status: "pending", correlationId};
  } catch (error) {
    responseError(error, correlationId);
  }
}

export const createAppointmentRequest = onCall({enforceAppCheck: true}, createAppointmentRequestHandler);
export const createAppointmentRequestDev = onCall({enforceAppCheck: false}, createAppointmentRequestHandler);

async function reviewAppointmentHandler(request: CallableRequest) {
  const correlationId = randomUUID();
  try {
    const actor = await requireApprovedPortalActor(request);
    const input = request.data as Record<string, unknown>;
    const appointmentId = identifier(input.appointmentId, "Appointment ID");
    const operationId = identifier(input.operationId, "Operation ID");
    const requestedAction = String(input.action ?? "").trim();
    const reply = text(input.reply, "Reply", 1, 1000);
    const action = requestedAction === "withdraw_reschedule" ? null : canonicalAppointmentStatus(requestedAction);
    if (!action && requestedAction !== "withdraw_reschedule") {
      throw new HttpsError("invalid-argument", "A valid appointment action is required.");
    }
    const proposed = action === "reschedule_proposed" ? schedule(input, "proposed") : null;
    const operationHash = hash({
      requestedAction,
      reply,
      proposedScheduledAt: proposed?.at.toMillis() ?? null,
      proposedScheduledTime: proposed?.time ?? "",
    });
    const db = getFirestore();
    const appointment = db.collection("appointments").doc(appointmentId);
    const history = appointment.collection("history").doc(`op_${operationId}`);
    const notification = db.collection("notifications").doc(`appointment_${appointmentId}_${operationId}`);
    let resultingStatus = "";
    await db.runTransaction(async (transaction) => {
      const [current, previousOperation] = await Promise.all([
        transaction.get(appointment), transaction.get(history),
      ]);
      if (previousOperation.exists) {
        const previousHash = String(previousOperation.data()?.operationHash ?? "");
        if (previousHash && previousHash !== operationHash) {
          throw new HttpsError("already-exists", "This operation ID was already used with different details.");
        }
        resultingStatus = String(previousOperation.data()?.status ?? "");
        return;
      }
      if (!current.exists) throw new HttpsError("not-found", "Appointment not found.");
      const data = current.data()!;
      const before = canonicalAppointmentStatus(data.status);
      if (!before) throw new HttpsError("failed-precondition", "This appointment has an unsupported status.");
      let after: AppointmentLifecycleStatus;
      const patch: Record<string, unknown> = {
        assignedStaffId: actor.uid, counselorName: actor.displayName, staffReply: reply,
        reviewedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      };
      if (requestedAction === "withdraw_reschedule") {
        if (before !== "reschedule_proposed") throw new HttpsError("failed-precondition", "No reschedule proposal is active.");
        after = canonicalAppointmentStatus(data.statusBeforeReschedule) ?? "pending";
        Object.assign(patch, {status: after, proposedScheduledAt: FieldValue.delete(), proposedScheduledTime: FieldValue.delete(), statusBeforeReschedule: FieldValue.delete(), proposedBy: FieldValue.delete(), proposedAt: FieldValue.delete()});
      } else {
        after = action!;
        if (!canTransitionAppointment(before, after)) {
          throw new HttpsError("failed-precondition", "This appointment cannot take that action from its current status.");
        }
        patch.status = after;
        if (after === "reschedule_proposed") {
          patch.statusBeforeReschedule = before === "reschedule_proposed" ? data.statusBeforeReschedule ?? "pending" : before;
          patch.proposedScheduledAt = proposed!.at;
          patch.proposedScheduledTime = proposed!.time;
          patch.proposedBy = actor.uid;
          patch.proposedAt = FieldValue.serverTimestamp();
        } else {
          patch.proposedScheduledAt = FieldValue.delete();
          patch.proposedScheduledTime = FieldValue.delete();
          if (after === "ongoing") patch.startedAt = FieldValue.serverTimestamp();
          if (after === "completed") patch.completedAt = FieldValue.serverTimestamp();
        }
      }
      resultingStatus = after;
      const userId = String(data.userId ?? "");
      if (!userId) throw new HttpsError("failed-precondition", "Appointment has no app user.");
      transaction.update(appointment, patch);
      transaction.create(history, {
        operationId, operationHash, eventType: requestedAction, previousStatus: before, status: after,
        reply, actorId: actor.uid, actorName: actor.displayName, actorRole: actor.accessRole,
        proposedScheduledAt: proposed?.at ?? null, proposedScheduledTime: proposed?.time ?? "",
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(notification, {
        userId, appointmentId, type: "appointment", title: after === "reschedule_proposed" ?
          "New appointment time proposed" : `Appointment ${after.replace(/_/g, " ")}`,
        body: reply, createdAt: FieldValue.serverTimestamp(), readAt: null,
      });
    });
    return {ok: true, status: resultingStatus, correlationId};
  } catch (error) {
    responseError(error, correlationId);
  }
}

export const reviewAppointment = onCall({enforceAppCheck: true}, reviewAppointmentHandler);
export const reviewAppointmentDev = onCall({enforceAppCheck: false}, reviewAppointmentHandler);

async function respondToAppointmentRescheduleHandler(request: CallableRequest) {
  const correlationId = randomUUID();
  try {
    const uid = authenticatedUid(request);
    const input = request.data as Record<string, unknown>;
    const appointmentId = identifier(input.appointmentId, "Appointment ID");
    const operationId = identifier(input.operationId, "Operation ID");
    const response = String(input.response ?? "");
    if (!["accept", "decline"].includes(response)) throw new HttpsError("invalid-argument", "Choose accept or decline.");
    const operationHash = hash({response});
    const db = getFirestore();
    const appointment = db.collection("appointments").doc(appointmentId);
    const history = appointment.collection("history").doc(`op_${operationId}`);
    let result: Record<string, unknown> = {};
    await db.runTransaction(async (transaction) => {
      const [current, previousOperation] = await Promise.all([transaction.get(appointment), transaction.get(history)]);
      if (previousOperation.exists) {
        const previousHash = String(previousOperation.data()?.operationHash ?? "");
        if (previousHash && previousHash !== operationHash) {
          throw new HttpsError("already-exists", "This operation ID was already used with a different response.");
        }
        result = previousOperation.data() ?? {};
        return;
      }
      if (!current.exists || current.data()?.userId !== uid) throw new HttpsError("permission-denied", "This appointment does not belong to you.");
      const data = current.data()!;
      if (canonicalAppointmentStatus(data.status) !== "reschedule_proposed" || !(data.proposedScheduledAt instanceof Timestamp)) {
        throw new HttpsError("failed-precondition", "This reschedule proposal is no longer available.");
      }
      let legacyHistory: Array<{previousStatus?: unknown}> = [];
      if (!canonicalAppointmentStatus(data.statusBeforeReschedule)) {
        const recent = await transaction.get(
          appointment.collection("history").orderBy("createdAt", "desc").limit(20),
        );
        legacyHistory = recent.docs.map((document) => document.data());
      }
      const restored = rescheduleRestoreStatus(data.statusBeforeReschedule, legacyHistory);
      const after: AppointmentLifecycleStatus = response === "accept" ? "confirmed" : restored;
      const patch: Record<string, unknown> = {
        status: after, updatedAt: FieldValue.serverTimestamp(),
        proposedScheduledAt: FieldValue.delete(), proposedScheduledTime: FieldValue.delete(),
        statusBeforeReschedule: FieldValue.delete(), proposedBy: FieldValue.delete(), proposedAt: FieldValue.delete(),
      };
      if (response === "accept") {
        if (data.proposedScheduledAt.toMillis() < Date.now() - 60_000) {
          throw new HttpsError("failed-precondition", "The proposed time has passed. Ask staff for a new schedule.");
        }
        patch.scheduledAt = data.proposedScheduledAt;
        patch.scheduledTime = String(data.proposedScheduledTime ?? "");
      }
      transaction.update(appointment, patch);
      result = {status: after, scheduledAt: response === "accept" ? data.proposedScheduledAt.toMillis() : data.scheduledAt?.toMillis(), scheduledTime: response === "accept" ? data.proposedScheduledTime : data.scheduledTime};
      transaction.create(history, {
        operationId, operationHash, eventType: `reschedule_${response}d`, previousStatus: "reschedule_proposed",
        status: after, reply: response === "accept" ? "Reschedule accepted" : "Reschedule declined",
        scheduledAt: result.scheduledAt,
        scheduledTime: result.scheduledTime,
        actorId: uid, actorName: "App user", actorRole: "appUser", createdAt: FieldValue.serverTimestamp(),
      });
      const assignedStaffId = String(data.assignedStaffId ?? "");
      if (assignedStaffId) {
        transaction.create(
          db.collection("notifications").doc(`appointment_response_${appointmentId}_${operationId}`),
          {
            userId: assignedStaffId,
            appointmentId,
            type: "appointment",
            title: response === "accept" ? "Reschedule accepted" : "Reschedule declined",
            body: response === "accept" ?
              "The app user accepted the proposed appointment time." :
              "The app user declined the proposed appointment time.",
            createdAt: FieldValue.serverTimestamp(),
            readAt: null,
          },
        );
      }
    });
    return {ok: true, ...result, correlationId};
  } catch (error) {
    responseError(error, correlationId);
  }
}

export const respondToAppointmentReschedule = onCall({enforceAppCheck: true}, respondToAppointmentRescheduleHandler);
export const respondToAppointmentRescheduleDev = onCall({enforceAppCheck: false}, respondToAppointmentRescheduleHandler);

async function scheduleAppointmentFollowUpHandler(request: CallableRequest) {
  const correlationId = randomUUID();
  try {
    const actor = await requireApprovedPortalActor(request);
    const input = request.data as Record<string, unknown>;
    const sourceAppointmentId = identifier(input.sourceAppointmentId, "Source appointment ID");
    const desired = schedule(input);
    const location = text(input.location, "Location", 2, 150);
    const reply = text(input.reply, "Reply", 1, 1000);
    const db = getFirestore();
    const source = db.collection("appointments").doc(sourceAppointmentId);
    const followUp = db.collection("appointments").doc(`followup_${sourceAppointmentId}`);
    const payloadHash = hash({scheduledAt: desired.at.toMillis(), scheduledTime: desired.time, location, reply});
    let existing = false;
    await db.runTransaction(async (transaction) => {
      const [current, child] = await Promise.all([transaction.get(source), transaction.get(followUp)]);
      if (child.exists) {
        if (child.data()?.followUpPayloadHash !== payloadHash) {
          throw new HttpsError("already-exists", "This completed appointment already has a different follow-up.");
        }
        existing = true;
        return;
      }
      if (!current.exists || canonicalAppointmentStatus(current.data()?.status) !== "completed") {
        throw new HttpsError("failed-precondition", "Only a completed appointment can receive a follow-up.");
      }
      const sourceData = current.data()!;
      const rootAppointmentId = String(sourceData.rootAppointmentId ?? sourceAppointmentId);
      const copied: Record<string, unknown> = {};
      for (const field of ["userId", "fullName", "age", "address", "contactNumber", "email", "facebook", "sex", "course", "yearLevel", "populationRole", "preferredContactMethod", "therapyBefore", "concern", "bestTime"]) {
        if (sourceData[field] !== undefined) copied[field] = sourceData[field];
      }
      transaction.create(followUp, {...copied, status: "pending", scheduledAt: desired.at, scheduledTime: desired.time,
        location, parentAppointmentId: sourceAppointmentId, rootAppointmentId, assignedStaffId: actor.uid,
        counselorName: actor.displayName, staffReply: reply, followUpPayloadHash: payloadHash,
        createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
      transaction.create(source.collection("history").doc(`followup_${sourceAppointmentId}`), {
        eventType: "follow_up_scheduled", previousStatus: "completed", status: "completed",
        linkedAppointmentId: followUp.id, reply, actorId: actor.uid, actorName: actor.displayName,
        actorRole: actor.accessRole, createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(followUp.collection("history").doc("created"), {
        eventType: "follow_up_created", previousStatus: null, status: "pending",
        parentAppointmentId: sourceAppointmentId, rootAppointmentId, reply,
        actorId: actor.uid, actorName: actor.displayName, actorRole: actor.accessRole,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(db.collection("notifications").doc(`followup_${sourceAppointmentId}`), {
        userId: sourceData.userId, appointmentId: followUp.id, type: "appointment",
        title: "Follow-up appointment scheduled", body: reply,
        createdAt: FieldValue.serverTimestamp(), readAt: null,
      });
    });
    return {ok: true, appointmentId: followUp.id, existing, correlationId};
  } catch (error) {
    responseError(error, correlationId);
  }
}

export const scheduleAppointmentFollowUp = onCall({enforceAppCheck: true}, scheduleAppointmentFollowUpHandler);
export const scheduleAppointmentFollowUpDev = onCall({enforceAppCheck: false}, scheduleAppointmentFollowUpHandler);
