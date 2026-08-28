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
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  Timestamp,
  updateDoc,
} from "firebase/firestore";

let environment: RulesTestEnvironment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: "mind-mates-breathing-session-rules-test",
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

function session(userId: string, completedSeconds = 300) {
  return {
    userId,
    completedSeconds,
    occurredAt: Timestamp.fromDate(new Date("2026-07-18T08:00:00Z")),
  };
}

test("clients cannot create, update, or delete breathing sessions", async () => {
  const db = environment.authenticatedContext("owner").firestore();
  const entry = doc(db, "breathing_sessions/session-owner-1");

  await assertFails(setDoc(entry, session("owner")));
  await assertFails(updateDoc(entry, {completedSeconds: 600}));
  await assertFails(deleteDoc(entry));
});

test("another user cannot read, update, or delete an owner's breathing session", async () => {
  const ownerDb = environment.authenticatedContext("owner").firestore();
  const otherDb = environment.authenticatedContext("other").firestore();
  const ownerEntry = doc(ownerDb, "breathing_sessions/session-owner-2");
  const otherEntry = doc(otherDb, "breathing_sessions/session-owner-2");

  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "breathing_sessions/session-owner-2"), session("owner"));
  });
  await assertSucceeds(getDoc(ownerEntry));
  await assertFails(getDoc(otherEntry));
  await assertFails(updateDoc(otherEntry, {completedSeconds: 1}));
  await assertFails(deleteDoc(otherEntry));
});
