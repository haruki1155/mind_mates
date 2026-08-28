import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {manilaDateKey} from "./wellness";

const db = getFirestore();

async function recordAnalyticsActivity(type: string, sourceId: string, userId: unknown): Promise<void> {
  if (typeof userId !== "string" || !userId) return;
  const occurredAt = Timestamp.now();
  const activity = db.collection("user_activities").doc(`${type}_${sourceId}`);
  const user = db.collection("users").doc(userId);
  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(activity)).exists) return;
    transaction.create(activity, {
      userId, type, sourceId, dateKey: manilaDateKey(occurredAt), occurredAt,
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.set(user, {lastActiveAt: occurredAt}, {merge: true});
  });
}

export const recordSecretChatPostActivity = onDocumentCreated(
  "secret_chats/{postId}",
  async (event) => recordAnalyticsActivity("secretChatPost", event.params.postId, event.data?.data().authorId),
);

export const recordSecretChatCommentActivity = onDocumentCreated(
  "secret_chat_comments/{commentId}",
  async (event) => recordAnalyticsActivity("secretChatComment", event.params.commentId, event.data?.data().authorId),
);
