import {HttpsError} from "firebase-functions/v2/https";

import {AssessmentValidationError} from "./calculator";

export function toHttpsError(error: unknown, correlationId?: string): never {
  if (error instanceof HttpsError) {
    if (!correlationId) throw error;
    const existingDetails = error.details;
    const details = existingDetails && typeof existingDetails === "object" && !Array.isArray(existingDetails) ?
      {...existingDetails as Record<string, unknown>, correlationId} :
      {correlationId};
    throw new HttpsError(error.code, error.message, details);
  }
  if (error instanceof AssessmentValidationError) {
    throw new HttpsError("invalid-argument", error.message, correlationId ? {correlationId} : undefined);
  }
  console.error("assessment_internal_error", {correlationId, error});
  throw new HttpsError("internal", "The assessment could not be saved.", correlationId ? {correlationId} : undefined);
}
