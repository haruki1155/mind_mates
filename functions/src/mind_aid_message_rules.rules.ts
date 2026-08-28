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
    projectId: "mind-mates-mind-aid-message-rules-test",
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

function message(
  userId: string,
  overrides: Partial<{
    sender: string;
    text: string;
    conversationId: string;
  }> = {},
) {
  return {
    userId,
    sender: overrides.sender ?? "user",
    text: overrides.text ?? "I feel stressed about exams.",
    conversationId: overrides.conversationId ?? "conversation-1",
  };
}

test("an owner can create, read, and delete a valid Mind Aid message", async () => {
  const db = environment.authenticatedContext("owner").firestore();
  const entry = doc(db, "mind_aid_messages/message-owner-1");

  await assertSucceeds(setDoc(entry, message("owner")));
  await assertSucceeds(getDoc(entry));
  await assertSucceeds(deleteDoc(entry));
});

test("owner-created Mind Aid messages require valid sender and bounded text", async () => {
  const db = environment.authenticatedContext("owner").firestore();

  await assertFails(
    setDoc(
      doc(db, "mind_aid_messages/message-invalid-sender"),
      message("owner", {sender: "system"}),
    ),
  );
  await assertFails(
    setDoc(
      doc(db, "mind_aid_messages/message-empty-text"),
      message("owner", {text: ""}),
    ),
  );
  await assertFails(
    setDoc(
      doc(db, "mind_aid_messages/message-long-text"),
      message("owner", {text: "x".repeat(1601)}),
    ),
  );
  await assertFails(
    setDoc(
      doc(db, "mind_aid_messages/message-long-conversation"),
      message("owner", {conversationId: "x".repeat(65)}),
    ),
  );
});

test("another user cannot read, update, or delete an owner's message", async () => {
  const ownerDb = environment.authenticatedContext("owner").firestore();
  const otherDb = environment.authenticatedContext("other").firestore();
  const ownerEntry = doc(ownerDb, "mind_aid_messages/message-owner-2");
  const otherEntry = doc(otherDb, "mind_aid_messages/message-owner-2");

  await assertSucceeds(setDoc(ownerEntry, message("owner")));
  await assertFails(getDoc(otherEntry));
  await assertFails(updateDoc(otherEntry, {text: "tampered"}));
  await assertFails(deleteDoc(otherEntry));
});

test("clients cannot update an existing Mind Aid message", async () => {
  const db = environment.authenticatedContext("owner").firestore();
  const entry = doc(db, "mind_aid_messages/message-immutable");

  await assertSucceeds(setDoc(entry, message("owner")));
  await assertFails(updateDoc(entry, {text: "edited"}));
});
