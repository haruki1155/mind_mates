import test from "node:test";
import assert from "node:assert/strict";
import {quickProfileRoleDecision, submissionHashesMatch} from "./submission_policy";

test("quick assessment backfills only a missing profile role", () => {
  assert.equal(quickProfileRoleDecision({}, "student"), "backfill");
  assert.equal(
    quickProfileRoleDecision({populationRole: "teaching"}, "teaching"),
    "match",
  );
  assert.equal(
    quickProfileRoleDecision({declaredRole: "student"}, "nonTeaching"),
    "mismatch",
  );
});

test("concurrent quick submissions must retain the same hash", () => {
  assert.equal(submissionHashesMatch("same", "same"), true);
  assert.equal(submissionHashesMatch("first", "second"), false);
  assert.equal(submissionHashesMatch(undefined, "second"), false);
});
