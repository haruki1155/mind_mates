import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {after, before, beforeEach, test} from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {deleteDoc, doc, getDoc, serverTimestamp, setDoc, updateDoc} from "firebase/firestore";

let environment: RulesTestEnvironment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: "mind-mates-mood-rules-test",
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

function validMood(userId: string, dateKey = "20260718") {
  return {
    userId,
    moodKey: "great",
    schemaVersion: 2,
    level: 4,
    label: "Good",
    note: "A manageable day.",
    dateKey,
    timezone: "Asia/Manila",
    createdAt: serverTimestamp(),
  };
}

test("an app user can read but cannot directly mutate their own mood", async () => {
  const ownerDb = environment.authenticatedContext("owner").firestore();
  const mood = doc(ownerDb, "moods/daily_owner_20260718");
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "moods/daily_owner_20260718"), validMood("owner"));
  });
  await assertSucceeds(getDoc(mood));
  await assertFails(setDoc(mood, validMood("owner")));
  await assertFails(updateDoc(mood, {note: "tampered"}));
  await assertFails(deleteDoc(mood));
  await assertFails(
    getDoc(
      doc(
        environment.authenticatedContext("other").firestore(),
        "moods/daily_owner_20260718",
      ),
    ),
  );
});

test("an app user cannot create a mood for any identity", async () => {
  const ownerDb = environment.authenticatedContext("owner").firestore();
  const otherDb = environment.authenticatedContext("other").firestore();

  await assertFails(
    setDoc(
      doc(ownerDb, "moods/daily_owner_20260719"),
      validMood("other", "20260719"),
    ),
  );
  await assertFails(
    setDoc(
      doc(otherDb, "moods/daily_other_20260719"),
      validMood("owner", "20260719"),
    ),
  );
});
