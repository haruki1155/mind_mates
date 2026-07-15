import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {randomBytes} from "node:crypto";

if (!getApps().length) initializeApp();
const db = getFirestore();
const apply = process.argv.includes("--apply");
const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function candidate(): string {
  return `USR-${Array.from(randomBytes(6), (byte) => alphabet[byte % alphabet.length]).join("")}`;
}

async function allocate(userId: string): Promise<void> {
  const mapping = db.collection("user_public_ids").doc(userId);
  if ((await mapping.get()).exists) return;
  for (let attempt = 0; attempt < 12; attempt++) {
    const publicUserId = candidate();
    const reservation = db.collection("public_user_id_reservations").doc(publicUserId);
    try {
      await db.runTransaction(async (transaction) => {
        const [current, reserved] = await Promise.all([transaction.get(mapping), transaction.get(reservation)]);
        if (current.exists) return;
        if (reserved.exists) throw new Error("collision");
        transaction.create(reservation, {userId, createdAt: FieldValue.serverTimestamp()});
        transaction.create(mapping, {publicUserId, createdAt: FieldValue.serverTimestamp()});
      });
      return;
    } catch (error) {
      if (!(error instanceof Error) || error.message !== "collision") throw error;
    }
  }
  throw new Error(`Could not allocate a public ID for ${userId}`);
}

async function main(): Promise<void> {
  const users = await db.collection("users").get();
  const appUsers = users.docs.filter((doc) => {
    const data = doc.data();
    return data.staffAccountStatus == null && data.accessRole !== "admin";
  });
  const mappings = await Promise.all(appUsers.map((doc) => db.collection("user_public_ids").doc(doc.id).get()));
  const missing = appUsers.filter((_, index) => !mappings[index].exists);
  console.log(JSON.stringify({mode: apply ? "apply" : "dry-run", appUsers: appUsers.length, missing: missing.length}));
  if (apply) await Promise.all(missing.map((doc) => allocate(doc.id)));
}

void main();
