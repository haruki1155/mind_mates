import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {after, before, beforeEach, test} from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from "firebase/firestore";

let environment: RulesTestEnvironment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: "mind-mates-notification-rules-test",
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

function notification(userId: string) {
  return {
    userId,
    title: "Appointment update",
    body: "Your appointment status changed.",
    type: "appointment",
    createdAt: Timestamp.fromDate(new Date("2026-07-18T08:00:00Z")),
    readAt: null,
  };
}

async function seedNotifications(): Promise<void> {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "notifications/notification-owner"),
      notification("owner"),
    );
    await setDoc(
      doc(context.firestore(), "notifications/notification-other"),
      notification("other"),
    );
  });
}

test("an owner can read their notification and constrained notification query", async () => {
  await seedNotifications();
  const db = environment.authenticatedContext("owner").firestore();

  await assertSucceeds(
    getDoc(doc(db, "notifications/notification-owner")),
  );
  await assertSucceeds(
    getDocs(
      query(
        collection(db, "notifications"),
        where("userId", "==", "owner"),
      ),
    ),
  );
});

test("an owner can update only the readAt field", async () => {
  await seedNotifications();
  const db = environment.authenticatedContext("owner").firestore();
  const entry = doc(db, "notifications/notification-owner");

  await assertSucceeds(updateDoc(entry, {readAt: serverTimestamp()}));
  await assertFails(updateDoc(entry, {title: "Tampered"}));
  await assertFails(updateDoc(entry, {userId: "other"}));
});

test("another user cannot read or update an owner's notification", async () => {
  await seedNotifications();
  const db = environment.authenticatedContext("other").firestore();
  const ownerEntry = doc(db, "notifications/notification-owner");

  await assertFails(getDoc(ownerEntry));
  await assertFails(updateDoc(ownerEntry, {readAt: serverTimestamp()}));
  await assertFails(
    getDocs(
      query(
        collection(db, "notifications"),
        where("userId", "==", "owner"),
      ),
    ),
  );
});

test("clients cannot create or delete notifications", async () => {
  await seedNotifications();
  const db = environment.authenticatedContext("owner").firestore();

  await assertFails(
    setDoc(
      doc(db, "notifications/client-created"),
      notification("owner"),
    ),
  );
  await assertFails(
    deleteDoc(doc(db, "notifications/notification-owner")),
  );
});
