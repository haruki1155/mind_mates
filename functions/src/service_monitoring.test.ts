import assert from "node:assert/strict";
import test from "node:test";
import {
  SERVICE_CATALOG,
  SERVICE_HEALTH_THRESHOLDS,
  classifyServiceHealth,
  normalizeServiceErrorCode,
  serviceKeyForActivity,
} from "./service_monitoring";

test("catalog contains eight user-facing services and excludes app opens", () => {
  assert.equal(SERVICE_CATALOG.length, 8);
  assert.equal(serviceKeyForActivity("appOpen"), null);
  assert.equal(serviceKeyForActivity("sleepQuality"), "sleep_quality");
  assert.deepEqual(SERVICE_CATALOG.map((item) => item.serviceKey), [
    "quick_assessment", "full_assessment", "appointments", "mindaid",
    "log_mood", "sleep_quality", "breathing", "secret_chat",
  ]);
});

test("health thresholds are deterministic", () => {
  const now = new Date("2026-07-17T00:00:00Z");
  assert.equal(SERVICE_HEALTH_THRESHOLDS.latencyMs, 3000);
  assert.equal(classifyServiceHealth({hasEvidence: false, lastTelemetryAt: null, successCount: 0, errorCount: 0, averageLatencyMs: 0, now}), "unavailable");
  assert.equal(classifyServiceHealth({hasEvidence: true, lastTelemetryAt: new Date("2026-07-15T00:00:00Z"), successCount: 1, errorCount: 0, averageLatencyMs: 0, now}), "stale");
  assert.equal(classifyServiceHealth({hasEvidence: true, lastTelemetryAt: now, successCount: 95, errorCount: 5, averageLatencyMs: 1, now}), "healthy");
  assert.equal(classifyServiceHealth({hasEvidence: true, lastTelemetryAt: now, successCount: 94, errorCount: 6, averageLatencyMs: 1, now}), "degraded");
  assert.equal(classifyServiceHealth({hasEvidence: true, lastTelemetryAt: now, successCount: 1, errorCount: 0, averageLatencyMs: 3001, now}), "degraded");
});

test("error categories never expose raw messages", () => {
  assert.equal(normalizeServiceErrorCode("permission-denied"), "permission_denied");
  assert.equal(normalizeServiceErrorCode("deadline-exceeded"), "timeout");
  assert.equal(normalizeServiceErrorCode("invalid-argument"), "validation_error");
  assert.equal(normalizeServiceErrorCode("unexpected-secret"), "internal_error");
});
