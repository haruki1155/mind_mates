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
    projectId: "mind-mates-user-activity-rules-test",
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

function activity(userId: string, label = "mood check-in") {
  return {
    userId,
    type: "mood",
    label,
    occurredAt: Timestamp.fromDate(new Date("2026-07-18T08:00:00Z")),
  };
}

test("an owner can read but cannot directly mutate their activity", async () => {
  const db = environment.authenticatedContext("owner").firestore();
  const entry = doc(db, "user_activities/activity-owner-1");
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "user_activities/activity-owner-1"), activity("owner"));
  });
  await assertSucceeds(getDoc(entry));
  await assertFails(setDoc(entry, activity("owner")));
  await assertFails(updateDoc(entry, {label: "updated mood check-in"}));
  await assertFails(deleteDoc(entry));
});

test("another user cannot read, update, or delete an owner's activity", async () => {
  const ownerDb = environment.authenticatedContext("owner").firestore();
  const otherDb = environment.authenticatedContext("other").firestore();
  const ownerEntry = doc(ownerDb, "user_activities/activity-owner-2");
  const otherEntry = doc(otherDb, "user_activities/activity-owner-2");

  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "user_activities/activity-owner-2"), activity("owner"));
  });
  await assertFails(getDoc(otherEntry));
  await assertFails(updateDoc(otherEntry, {label: "tampered"}));
  await assertFails(deleteDoc(otherEntry));
});
