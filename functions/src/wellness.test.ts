import assert from "node:assert/strict";
import test from "node:test";
import {Timestamp} from "firebase-admin/firestore";
import {appendActiveDateKey, manilaDateKey, nextWellnessStreak} from "./wellness";

test("Manila date keys are compact and independent of the host timezone", () => {
  assert.equal(manilaDateKey(Timestamp.fromDate(new Date("2026-08-15T16:01:00.000Z"))), "20260816");
});

test("wellness streak advances once per day and resets after a gap", () => {
  const first = nextWellnessStreak({}, "20260815");
  assert.deepEqual(first, {
    dayStreak: 1,
    longestStreak: 1,
    lastQualifyingActivityDateKey: "20260815",
    activeDateKeys: ["20260815"],
  });
  const sameDay = nextWellnessStreak({...first}, "20260815");
  assert.equal(sameDay.dayStreak, 1);
  const nextDay = nextWellnessStreak({...sameDay}, "20260816");
  assert.equal(nextDay.dayStreak, 2);
  const gap = nextWellnessStreak({...nextDay}, "20260818");
  assert.equal(gap.dayStreak, 1);
  assert.equal(gap.longestStreak, 2);
});

test("active wellness dates are deduplicated, ordered, and bounded", () => {
  const many = Array.from({length: 70}, (_, index) => `202601${String(index + 1).padStart(2, "0")}`);
  const dates = appendActiveDateKey([...many, "20260110"], "20261231");
  assert.equal(dates.length, 60);
  assert.equal(new Set(dates).size, 60);
  assert.deepEqual(dates, [...dates].sort());
  assert.equal(dates.at(-1), "20261231");
});
