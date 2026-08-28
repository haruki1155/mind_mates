import {Timestamp, FieldValue, getFirestore} from "firebase-admin/firestore";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {manilaDateKey, writeQualifyingWellnessState} from "./wellness";

const db = getFirestore();
const techniques: Record<string, {title: string; durationSeconds: number}> = {
  emergency_reset: {title: "Emergency Reset Breath", durationSeconds: 30},
  cyclic_sighing: {title: "Cyclic Sighing Mini Reset", durationSeconds: 60},
  long_exhale: {title: "Long Exhale Breathing", durationSeconds: 120},
  box_breathing: {title: "Box Breathing", durationSeconds: 180},
  balanced_calm: {title: "Balanced Calm Breathing", durationSeconds: 240},
  nhs_calm: {title: "NHS Calm Breathing", durationSeconds: 300},
  four_seven_eight: {title: "4-7-8 Breathing", durationSeconds: 420},
  belly_breathing: {title: "Belly / Diaphragmatic Breathing", durationSeconds: 600},
  mindful_session: {title: "Mindful Breathing Session", durationSeconds: 900},
  full_relaxation: {title: "Full Relaxation Routine", durationSeconds: 1200},
};
const sessionIdPattern = /^[A-Za-z0-9_-]{16,80}$/;
const moodTechniquePattern = /^mood_(anger|anxiety|stress|overwhelm)_([1-6])m$/;

function requireUid(request: {auth?: {uid?: string}}): string {
  const uid = request.auth?.uid?.trim();
  if (!uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  return uid;
}

export function breathingTechnique(value: unknown): {id: string; title: string; durationSeconds: number} {
  const id = typeof value === "string" ? value.trim() : "";
  const curated = techniques[id];
  if (curated) return {id, ...curated};
  const mood = moodTechniquePattern.exec(id);
  if (!mood) throw new HttpsError("invalid-argument", "Choose a valid breathing technique.");
  const minutes = Number(mood[2]);
  return {id, title: `${mood[1]} breathing`, durationSeconds: minutes * 60};
}

function sessionId(value: unknown): string {
  const id = typeof value === "string" ? value.trim() : "";
  if (!sessionIdPattern.test(id)) {
    throw new HttpsError("invalid-argument", "The breathing session identifier is invalid.");
  }
  return id;
}

async function startBreathingSessionHandler(request: CallableRequest) {
  const userId = requireUid(request);
  const id = sessionId(request.data?.sessionId);
  const technique = breathingTechnique(request.data?.techniqueId);
  const ref = db.collection("breathing_sessions").doc(id);
  const lock = db.collection("breathing_session_locks").doc(userId);
  const now = Timestamp.now();
  await db.runTransaction(async (transaction) => {
    const [existing, activeLock] = await Promise.all([
      transaction.get(ref), transaction.get(lock),
    ]);
    if (existing.exists) {
      const data = existing.data()!;
      if (data.userId !== userId || data.techniqueId !== technique.id) {
        throw new HttpsError("already-exists", "A different session already uses this identifier.");
      }
      return;
    }
    const lockExpiry = activeLock.data()?.expiresAt;
    if (lockExpiry instanceof Timestamp && lockExpiry.toMillis() > now.toMillis()) {
      throw new HttpsError("failed-precondition", "Finish or leave your current breathing session before starting another.");
    }
    transaction.create(ref, {
      userId,
      techniqueId: technique.id,
      techniqueTitle: technique.title,
      durationSeconds: technique.durationSeconds,
      completedSeconds: 0,
      completed: false,
      status: "active",
      startedAt: now,
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.set(lock, {
      sessionId: id,
      expiresAt: Timestamp.fromMillis(now.toMillis() + (technique.durationSeconds + 300) * 1000),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return {ok: true, sessionId: id};
}

async function completeBreathingSessionHandler(request: CallableRequest) {
  const userId = requireUid(request);
  const id = sessionId(request.data?.sessionId);
  const technique = breathingTechnique(request.data?.techniqueId);
  const session = db.collection("breathing_sessions").doc(id);
  const lock = db.collection("breathing_session_locks").doc(userId);
  const activity = db.collection("user_activities").doc(`breathing_${id}`);
  const user = db.collection("users").doc(userId);
  const now = Timestamp.now();
  const nowDate = now.toDate();
  let alreadyCompleted = false;

  await db.runTransaction(async (transaction) => {
    const [sessionSnapshot, userSnapshot] = await Promise.all([
      transaction.get(session), transaction.get(user),
    ]);
    if (!sessionSnapshot.exists) throw new HttpsError("not-found", "This breathing session was not started.");
    const data = sessionSnapshot.data()!;
    if (data.userId !== userId || data.techniqueId !== technique.id ||
        data.durationSeconds !== technique.durationSeconds) {
      throw new HttpsError("failed-precondition", "This breathing session does not match the selected exercise.");
    }
    if (data.status === "completed") {
      alreadyCompleted = true;
      return;
    }
    const startedAt = data.startedAt instanceof Timestamp ? data.startedAt.toDate() : null;
    if (!startedAt || nowDate.getTime() - startedAt.getTime() < (technique.durationSeconds - 3) * 1000) {
      throw new HttpsError("failed-precondition", "Finish the breathing timer before completing this session.");
    }
    if (!userSnapshot.exists) throw new HttpsError("failed-precondition", "Your account profile is unavailable.");
    const profile = userSnapshot.data()!;
    const today = manilaDateKey(now);
    transaction.update(session, {
      completed: true,
      status: "completed",
      completedSeconds: technique.durationSeconds,
      completedAt: now,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(activity, {
      userId,
      type: "breathingSession",
      sourceId: id,
      dateKey: today,
      occurredAt: now,
      createdAt: FieldValue.serverTimestamp(),
    });
    writeQualifyingWellnessState(transaction, user, profile, now, today);
    transaction.delete(lock);
  });
  return {ok: true, sessionId: id, alreadyCompleted};
}

export const startBreathingSession = onCall({enforceAppCheck: true}, startBreathingSessionHandler);
export const startBreathingSessionDev = onCall({enforceAppCheck: false}, startBreathingSessionHandler);
export const completeBreathingSession = onCall({enforceAppCheck: true}, completeBreathingSessionHandler);
export const completeBreathingSessionDev = onCall({enforceAppCheck: false}, completeBreathingSessionHandler);
