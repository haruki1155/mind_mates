import test from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {calculateFull, calculateQuick, validateFullAnswers, validateQuickAnswers} from "./calculator";
import {LEGACY_FULL_RESPONSE_SCALE_VERSION, QUESTIONS_BY_ROLE, QUICK_QUESTIONS} from "./catalog";

type ContractGroup = {prefix: string; count: number};
type QuestionContract = {
  version: string;
  roles: Record<"student" | "teaching" | "nonTeaching", ContractGroup[]>;
};

function contractIds(groups: ContractGroup[]): string[] {
  return groups.flatMap((group) =>
    Array.from({length: group.count}, (_, index) => `${group.prefix}${index + 1}`),
  );
}

function questionContract(): QuestionContract {
  const path = resolve(__dirname, "../../../contracts/assessment_question_ids.v2.json");
  return JSON.parse(readFileSync(path, "utf8")) as QuestionContract;
}

test("Functions question catalogs match the shared agreement-scale role contract", () => {
  const contract = questionContract();
  assert.equal(contract.version, "experimental_role_based_v2_agreement");
  for (const role of ["student", "teaching", "nonTeaching"] as const) {
    assert.deepEqual(
      QUESTIONS_BY_ROLE[role].map((question) => question.id),
      contractIds(contract.roles[role]),
    );
  }
});

test("quick calculator requires the complete catalog and ranks concern areas", () => {
  const answers = QUICK_QUESTIONS.map((question) => {
    const option = question.options[question.options.length - 1];
    return {questionId: question.id, optionId: option.id, value: option.value};
  });
  validateQuickAnswers(answers);
  const result = calculateQuick("student", "Test User", answers);
  assert.equal(result.questionSetVersion, "experimental_quick_v1");
  assert.equal((result.responses as unknown[]).length, QUICK_QUESTIONS.length);
  assert.equal((result.topConcernAreas as string[]).length, 3);
});

test("quick validation rejects duplicate, unknown, and mismatched options", () => {
  const first = QUICK_QUESTIONS[0];
  const option = first.options[0];
  const duplicate = QUICK_QUESTIONS.map((question) => ({
    questionId: question.id,
    optionId: question.options[0].id,
    value: question.options[0].value,
  }));
  duplicate[1] = {...duplicate[1], questionId: first.id};
  assert.throws(() => validateQuickAnswers(duplicate), /exactly once/);
  const unknown = QUICK_QUESTIONS.map((question) => ({
    questionId: question.id,
    optionId: question.options[0].id,
    value: question.options[0].value,
  }));
  unknown[0] = {questionId: "unknown", optionId: option.id, value: option.value};
  assert.throws(() => calculateQuick("student", "Test User", unknown), /catalog/);
});

test("full calculator preserves conditional question rules and insufficient domains", () => {
  const baseQuestions = QUESTIONS_BY_ROLE.student.filter((question) => !question.conditional);
  const answers = baseQuestions.map((question) => ({
    questionId: question.id,
    answer: "stronglyDisagree",
    isSkipped: question.section === "financialConcern",
  }));
  validateFullAnswers("student", answers);
  const result = calculateFull("student", answers);
  assert.equal(result.questionSetVersion, "experimental_role_based_v2_agreement");
  assert.equal(result.responseScaleVersion, "agreement5_v2");
  assert.equal(result.overallScore, null);
  const interpretation = result.interpretation as {supportPriority: string; domainResults: Array<{band: string}>};
  assert.equal(interpretation.supportPriority, "insufficientResponses");
  assert.ok(interpretation.domainResults.some((domain) => domain.band === "insufficient"));
});

test("full validation rejects duplicate and unknown question IDs", () => {
  const baseQuestions = QUESTIONS_BY_ROLE.student.filter((question) => !question.conditional);
  const answers = baseQuestions.map((question) => ({questionId: question.id, answer: "neutral", isSkipped: false}));
  answers[1] = {...answers[1], questionId: answers[0].questionId};
  assert.throws(() => validateFullAnswers("student", answers), /Duplicate/);
  answers[1] = {...answers[1], questionId: "unknown"};
  assert.throws(() => validateFullAnswers("student", answers), /Invalid full/);
});

test("full validation accepts agreement values and rejects legacy frequency values", () => {
  const answers = QUESTIONS_BY_ROLE.student
    .filter((question) => !question.conditional)
    .map((question) => ({questionId: question.id, answer: "stronglyDisagree", isSkipped: false}));
  assert.doesNotThrow(() => validateFullAnswers("student", answers));
  answers[0] = {...answers[0], answer: "always"};
  assert.throws(() => validateFullAnswers("student", answers), /Invalid full/);
});

test("legacy frequency responses remain explicitly legacy when recomputed", () => {
  const answers = QUESTIONS_BY_ROLE.student
    .filter((question) => !question.conditional)
    .map((question) => ({questionId: question.id, answer: "never", isSkipped: false}));
  assert.doesNotThrow(() =>
    validateFullAnswers("student", answers, LEGACY_FULL_RESPONSE_SCALE_VERSION),
  );
  const result = calculateFull(
    "student",
    answers,
    LEGACY_FULL_RESPONSE_SCALE_VERSION,
  );
  assert.equal(result.responseScaleVersion, "frequency5_v1");
  assert.equal(result.questionSetVersion, "experimental_role_based_v1");
});
