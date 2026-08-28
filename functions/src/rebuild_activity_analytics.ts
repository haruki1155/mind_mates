import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {resolveProjectId} from "./backfill_profiles";

if (!getApps().length) initializeApp({projectId: resolveProjectId()});

export type DailyAggregate = {
  eventCount: number;
  users: Map<string, {lastActivityType: string; lastActiveAt: Timestamp}>;
  activityCounts: Record<string, number>;
};

function comparable(value: unknown): unknown {
  if (value instanceof Timestamp) return value.toMillis();
  if (Array.isArray(value)) return value.map(comparable);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value as Record<string, unknown>)
      .filter(([key]) => key !== "updatedAt")
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, item]) => [key, comparable(item)]));
  }
  return value;
}

export function analyticsValuesEqual(left: unknown, right: unknown): boolean {
  return JSON.stringify(comparable(left)) === JSON.stringify(comparable(right));
}

function dateKey(value: Date): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Manila", year: "numeric", month: "2-digit", day: "2-digit",
  }).format(value);
}

function activityType(value: unknown): string {
  return String(value ?? "unknown").replace(/[^A-Za-z0-9_]/g, "_");
}

export type RawActivityRecord = {
  id: string;
  userId: unknown;
  type: unknown;
  createdAt: unknown;
};

export function buildDailyAggregates(
  records: RawActivityRecord[],
  appUserIds: ReadonlySet<string>,
): {
  aggregates: Map<string, DailyAggregate>;
  appUserActivityCount: number;
  excludedPortalActivityCount: number;
  invalidActivityCount: number;
} {
  const aggregates = new Map<string, DailyAggregate>();
  let excludedPortalActivityCount = 0;
  let appUserActivityCount = 0;
  let invalidActivityCount = 0;
  const ordered = records
    .filter((record) => {
      if (record.createdAt instanceof Timestamp) return true;
      invalidActivityCount++;
      return false;
    })
    .sort((a, b) =>
      (a.createdAt as Timestamp).toMillis() - (b.createdAt as Timestamp).toMillis() ||
      a.id.localeCompare(b.id));
  for (const record of ordered) {
    const userId = String(record.userId ?? "");
    if (!appUserIds.has(userId)) {
      excludedPortalActivityCount++;
      continue;
    }
    appUserActivityCount++;
    const occurred = record.createdAt as Timestamp;
    const key = dateKey(occurred.toDate());
    const aggregate: DailyAggregate = aggregates.get(key) ?? {
      eventCount: 0, users: new Map(), activityCounts: {},
    };
    const type = activityType(record.type);
    aggregate.eventCount++;
    aggregate.activityCounts[type] = (aggregate.activityCounts[type] ?? 0) + 1;
    aggregate.users.set(userId, {lastActivityType: type, lastActiveAt: occurred});
    aggregates.set(key, aggregate);
  }
  return {
    aggregates, appUserActivityCount, excludedPortalActivityCount,
    invalidActivityCount,
  };
}

export async function rebuildActivityAnalytics(dryRun = true): Promise<Record<string, number | boolean>> {
  const db = getFirestore();
  const [profiles, activities, existingDays] = await Promise.all([
    db.collection("users").get(), db.collection("user_activities").get(),
    db.collection("analytics_daily").get(),
  ]);
  const appUserIds = new Set(profiles.docs.filter((document) => {
    const data = document.data();
    return data.accessRole === "appUser" && data.staffAccountStatus == null;
  }).map((document) => document.id));
  const computed = buildDailyAggregates(activities.docs.map((document) => ({
    id: document.id,
    userId: document.data().userId,
    type: document.data().type,
    createdAt: document.data().createdAt,
  })), appUserIds);
  const {aggregates, appUserActivityCount, excludedPortalActivityCount,
    invalidActivityCount} = computed;
  let createCount = 0;
  let updateCount = 0;
  let deleteCount = 0;
  let unchangedCount = 0;
  const writer = dryRun ? null : db.bulkWriter();
  const existingByKey = new Map(existingDays.docs.map((document) => [document.id, document]));
  for (const day of existingDays.docs) {
    if (aggregates.has(day.id)) continue;
    const users = await day.ref.collection("users").get();
    deleteCount += users.size + 1;
    if (writer) {
      for (const user of users.docs) writer.delete(user.ref);
      writer.delete(day.ref);
    }
  }
  for (const [key, aggregate] of aggregates) {
      const day = db.collection("analytics_daily").doc(key);
      const desiredDay = {
        dateKey: key, eventCount: aggregate.eventCount,
        activeUserCount: aggregate.users.size, activityCounts: aggregate.activityCounts,
      };
      const existingDay = existingByKey.get(key);
      if (!existingDay) {
        createCount++;
        writer?.set(day, {...desiredDay, updatedAt: Timestamp.now()});
      } else if (!analyticsValuesEqual(existingDay.data(), desiredDay)) {
        updateCount++;
        writer?.set(day, {...desiredDay, updatedAt: Timestamp.now()});
      } else {
        unchangedCount++;
      }
      const existingUsers = await day.collection("users").get();
      const existingUserMap = new Map(existingUsers.docs.map((document) => [document.id, document]));
      for (const [userId, user] of aggregate.users) {
        const desiredUser = {userId, ...user};
        const existingUser = existingUserMap.get(userId);
        if (!existingUser) {
          createCount++;
          writer?.set(day.collection("users").doc(userId), {...desiredUser, updatedAt: Timestamp.now()});
        } else if (!analyticsValuesEqual(existingUser.data(), desiredUser)) {
          updateCount++;
          writer?.set(day.collection("users").doc(userId), {...desiredUser, updatedAt: Timestamp.now()});
        } else {
          unchangedCount++;
        }
        existingUserMap.delete(userId);
      }
      for (const stale of existingUserMap.values()) {
        deleteCount++;
        writer?.delete(stale.ref);
      }
    }
  if (writer) await writer.close();
  return {
    dryRun, rawActivityCount: activities.size, appUserActivityCount,
    excludedPortalActivityCount, appUserProfileCount: appUserIds.size,
    invalidActivityCount, dailyAggregateCount: aggregates.size,
    existingDailyAggregateCount: existingDays.size,
    createCount, updateCount, deleteCount, unchangedCount,
  };
}

if (require.main === module) {
  const dryRun = !process.argv.includes("--apply");
  rebuildActivityAnalytics(dryRun).then((summary) => {
    // Counts only: no user identifiers, activity text, or credentials.
    console.log(JSON.stringify(summary));
  }).catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : "Analytics rebuild failed.");
    process.exitCode = 1;
  });
}
