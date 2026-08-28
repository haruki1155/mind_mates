import assert from "node:assert/strict";
import test from "node:test";
import {HttpsError} from "firebase-functions/v2/https";

import {AssessmentValidationError} from "./calculator";
import {toHttpsError} from "./errors";

test("assessment contract failures are returned as invalid arguments", () => {
  assert.throws(
    () => toHttpsError(new AssessmentValidationError("Invalid full-assessment answer.")),
    (error: unknown) => error instanceof HttpsError &&
      error.code === "invalid-argument" &&
      error.message === "Invalid full-assessment answer.",
  );
});
