import {HttpsError} from "firebase-functions/v2/https";

import {
  FULL_QUESTION_SET_VERSION,
  FULL_RESPONSE_SCALE_VERSION,
} from "./catalog";

const AGREEMENT_ANSWERS = new Set([
  "stronglyDisagree",
  "disagree",
  "neutral",
  "agree",
  "stronglyAgree",
]);

export type FullContractSource = "explicit" | "inferredAgreementCompatibility";

export interface FullSubmissionContract {
  responseScaleVersion: typeof FULL_RESPONSE_SCALE_VERSION;
  questionSetVersion: typeof FULL_QUESTION_SET_VERSION;
  source: FullContractSource;
}

interface SemanticAnswer {
  answer: string;
}

function mismatch(
  responseScaleVersion: unknown,
  questionSetVersion: unknown,
): never {
  throw new HttpsError(
    "failed-precondition",
    "This assessment uses an unsupported response contract. Update MindMates and try again.",
    {
      reason: "assessment_contract_mismatch",
      expectedResponseScaleVersion: FULL_RESPONSE_SCALE_VERSION,
      receivedResponseScaleVersion: responseScaleVersion ?? null,
      expectedQuestionSetVersion: FULL_QUESTION_SET_VERSION,
      receivedQuestionSetVersion: questionSetVersion ?? null,
    },
  );
}

/**
 * Resolves the contract for a new full-assessment submission.
 *
 * The inference branch is a temporary, zero-downtime bridge for the currently
 * released client, which already sends unambiguous agreement enum names but
 * predates the explicit version fields. Frequency names and partial/unknown
 * version declarations are rejected, so historical meanings are never guessed.
 */
export function resolveFullSubmissionContract(
  responseScaleVersion: unknown,
  questionSetVersion: unknown,
  answers: SemanticAnswer[],
): FullSubmissionContract {
  if (
    responseScaleVersion === FULL_RESPONSE_SCALE_VERSION &&
    questionSetVersion === FULL_QUESTION_SET_VERSION
  ) {
    return {
      responseScaleVersion: FULL_RESPONSE_SCALE_VERSION,
      questionSetVersion: FULL_QUESTION_SET_VERSION,
      source: "explicit",
    };
  }

  if (
    responseScaleVersion === undefined &&
    questionSetVersion === undefined &&
    answers.length > 0 &&
    answers.every((answer) => AGREEMENT_ANSWERS.has(answer.answer))
  ) {
    return {
      responseScaleVersion: FULL_RESPONSE_SCALE_VERSION,
      questionSetVersion: FULL_QUESTION_SET_VERSION,
      source: "inferredAgreementCompatibility",
    };
  }

  return mismatch(responseScaleVersion, questionSetVersion);
}
