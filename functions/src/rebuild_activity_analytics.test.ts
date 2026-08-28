import assert from "node:assert/strict";
import test from "node:test";
import {Timestamp} from "firebase-admin/firestore";
import {
  analyticsValuesEqual,
  buildDailyAggregates,
} from "./rebuild_activity_analytics";

test("analytics aggregation excludes portal activity and malformed timestamps", () => {
  const at = Timestamp.fromDate(new Date("2026-07-17T01:00:00Z"));
  const result = buildDailyAggregates([
    {id: "a", userId: "app", type: "mood", createdAt: at},
    {id: "b", userId: "staff", type: "admin", createdAt: at},
    {id: "c", userId: "app", type: "sleepQuality", createdAt: "invalid"},
  ], new Set(["app"]));

  assert.equal(result.appUserActivityCount, 1);
  assert.equal(result.excludedPortalActivityCount, 1);
  assert.equal(result.invalidActivityCount, 1);
  assert.equal([...result.aggregates.values()][0].eventCount, 1);
});

test("same-time activity ordering uses document ID deterministically", () => {
  const at = Timestamp.fromDate(new Date("2026-07-17T02:00:00Z"));
  const result = buildDailyAggregates([
    {id: "z-last", userId: "app", type: "sleepQuality", createdAt: at},
    {id: "a-first", userId: "app", type: "mood", createdAt: at},
  ], new Set(["app"]));
  const dailyUser = [...result.aggregates.values()][0].users.get("app");
  assert.equal(dailyUser?.lastActivityType, "sleepQuality");
});

test("analytics diff ignores only the generated update timestamp", () => {
  const now = Timestamp.now();
  assert.equal(analyticsValuesEqual(
    {eventCount: 2, updatedAt: now},
    {eventCount: 2},
  ), true);
  assert.equal(analyticsValuesEqual(
    {eventCount: 1, updatedAt: now},
    {eventCount: 2},
  ), false);
});
