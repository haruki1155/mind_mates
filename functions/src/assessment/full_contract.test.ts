import assert from "node:assert/strict";
import test from "node:test";
import {HttpsError} from "firebase-functions/v2/https";

import {
  FULL_QUESTION_SET_VERSION,
  FULL_RESPONSE_SCALE_VERSION,
} from "./catalog";
import {resolveFullSubmissionContract} from "./full_contract";

const agreementAnswers = [
  {answer: "stronglyDisagree"},
  {answer: "disagree"},
  {answer: "neutral"},
  {answer: "agree"},
  {answer: "stronglyAgree"},
];

test("accepts the explicit agreement response contract", () => {
  const contract = resolveFullSubmissionContract(
    FULL_RESPONSE_SCALE_VERSION,
    FULL_QUESTION_SET_VERSION,
    agreementAnswers,
  );

  assert.equal(contract.source, "explicit");
  assert.equal(contract.responseScaleVersion, FULL_RESPONSE_SCALE_VERSION);
  assert.equal(contract.questionSetVersion, FULL_QUESTION_SET_VERSION);
});

test("temporarily infers only unambiguous versionless agreement requests", () => {
  const contract = resolveFullSubmissionContract(
    undefined,
    undefined,
    agreementAnswers,
  );

  assert.equal(contract.source, "inferredAgreementCompatibility");
});

test("rejects versionless legacy frequency names instead of reinterpreting them", () => {
  assert.throws(
    () => resolveFullSubmissionContract(undefined, undefined, [{answer: "often"}]),
    (error: unknown) => error instanceof HttpsError &&
      error.code === "failed-precondition" &&
      (error.details as {reason?: string})?.reason === "assessment_contract_mismatch",
  );
});

test("rejects partial and unknown version declarations", () => {
  for (const versions of [
    [FULL_RESPONSE_SCALE_VERSION, undefined],
    [undefined, FULL_QUESTION_SET_VERSION],
    ["frequency5_v1", "experimental_role_based_v1"],
  ]) {
    assert.throws(
      () => resolveFullSubmissionContract(versions[0], versions[1], agreementAnswers),
      (error: unknown) => error instanceof HttpsError &&
        error.code === "failed-precondition",
    );
  }
});
