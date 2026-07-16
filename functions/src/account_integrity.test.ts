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

test("recovery normalizes School IDs without exposing account state", async () => {
  const {authEmailForSchoolId} = await import("./account_recovery");
  assert.equal(authEmailForSchoolId(" 2024 / 001 "), "2024.001@mindmate.local");
  assert.throws(() => authEmailForSchoolId("***"), /valid School ID/);
});
