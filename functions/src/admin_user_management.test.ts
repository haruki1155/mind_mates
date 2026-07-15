import assert from "node:assert/strict";
import test from "node:test";
import {newPublicUserId} from "./index";

test("public app user IDs use the privacy-safe format", () => {
  const values = Array.from({length: 200}, () => newPublicUserId());
  assert.ok(values.every((value) => /^USR-[A-HJ-NP-Z2-9]{6}$/.test(value)));
  assert.equal(new Set(values).size, values.length);
});
