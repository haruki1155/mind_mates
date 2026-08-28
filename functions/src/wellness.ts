import {FieldValue, Timestamp, Transaction} from "firebase-admin/firestore";

export const MANILA_TIMEZONE = "Asia/Manila";
export const QUALIFYING_WELLNESS_TYPES = new Set([
  "moodCheckIn",
  "breathingSession",
  "sleepQuality",
  "fullAssessment",
  "quickAssessment",
]);

export function manilaDateKey(timestamp: Timestamp): string {
  return new Date(timestamp.toMillis() + 8 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10)
    .replaceAll("-", "");
}

export function previousManilaDateKey(dateKey: string): string {
  const year = Number(dateKey.slice(0, 4));
  const month = Number(dateKey.slice(4, 6));
  const day = Number(dateKey.slice(6, 8));
  return new Date(Date.UTC(year, month - 1, day - 1)).toISOString().slice(0, 10).replaceAll("-", "");
}

export function appendActiveDateKey(existing: unknown, today: string): string[] {
  const keys = Array.isArray(existing) ? existing : [];
  return Array.from(new Set([...keys, today]
    .filter((value): value is string => typeof value === "string" && /^\d{8}$/.test(value))))
    .sort()
    .slice(-60);
}

export interface WellnessStreak {
  dayStreak: number;
  longestStreak: number;
  lastQualifyingActivityDateKey: string;
  activeDateKeys: string[];
}

export function nextWellnessStreak(profile: Record<string, unknown>, dateKey: string): WellnessStreak {
  const previous = typeof profile.lastQualifyingActivityDateKey === "string" ?
    profile.lastQualifyingActivityDateKey : "";
  const current = Number(profile.dayStreak ?? 0) || 0;
  const longest = Number(profile.longestStreak ?? 0) || 0;
  const dayStreak = previous === dateKey ? current :
    previous === previousManilaDateKey(dateKey) && current > 0 ? current + 1 : 1;
  return {
    dayStreak,
    longestStreak: Math.max(longest, dayStreak),
    lastQualifyingActivityDateKey: dateKey,
    activeDateKeys: appendActiveDateKey(profile.activeDateKeys, dateKey),
  };
}

export function writeQualifyingWellnessState(
  transaction: Transaction,
  userRef: FirebaseFirestore.DocumentReference,
  profile: Record<string, unknown>,
  occurredAt: Timestamp,
  dateKey: string,
): WellnessStreak {
  const streak = nextWellnessStreak(profile, dateKey);
  transaction.update(userRef, {
    dayStreak: streak.dayStreak,
    longestStreak: streak.longestStreak,
    lastQualifyingActivityDateKey: streak.lastQualifyingActivityDateKey,
    lastQualifyingActivityAt: occurredAt,
    activeDateKeys: streak.activeDateKeys,
    streakUpdatedAt: FieldValue.serverTimestamp(),
  });
  return streak;
}
