import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {manilaDateKey, writeQualifyingWellnessState} from "./wellness";

const db = getFirestore();

const moods = {
  great: {label: "Great", level: 5},
  okay: {label: "Okay", level: 4},
  tired: {label: "Tired", level: 3},
  stressed: {label: "Stressed", level: 2},
  sad: {label: "Sad", level: 1},
  angry: {label: "Angry", level: 1},
  excited: {label: "Excited", level: 5},
} as const;

type MoodKey = keyof typeof moods;

function requestUid(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  return uid;
}

function parseRequest(raw: unknown): {moodKey: MoodKey; note: string} {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new HttpsError("invalid-argument", "A mood check-in is required.");
  }
  const data = raw as Record<string, unknown>;
  if (Object.keys(data).some((key) => key !== "moodKey" && key !== "note")) {
    throw new HttpsError("invalid-argument", "The mood request contains unsupported fields.");
  }
  const moodKey = typeof data.moodKey === "string" ? data.moodKey : "";
  if (!(moodKey in moods)) throw new HttpsError("invalid-argument", "Choose a valid mood.");
  if (data.note != null && typeof data.note !== "string") {
    throw new HttpsError("invalid-argument", "The mood note is invalid.");
  }
  const note = (data.note ?? "").trim();
  if (note.length > 300) throw new HttpsError("invalid-argument", "The mood note is too long.");
  return {moodKey: moodKey as MoodKey, note};
}

function serializeMood(id: string, data: Record<string, unknown>, fallback: Timestamp) {
  const createdAt = data.createdAt instanceof Timestamp ? data.createdAt : fallback;
  return {
    id,
    moodKey: String(data.moodKey ?? ""),
    label: String(data.label ?? ""),
    level: Number(data.level ?? 0),
    note: String(data.note ?? ""),
    dateKey: String(data.dateKey ?? ""),
    createdAtMillis: createdAt.toMillis(),
  };
}

export async function logDailyMoodHandler(request: CallableRequest) {
  const userId = requestUid(request);
  const input = parseRequest(request.data);
  const occurredAt = Timestamp.now();
  const dateKey = manilaDateKey(occurredAt);
  const moodId = `daily_${userId}_${dateKey}`;
  const moodRef = db.collection("moods").doc(moodId);
  const activityRef = db.collection("user_activities").doc(`moodCheckIn_${moodId}`);
  const userRef = db.collection("users").doc(userId);
  let response: Record<string, unknown> = {};

  await db.runTransaction(async (transaction) => {
    const [existingMood, userSnapshot] = await Promise.all([
      transaction.get(moodRef),
      transaction.get(userRef),
    ]);
    if (!userSnapshot.exists) {
      throw new HttpsError("failed-precondition", "Your account profile is unavailable.");
    }
    const profile = userSnapshot.data() ?? {};
    if (existingMood.exists) {
      response = {
        created: false,
        mood: serializeMood(moodId, existingMood.data() ?? {}, occurredAt),
        dayStreak: Number(profile.dayStreak ?? 0) || 0,
        longestStreak: Number(profile.longestStreak ?? 0) || 0,
      };
      return;
    }

    const mood = moods[input.moodKey];
    transaction.create(moodRef, {
      schemaVersion: 2,
      userId,
      moodKey: input.moodKey,
      label: mood.label,
      level: mood.level,
      note: input.note,
      dateKey,
      timezone: "Asia/Manila",
      createdAt: occurredAt,
    });
    transaction.create(activityRef, {
      userId,
      type: "moodCheckIn",
      sourceId: moodId,
      dateKey,
      occurredAt,
      createdAt: FieldValue.serverTimestamp(),
    });
    const streak = writeQualifyingWellnessState(
      transaction, userRef, profile, occurredAt, dateKey,
    );
    response = {
      created: true,
      mood: {
        id: moodId,
        moodKey: input.moodKey,
        label: mood.label,
        level: mood.level,
        note: input.note,
        dateKey,
        createdAtMillis: occurredAt.toMillis(),
      },
      dayStreak: streak.dayStreak,
      longestStreak: streak.longestStreak,
    };
  });
  return response;
}

export const logDailyMood = onCall({enforceAppCheck: true}, logDailyMoodHandler);
