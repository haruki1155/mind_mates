import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {after, before, beforeEach, test} from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {deleteDoc, doc, getDoc, setDoc, updateDoc} from "firebase/firestore";

let environment: RulesTestEnvironment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: "mind-mates-mind-aid-preference-rules-test",
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

function preferences(userId: string) {
  return {
    userId,
    hasDecision: true,
    cloudConsent: true,
    personalizationEnabled: true,
    conversationId: "conversation-1",
  };
}

test("an owner can create, read, update, and delete their Mind Aid preferences", async () => {
  const db = environment.authenticatedContext("owner").firestore();
  const entry = doc(db, "mind_aid_preferences/owner");

  await assertSucceeds(setDoc(entry, preferences("owner")));
  await assertSucceeds(getDoc(entry));
  await assertSucceeds(updateDoc(entry, {personalizationEnabled: false}));
  await assertFails(updateDoc(entry, {userId: "other"}));
  await assertSucceeds(deleteDoc(entry));
});

test("Mind Aid preferences require valid booleans and conversation IDs", async () => {
  const db = environment.authenticatedContext("owner").firestore();

  await assertFails(
    setDoc(doc(db, "mind_aid_preferences/owner"), {
      ...preferences("owner"),
      hasDecision: "yes",
    }),
  );
  await assertFails(
    setDoc(doc(db, "mind_aid_preferences/owner"), {
      ...preferences("owner"),
      conversationId: "short",
    }),
  );
  await assertFails(
    setDoc(doc(db, "mind_aid_preferences/owner"), {
      ...preferences("owner"),
      conversationId: "x".repeat(65),
    }),
  );
});

test("another user cannot read or write an owner's Mind Aid preferences", async () => {
  const ownerDb = environment.authenticatedContext("owner").firestore();
  const otherDb = environment.authenticatedContext("other").firestore();
  const ownerEntry = doc(ownerDb, "mind_aid_preferences/owner");
  const otherEntry = doc(otherDb, "mind_aid_preferences/owner");

  await assertSucceeds(setDoc(ownerEntry, preferences("owner")));
  await assertFails(getDoc(otherEntry));
  await assertFails(setDoc(otherEntry, preferences("other")));
  await assertFails(updateDoc(otherEntry, {personalizationEnabled: false}));
  await assertFails(deleteDoc(otherEntry));
});
