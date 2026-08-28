import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {after, before, beforeEach, test} from "node:test";
import {assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment} from "@firebase/rules-unit-testing";
import {deleteDoc, doc, getDoc, setDoc, Timestamp, updateDoc} from "firebase/firestore";

let environment: RulesTestEnvironment;
before(async () => {
  environment = await initializeTestEnvironment({
    projectId: "mind-mates-assessment-rules-test",
    firestore: {rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8")},
  });
});
beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

async function seed(): Promise<void> {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/owner"), {role: "student", accessRole: "appUser"});
    await setDoc(doc(context.firestore(), "users/counselor"), {
      role: "student", accessRole: "counselor", staffAccountStatus: "approved",
    });
    await setDoc(doc(context.firestore(), "assessments/assessment-1"), {
      userId: "owner", type: "quick", concernScore: 20, createdAt: Timestamp.now(), verificationStatus: "verified",
    });
  });
}

test("assessment result documents are immutable to clients", async () => {
  await seed();
  const db = environment.authenticatedContext("owner").firestore();
  const ref = doc(db, "assessments/new-assessment");
  await assertFails(setDoc(ref, {userId: "owner", type: "quick"}));
  const existing = doc(db, "assessments/assessment-1");
  await assertFails(updateDoc(existing, {concernScore: 99}));
  await assertFails(deleteDoc(existing));
});

test("owners and authorized clinical staff retain intended reads", async () => {
  await seed();
  await assertSucceeds(getDoc(doc(environment.authenticatedContext("owner").firestore(), "assessments/assessment-1")));
  await assertSucceeds(getDoc(doc(environment.authenticatedContext("counselor").firestore(), "assessments/assessment-1")));
});
