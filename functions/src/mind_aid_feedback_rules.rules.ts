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
    projectId: "mind-mates-mind-aid-feedback-rules-test",
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

function feedback(userId: string, helpful = true) {
  return {
    userId,
    messageId: "assistant-message-1",
    helpful,
  };
}

test("an owner can create, read, update, and delete valid Mind Aid feedback", async () => {
  const db = environment.authenticatedContext("owner").firestore();
  const entry = doc(db, "mind_aid_feedback/owner_assistant-message-1");

  await assertSucceeds(setDoc(entry, feedback("owner")));
  await assertSucceeds(getDoc(entry));
  await assertSucceeds(updateDoc(entry, {helpful: false}));
  await assertSucceeds(deleteDoc(entry));
});

test("Mind Aid feedback requires string message IDs and boolean values", async () => {
  const db = environment.authenticatedContext("owner").firestore();

  await assertFails(
    setDoc(doc(db, "mind_aid_feedback/invalid-message"), {
      ...feedback("owner"),
      messageId: 1,
    }),
  );
  await assertFails(
    setDoc(doc(db, "mind_aid_feedback/invalid-helpful"), {
      ...feedback("owner"),
      helpful: "yes",
    }),
  );
});

test("an owner cannot transfer Mind Aid feedback to another user", async () => {
  const db = environment.authenticatedContext("owner").firestore();
  const entry = doc(db, "mind_aid_feedback/owner_assistant-message-2");

  await assertSucceeds(setDoc(entry, feedback("owner")));
  await assertFails(updateDoc(entry, {userId: "other"}));
});

test("another user cannot read, update, or delete an owner's feedback", async () => {
  const ownerDb = environment.authenticatedContext("owner").firestore();
  const otherDb = environment.authenticatedContext("other").firestore();
  const ownerEntry = doc(
    ownerDb,
    "mind_aid_feedback/owner_assistant-message-3",
  );
  const otherEntry = doc(
    otherDb,
    "mind_aid_feedback/owner_assistant-message-3",
  );

  await assertSucceeds(setDoc(ownerEntry, feedback("owner")));
  await assertFails(getDoc(otherEntry));
  await assertFails(updateDoc(otherEntry, {helpful: false}));
  await assertFails(deleteDoc(otherEntry));
});
