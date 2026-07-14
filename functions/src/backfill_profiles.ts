import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {existsSync, readFileSync} from "node:fs";
import {resolve} from "node:path";

export function resolveProjectId(): string {
  const environmentProject = process.env.GCLOUD_PROJECT ??
    process.env.GOOGLE_CLOUD_PROJECT;
  if (environmentProject?.trim()) return environmentProject.trim();

  const firebaseConfigPath = resolve(__dirname, "../../.firebaserc");
  if (existsSync(firebaseConfigPath)) {
    const config = JSON.parse(readFileSync(firebaseConfigPath, "utf8")) as {
      projects?: {default?: unknown};
    };
    const configuredProject = config.projects?.default;
    if (typeof configuredProject === "string" && configuredProject.trim()) {
      return configuredProject.trim();
    }
  }

  throw new Error(
    "Unable to determine the Firebase project. Set GOOGLE_CLOUD_PROJECT or configure .firebaserc.",
  );
}

if (!getApps().length) initializeApp({projectId: resolveProjectId()});

type PopulationRole = "student" | "teaching" | "nonTeaching";

export function mapLegacyPopulationRole(value: unknown): PopulationRole | null {
  const role = String(value ?? "").trim().toLowerCase().replace(/[\s_-]+/g, "");
  if (role === "student") return "student";
  if (["faculty", "teaching", "teachingpersonnel"].includes(role)) return "teaching";
  if (["staff", "nonteaching", "nonteachingpersonnel"].includes(role)) return "nonTeaching";
  return null;
}

export function mapLegacyAccessRole(value: unknown): string {
  const role = String(value ?? "").trim().toLowerCase();
  if (role === "admin") return "admin";
  if (role === "counselor" || role === "counsellor") return "counselor";
  return "appUser";
}

export async function backfillProfiles(dryRun = true): Promise<{scanned: number; changed: number}> {
  const snapshot = await getFirestore().collection("users").get();
  let changed = 0;
  const writer = dryRun ? null : getFirestore().bulkWriter();
  for (const document of snapshot.docs) {
    const data = document.data();
    if (Number(data.profileVersion ?? 0) >= 2) continue;
    const populationRole = mapLegacyPopulationRole(data.populationRole ?? data.role);
    const accessRole = data.accessRole ?? mapLegacyAccessRole(data.role);
    const patch = {
      populationRole: populationRole ?? "",
      declaredRole: populationRole ?? "",
      accessRole,
      verificationStatus: "needsReview",
      verifiedAt: null,
      verifiedBy: "",
      employeeId: data.employeeId ?? "",
      yearLevel: data.yearLevel ?? "",
      position: data.position ?? "",
      profileVersion: 2,
      migratedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    changed++;
    if (writer) writer.set(document.ref, patch, {merge: true});
  }
  if (writer) await writer.close();
  return {scanned: snapshot.size, changed};
}

if (require.main === module) {
  const apply = process.argv.includes("--apply");
  backfillProfiles(!apply)
    .then((result) => {
      console.log(JSON.stringify({mode: apply ? "apply" : "dry-run", ...result}));
    })
    .catch((error) => {
      const message = error instanceof Error ? error.message : String(error);
      if (message.includes("default credentials") ||
          message.includes("Could not load the default credentials") ||
          message.includes("Could not refresh access token")) {
        console.error(
          "Google credentials are required to read production Firestore.\n" +
          "Use Application Default Credentials (`gcloud auth application-default login`) " +
          "or set GOOGLE_APPLICATION_CREDENTIALS to a service-account JSON file.\n" +
          "Never commit that JSON file to the repository.",
        );
      } else {
        console.error(error);
      }
      process.exitCode = 1;
    });
}
