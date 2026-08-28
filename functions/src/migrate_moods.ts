import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {manilaDateKey} from "./wellness";
import {resolveProjectId} from "./backfill_profiles";

if (!getApps().length) initializeApp({projectId: resolveProjectId()});

function idDateKey(id: string): string | null {
  const match = /^daily_[^_]+_(\d{8})$/.exec(id);
  return match?.[1] ?? null;
}

function storedDateKey(value: unknown): string | null {
  const raw = typeof value === "string" ? value.replaceAll("-", "") : "";
  return /^\d{8}$/.test(raw) ? raw : null;
}

export async function migrateMoods(dryRun = true) {
  const db = getFirestore();
  const moods = await db.collection("moods").get();
  const seen = new Set<string>();
  const writer = dryRun ? null : db.bulkWriter();
  let migrated = 0;
  let alreadyCanonical = 0;
  let quarantined = 0;

  for (const document of moods.docs) {
    const data = document.data();
    if (data.schemaVersion === 2) {
      alreadyCanonical++;
      continue;
    }
    const userId = typeof data.userId === "string" ? data.userId : "";
    const createdAt = data.createdAt instanceof Timestamp ? data.createdAt : null;
    const derived = createdAt ? manilaDateKey(createdAt) : null;
    const stored = storedDateKey(data.dateKey);
    const fromId = idDateKey(document.id);
    const evidence = [stored, fromId].filter((value): value is string => value != null);
    const targetId = derived && userId ? `daily_${userId}_${derived}` : null;
    const consistent = derived != null && evidence.every((value) => value === derived) && targetId != null;
    if (!consistent || seen.has(targetId!)) {
      quarantined++;
      if (writer) writer.set(db.collection("mood_migration_quarantine").doc(document.id), {
        sourceMoodId: document.id, reason: !derived ? "missing_trusted_created_at" : "conflicting_or_duplicate_date", data,
        quarantinedAt: FieldValue.serverTimestamp(),
      });
      continue;
    }
    seen.add(targetId!);
    migrated++;
    if (writer) writer.create(db.collection("moods").doc(targetId!), {
      schemaVersion: 2, userId, moodKey: "legacy", label: String(data.label ?? ""),
      level: Number(data.level ?? 0), note: String(data.note ?? ""), dateKey: derived,
      timezone: "Asia/Manila", createdAt, legacySourceMoodId: document.id,
      migratedAt: FieldValue.serverTimestamp(),
    });
  }
  if (writer) await writer.close();
  return {scanned: moods.size, migrated, alreadyCanonical, quarantined};
}

export async function resetLegacyWellnessStreaks(dryRun = true) {
  const db = getFirestore();
  const users = await db.collection("users").get();
  const writer = dryRun ? null : db.bulkWriter();
  for (const user of users.docs) {
    const data = user.data();
    if (writer) {
      writer.set(db.collection("wellness_migration_audit").doc(user.id), {
        userId: user.id,
        legacyDayStreak: Number(data.dayStreak ?? 0) || 0,
        legacyLongestStreak: Number(data.longestStreak ?? 0) || 0,
        legacyLastActivityDateKey: String(data.lastActivityDateKey ?? ""),
        legacyActiveDateKeys: Array.isArray(data.activeDateKeys) ? data.activeDateKeys : [],
        archivedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      writer.set(user.ref, {
        dayStreak: 0,
        longestStreak: 0,
        lastQualifyingActivityDateKey: "",
        lastQualifyingActivityAt: null,
        activeDateKeys: [],
        lastActivityDateKey: FieldValue.delete(),
        streakUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  }
  if (writer) await writer.close();
  return {scanned: users.size, reset: users.size};
}

if (require.main === module) {
  const apply = process.argv.includes("--apply");
  Promise.all([migrateMoods(!apply), resetLegacyWellnessStreaks(!apply)])
    .then(([moods, users]) => console.log(JSON.stringify({mode: apply ? "apply" : "dry-run", moods, users})))
    .catch((error) => { console.error(error); process.exitCode = 1; });
}
