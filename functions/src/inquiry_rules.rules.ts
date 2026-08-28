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
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} from "firebase/firestore";

let environment: RulesTestEnvironment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: "mind-mates-inquiry-rules-test",
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

function inquiry(userId: string) {
  return {
    userId,
    subject: "Counseling schedule",
    message: "I would like to ask about available counseling schedules.",
    category: "Counseling",
    email: "owner@example.com",
    name: "Owner User",
    role: "student",
    status: "pending",
    createdAt: serverTimestamp(),
  };
}

test("an owner can create and read a valid inquiry", async () => {
  const db = environment.authenticatedContext("owner").firestore();
  const entry = doc(db, "inquiries/inquiry-owner-1");

  await assertSucceeds(setDoc(entry, inquiry("owner")));
  await assertSucceeds(getDoc(entry));
});

test("inquiry creation enforces content, status, and server timestamp", async () => {
  const db = environment.authenticatedContext("owner").firestore();

  await assertFails(
    setDoc(doc(db, "inquiries/empty-subject"), {
      ...inquiry("owner"),
      subject: "",
    }),
  );
  await assertFails(
    setDoc(doc(db, "inquiries/long-subject"), {
      ...inquiry("owner"),
      subject: "x".repeat(161),
    }),
  );
  await assertFails(
    setDoc(doc(db, "inquiries/empty-message"), {
      ...inquiry("owner"),
      message: "",
    }),
  );
  await assertFails(
    setDoc(doc(db, "inquiries/invalid-status"), {
      ...inquiry("owner"),
      status: "resolved",
    }),
  );
  await assertFails(
    setDoc(doc(db, "inquiries/client-timestamp"), {
      ...inquiry("owner"),
      createdAt: Timestamp.fromDate(new Date("2026-07-18T08:00:00Z")),
    }),
  );
});

test("another user cannot create or read an owner's inquiry", async () => {
  const ownerDb = environment.authenticatedContext("owner").firestore();
  const otherDb = environment.authenticatedContext("other").firestore();
  const ownerEntry = doc(ownerDb, "inquiries/inquiry-owner-2");
  const otherView = doc(otherDb, "inquiries/inquiry-owner-2");

  await assertSucceeds(setDoc(ownerEntry, inquiry("owner")));
  await assertFails(getDoc(otherView));
  await assertFails(
    setDoc(doc(otherDb, "inquiries/forged-owner"), inquiry("owner")),
  );
});

test("app users cannot update or delete inquiries", async () => {
  const db = environment.authenticatedContext("owner").firestore();
  const entry = doc(db, "inquiries/inquiry-owner-3");

  await assertSucceeds(setDoc(entry, inquiry("owner")));
  await assertFails(updateDoc(entry, {message: "Changed"}));
  await assertFails(deleteDoc(entry));
});
