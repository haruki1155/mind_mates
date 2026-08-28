import assert from "node:assert/strict";
import {test} from "node:test";
import {obsoleteRoleVerificationFields} from "./backfill_profiles";

test("app-user role verification fields are removed", () => {
  assert.deepEqual(
    obsoleteRoleVerificationFields({
      accessRole: "appUser",
      verificationStatus: "pending",
      verifiedAt: null,
      verifiedBy: "",
      populationRole: "student",
    }),
    ["verificationStatus", "verifiedAt", "verifiedBy"],
  );
});

test("staff approval metadata is preserved while generic status is removed", () => {
  assert.deepEqual(
    obsoleteRoleVerificationFields({
      accessRole: "counselor",
      staffAccountStatus: "approved",
      verificationStatus: "verified",
      verifiedAt: "server timestamp",
      verifiedBy: "administrator",
    }),
    ["verificationStatus"],
  );
});

test("already-migrated profiles produce no changes", () => {
  assert.deepEqual(
    obsoleteRoleVerificationFields({
      accessRole: "appUser",
      populationRole: "nonTeaching",
      declaredRole: "nonTeaching",
    }),
    [],
  );
});
