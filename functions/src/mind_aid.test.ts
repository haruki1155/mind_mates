import assert from "node:assert/strict";
import test from "node:test";

import {
  classifyMindAidCxSafety,
  classifyMindAidSafety,
  isSafeMindAidOutput,
  parseSupportContacts,
} from "./mind_aid";

test("classifies English and Taglish crisis messages before Dialogflow", () => {
  assert.equal(classifyMindAidSafety("I want to kill myself"), "crisisOrImmediateRisk");
  assert.equal(classifyMindAidSafety("Ayoko nang mabuhay"), "crisisOrImmediateRisk");
  assert.equal(classifyMindAidSafety("Hindi ako safe right now"), "highDistress");
  assert.equal(classifyMindAidSafety("I feel stressed about finals"), "safeSupport");
  assert.equal(classifyMindAidSafety("hi"), "safeSupport");
  assert.equal(classifyMindAidSafety("hello"), "safeSupport");
  assert.equal(classifyMindAidSafety("Magpapakamatay ako"), "crisisOrImmediateRisk");
  assert.equal(classifyMindAidSafety("I am being harassed"), "highDistress");
  assert.equal(classifyMindAidSafety("I can't breathe"), "highDistress");
});

test("treats high-confidence CX safety intents as controlled server safety", () => {
  assert.equal(
    classifyMindAidCxSafety("safety.self_harm_or_suicide_concern", 0.9),
    "crisisOrImmediateRisk",
  );
  assert.equal(
    classifyMindAidCxSafety("safety.abuse_harassment_or_violence", 0.8),
    "highDistress",
  );
  assert.equal(classifyMindAidCxSafety("safety.severe_panic_or_distress", 0.2), null);
  assert.equal(classifyMindAidCxSafety("support.academic_stress", 0.99), null);
});

test("rejects diagnostic and prescription-like generated output", () => {
  assert.equal(isSafeMindAidOutput("You have depression and should isolate."), false);
  assert.equal(isSafeMindAidOutput("Stop taking your medicine today."), false);
  assert.equal(isSafeMindAidOutput("That sounds difficult. A short pause could help."), true);
});

test("support contacts require complete verification metadata", () => {
  assert.deepEqual(parseSupportContacts([{value: "placeholder", enabled: true}]), []);
  const contacts = parseSupportContacts([{
    value: "verified-value", type: "counseling", displayName: "Approved service",
    availability: "Approved hours", verificationStatus: "verified",
    verifiedAt: "2026-07-01T00:00:00Z", approvingAuthority: "Authorized office", enabled: true,
  }]);
  assert.equal(contacts.length, 1);
  assert.equal(contacts[0].displayName, "Approved service");
});
