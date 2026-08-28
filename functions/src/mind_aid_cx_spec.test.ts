import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import test from "node:test";

import {
  mindAidCxFlows,
  mindAidCxIntents,
  mindAidCxDialogueCases,
  mindAidCxRedTeamCases,
  mindAidCxWelcome,
} from "./mind_aid_cx_spec";

const allowedActions = new Set([
  "logMood",
  "startBreathing",
  "openAssessment",
  "openInsights",
  "openCounselingServices",
  "bookAppointment",
  "viewAppointments",
]);

test("CX specification has unique names and training phrases", () => {
  assert.equal(new Set(mindAidCxFlows.map((flow) => flow.displayName)).size, mindAidCxFlows.length);
  assert.equal(new Set(mindAidCxIntents.map((intent) => intent.displayName)).size, mindAidCxIntents.length);

  const phrases = new Map<string, string>();
  for (const intent of mindAidCxIntents) {
    assert.ok(intent.trainingPhrases.length >= 5, `${intent.displayName} needs at least five training phrases`);
    for (const phrase of intent.trainingPhrases) {
      const normalized = phrase.trim().toLowerCase();
      assert.ok(normalized.length > 1, `${intent.displayName} contains an empty phrase`);
      assert.equal(phrases.get(normalized), undefined, `${phrase} is duplicated across intents`);
      phrases.set(normalized, intent.displayName);
    }
  }
  for (const phrase of mindAidCxWelcome.trainingPhrases) {
    assert.equal(phrases.get(phrase.toLowerCase()), undefined, `${phrase} overlaps a custom intent`);
  }
});

test("CX specification only emits client-allowlisted actions", () => {
  for (const intent of mindAidCxIntents) {
    for (const action of intent.actions ?? []) {
      assert.ok(allowedActions.has(action.type), `${intent.displayName} uses unsupported action ${action.type}`);
    }
  }
});

test("dataset-backed CX intents resolve to approved response records", () => {
  const datasetIntents = new Set<string>();
  for (const filename of ["intents.json", "crisis_triggers.json"]) {
    const path = resolve(__dirname, "../../assets/data/mind_aid", filename);
    const parsed = JSON.parse(readFileSync(path, "utf8").replace(/^\uFEFF/, "")) as {
      records?: Array<{intent?: string; responses?: string[]}>;
    };
    for (const record of parsed.records ?? []) {
      if (record.intent && record.responses?.[0]?.trim()) datasetIntents.add(record.intent);
    }
  }
  for (const intent of mindAidCxIntents) {
    if (intent.response) continue;
    assert.ok(intent.datasetIntent, `${intent.displayName} has no response source`);
    assert.ok(datasetIntents.has(intent.datasetIntent), `${intent.displayName} has no approved dataset record`);
  }
});

test("red-team expectations reference configured intents", () => {
  const names = new Set([
    "NO_MATCH",
    "Default Welcome Intent",
    ...mindAidCxIntents.map((intent) => intent.displayName),
  ]);
  for (const testCase of mindAidCxRedTeamCases) {
    assert.ok(names.has(testCase.expectedIntent), `${testCase.expectedIntent} is not configured`);
  }
  for (const dialogue of mindAidCxDialogueCases) {
    assert.ok(dialogue.turns.length > 1, `${dialogue.name} does not exercise a dialogue`);
    for (const turn of dialogue.turns) {
      assert.ok(names.has(turn.expectedIntent), `${turn.expectedIntent} is not configured`);
    }
  }
});
