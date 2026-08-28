import assert from "node:assert/strict";
import {after, before, beforeEach, test} from "node:test";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";

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

const projectId = "mind-mates-sleep-rules-test";
let environment: RulesTestEnvironment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

function validEntry(userId = "owner", wakeDateKey = "20260714") {
  return {
    userId,
    wakeDateKey,
    timezone: "Asia/Manila",
    attemptedSleepAt: Timestamp.fromDate(new Date("2026-07-13T15:00:00Z")),
    sleepOnsetAt: Timestamp.fromDate(new Date("2026-07-13T15:30:00Z")),
    finalWakeAt: Timestamp.fromDate(new Date("2026-07-13T23:00:00Z")),
    outOfBedAt: Timestamp.fromDate(new Date("2026-07-13T23:15:00Z")),
    awakeningCount: 1,
    awakeMinutes: 15,
    napCount: 0,
    napMinutes: 0,
    restfulness: 4,
    daytimeSleepiness: 2,
    perceivedQuality: 4,
    contributorTags: ["stress"],
    concernTags: [],
    createdAt: Timestamp.fromDate(new Date("2026-07-14T00:00:00Z")),
    clientUpdatedAt: Timestamp.fromDate(new Date("2026-07-14T00:00:00Z")),
    updatedAt: serverTimestamp(),
  };
}

test("owners can read their diary but direct client mutations are denied", async () => {
  const db = environment.authenticatedContext("owner").firestore();
  const ref = doc(db, "sleep_entries/sleep_owner_20260714");
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "sleep_entries/sleep_owner_20260714"), {
      ...validEntry(), updatedAt: Timestamp.now(), revision: 1,
    });
  });
  await assertSucceeds(
    getDocs(query(collection(db, "sleep_entries"), where("userId", "==", "owner"))),
  );
  await assertFails(setDoc(ref, validEntry()));
  await assertFails(updateDoc(ref, {perceivedQuality: 5, updatedAt: serverTimestamp()}));
  await assertFails(deleteDoc(ref));
});

test("other users and administrators cannot read an owner's sleep entry", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "sleep_entries/sleep_owner_20260714"), {
      ...validEntry(),
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(context.firestore(), "users/admin"), {role: "admin"});
  });
  await assertFails(
    getDoc(doc(environment.authenticatedContext("other").firestore(), "sleep_entries/sleep_owner_20260714")),
  );
  await assertFails(
    getDoc(doc(environment.authenticatedContext("admin").firestore(), "sleep_entries/sleep_owner_20260714")),
  );
});

test("client writes are denied regardless of submitted sleep-entry shape", async () => {
  const db = environment.authenticatedContext("owner").firestore();
  await assertFails(setDoc(doc(db, "sleep_entries/wrong"), validEntry()));
  await assertFails(
    setDoc(doc(db, "sleep_entries/sleep_owner_20260714"), {
      ...validEntry(),
      contributorTags: ["unsupported"],
    }),
  );
  await assertFails(
    setDoc(doc(db, "sleep_entries/sleep_owner_20260714"), {
      ...validEntry(),
      perceivedQuality: 6,
    }),
  );
  await assertFails(
    setDoc(doc(db, "sleep_entries/sleep_owner_20260714"), {
      ...validEntry(),
      sleepOnsetAt: Timestamp.fromDate(new Date("2026-07-14T01:00:00Z")),
    }),
  );
  await assertFails(setDoc(doc(db, "sleep_entries/sleep_owner_20260714"), validEntry()));
});

test("owners can read cloud consent but direct writes are callable-owned", async () => {
  const ownerDb = environment.authenticatedContext("owner").firestore();
  const preference = doc(ownerDb, "sleep_preferences/owner");
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "sleep_preferences/owner"), {
      userId: "owner", consentVersion: "sleep-v1", cloudConsent: true,
      grantedAt: Timestamp.now(), updatedAt: Timestamp.now(),
    });
  });
  await assertFails(setDoc(preference, {
    userId: "owner", consentVersion: "sleep-v1", cloudConsent: true,
    grantedAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  await assertFails(
    getDoc(doc(environment.authenticatedContext("other").firestore(), "sleep_preferences/owner")),
  );
  assert.equal((await getDoc(preference)).data()?.cloudConsent, true);
});
