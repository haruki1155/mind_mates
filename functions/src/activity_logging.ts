import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {manilaDateKey} from "./wellness";

const db = getFirestore();

export async function recordAppOpenHandler(request: CallableRequest) {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError("unauthenticated", "Sign in is required.");
  if (request.data != null &&
      (typeof request.data !== "object" || Array.isArray(request.data) || Object.keys(request.data).length > 0)) {
    throw new HttpsError("invalid-argument", "App-open tracking does not accept data.");
  }
  const occurredAt = Timestamp.now();
  const dateKey = manilaDateKey(occurredAt);
  const activity = db.collection("user_activities").doc(`appOpen_${userId}_${dateKey}`);
  const user = db.collection("users").doc(userId);
  await db.runTransaction(async (transaction) => {
    if (!(await transaction.get(activity)).exists) {
      transaction.create(activity, {
        userId, type: "appOpen", sourceId: `${userId}_${dateKey}`, dateKey, occurredAt,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    transaction.set(user, {lastActiveAt: occurredAt}, {merge: true});
  });
  return {recordedAtMillis: occurredAt.toMillis()};
}

export const recordAppOpen = onCall({enforceAppCheck: true}, recordAppOpenHandler);
