import assert from "node:assert/strict";
import test from "node:test";
import {activeCommentDelta, reactionDelta} from "./index";

test("reaction deltas cover like, unlike, and unrelated writes", () => {
  assert.equal(reactionDelta(false, true), 1);
  assert.equal(reactionDelta(true, false), -1);
  assert.equal(reactionDelta(true, true), 0);
});

test("comment deltas count active lifecycle transitions", () => {
  assert.equal(activeCommentDelta(undefined, "active"), 1);
  assert.equal(activeCommentDelta("active", undefined), -1);
  assert.equal(activeCommentDelta("active", "active"), 0);
});
