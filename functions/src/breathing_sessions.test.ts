import {getApps, initializeApp} from "firebase-admin/app";
import assert from "node:assert/strict";
import test from "node:test";

if (!getApps().length) initializeApp({projectId: "mind-mates-breathing-sessions-test"});

test("breathing techniques only accept curated or bounded mood sessions", async () => {
  const {breathingTechnique} = await import("./breathing_sessions");
  assert.deepEqual(breathingTechnique("box_breathing"), {
    id: "box_breathing", title: "Box Breathing", durationSeconds: 180,
  });
  assert.equal(breathingTechnique("mood_anxiety_5m").durationSeconds, 300);
  assert.throws(() => breathingTechnique("mood_anxiety_99m"), /valid breathing technique/);
  assert.throws(() => breathingTechnique("invented"), /valid breathing technique/);
});
