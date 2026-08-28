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
    projectId: "mind-mates-user-device-token-rules-test",
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

function token(value: string) {
  return {
    token: value,
    updatedAt: Timestamp.fromDate(new Date("2026-07-18T08:00:00Z")),
  };
}

test("an owner can create, read, update, and delete their device token", async () => {
  const db = environment.authenticatedContext("owner").firestore();
  const entry = doc(db, "user_devices/owner/tokens/token-owner-1");

  await assertSucceeds(setDoc(entry, token("token-owner-1")));
  await assertSucceeds(getDoc(entry));
  await assertSucceeds(updateDoc(entry, {token: "token-owner-refreshed"}));
  await assertSucceeds(deleteDoc(entry));
});

test("an owner cannot read or write another user's device tokens", async () => {
  const otherDb = environment.authenticatedContext("other").firestore();
  const ownerDb = environment.authenticatedContext("owner").firestore();
  const otherEntry = doc(otherDb, "user_devices/other/tokens/token-other-1");
  const ownerView = doc(ownerDb, "user_devices/other/tokens/token-other-1");

  await assertSucceeds(setDoc(otherEntry, token("token-other-1")));
  await assertFails(getDoc(ownerView));
  await assertFails(setDoc(ownerView, token("forged")));
  await assertFails(updateDoc(ownerView, {token: "tampered"}));
  await assertFails(deleteDoc(ownerView));
});

test("another user cannot access an owner's device token", async () => {
  const ownerDb = environment.authenticatedContext("owner").firestore();
  const otherDb = environment.authenticatedContext("other").firestore();
  const ownerEntry = doc(ownerDb, "user_devices/owner/tokens/token-owner-2");
  const otherView = doc(otherDb, "user_devices/owner/tokens/token-owner-2");

  await assertSucceeds(setDoc(ownerEntry, token("token-owner-2")));
  await assertFails(getDoc(otherView));
  await assertFails(updateDoc(otherView, {token: "tampered"}));
  await assertFails(deleteDoc(otherView));
});
