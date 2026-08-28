import assert from "node:assert/strict";
import test from "node:test";
import {validRotationTransition, validateTemporaryPassword} from "./rotate_super_admin";

test("one-time passwords must meet the guarded rotation policy", () => {
  assert.equal(validateTemporaryPassword("Short1!"), false);
  assert.equal(validateTemporaryPassword("long but missing 1!"), false);
  assert.equal(validateTemporaryPassword("StrongTemporary1!"), true);
  assert.equal(validateTemporaryPassword("Strong Temporary1!"), false);
});

test("rotation transitions refuse destructive out-of-order operations", () => {
  assert.equal(validRotationTransition("none", "prepare"), true);
  assert.equal(validRotationTransition("prepared", "prepare"), false);
  assert.equal(validRotationTransition("prepared", "cutover"), true);
  assert.equal(validRotationTransition("cutover", "finalize"), true);
  assert.equal(validRotationTransition("finalized", "rollback"), false);
  assert.equal(validRotationTransition("finalizing", "rollback"), false);
});
