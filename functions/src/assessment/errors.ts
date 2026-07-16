import {HttpsError} from "firebase-functions/v2/https";

import {AssessmentValidationError} from "./calculator";

export function toHttpsError(error: unknown): never {
  if (error instanceof HttpsError) throw error;
  if (error instanceof AssessmentValidationError) {
    throw new HttpsError("invalid-argument", error.message);
  }
  console.error("assessment_internal_error", error);
  throw new HttpsError("internal", "The assessment could not be saved.");
}
