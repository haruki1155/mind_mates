import {getApps, initializeApp} from "firebase-admin/app";
import assert from "node:assert/strict";
import test from "node:test";

if (!getApps().length) initializeApp({projectId: "mind-mates-account-integrity-test"});

test("profile provisioning validates each population role", async () => {
  const {validatedProfileInput} = await import("./account_integrity");
  const base = {firstName: "Mind", lastName: "Mate"};
  assert.equal(validatedProfileInput({...base, populationRole: "student", department: "CITE", course: "BSIT", yearLevel: "2"}).populationRole, "student");
  assert.equal(validatedProfileInput({...base, populationRole: "teaching", employeeId: "E-1", department: "CITE", position: "Instructor"}).populationRole, "teaching");
  assert.equal(validatedProfileInput({...base, populationRole: "nonTeaching", employeeId: "E-2", sector: "Registrar", position: "Officer"}).populationRole, "nonTeaching");
});

test("profile provisioning rejects incomplete student input", async () => {
  const {validatedProfileInput} = await import("./account_integrity");
  assert.throws(() => validatedProfileInput({firstName: "Mind", lastName: "Mate", populationRole: "student"}), /Students must provide/);
});

test("app-user profiles omit institutional-role verification fields", async () => {
  const {appUserProfileDocument, validatedProfileInput} = await import("./account_integrity");
  const input = validatedProfileInput({
    firstName: "Mind",
    lastName: "Mate",
    populationRole: "student",
    department: "CITE",
    course: "BSIT",
    yearLevel: "2",
  });
  const profile = appUserProfileDocument("uid", "user@mindmate.local", "user", input);
  assert.equal(profile.populationRole, "student");
  assert.equal(profile.declaredRole, "student");
  assert.equal(profile.accessRole, "appUser");
  assert.equal("verificationStatus" in profile, false);
  assert.equal("verifiedAt" in profile, false);
  assert.equal("verifiedBy" in profile, false);
});

test("profile retries repair only missing initialization fields", async () => {
  const {profileRepairUpdates} = await import("./account_integrity");
  const updates = profileRepairUpdates(
    {
      firstName: "Existing",
      role: "student",
      populationRole: "student",
      accessRole: "appUser",
      accountStatus: "active",
      quickAssessmentCompleted: true,
      createdAt: "server-created",
    },
    {
      firstName: "Attacker",
      lastName: "Mate",
      populationRole: "student",
      role: "admin",
      accessRole: "admin",
      accountStatus: "disabled",
      quickAssessmentCompleted: "false",
      createdAt: "client-created",
      department: "CITE",
    },
  );
  assert.deepEqual(updates, {lastName: "Mate", department: "CITE"});
  assert.equal("role" in updates, false);
  assert.equal("accessRole" in updates, false);
  assert.equal("accountStatus" in updates, false);
  assert.equal("quickAssessmentCompleted" in updates, false);
  assert.equal("createdAt" in updates, false);
});

test("recovery normalizes School IDs without exposing account state", async () => {
  const {authEmailForSchoolId} = await import("./account_recovery");
  assert.equal(authEmailForSchoolId(" 2024 / 001 "), "2024.001@mindmate.local");
  assert.throws(() => authEmailForSchoolId("***"), /valid School ID/);
});
