import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
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

export function obsoleteRoleVerificationFields(
  data: Record<string, unknown>,
): string[] {
  const fields: string[] = [];
  const has = (key: string) => Object.prototype.hasOwnProperty.call(data, key);
  if (has("verificationStatus")) fields.push("verificationStatus");

  if (!isStaffProfile(data)) {
    if (has("verifiedAt")) fields.push("verifiedAt");
    if (has("verifiedBy")) fields.push("verifiedBy");
  }
  return fields;
}

export function isStaffProfile(data: Record<string, unknown>): boolean {
  const accessRole = String(data.accessRole ?? "appUser");
  return data.staffAccountStatus != null ||
    ["portalStaff", "counselor", "admin"].includes(accessRole);
}

export async function backfillProfiles(dryRun = true): Promise<{
  scanned: number; changed: number; completionCleared: number;
  authUsers: number; authWithoutProfile: number;
  rolePolicyProfilesChanged: number; roleVerificationFieldsRemoved: number;
  appUserProfiles: number; staffProfiles: number; assessmentDocuments: number;
}> {
  const database = getFirestore();
  const [snapshot, assessmentSnapshot, assessmentCount] = await Promise.all([
    database.collection("users").get(),
    database.collection("assessments").where("type", "==", "quick").get(),
    database.collection("assessments").count().get(),
  ]);
  const verifiedQuickUsers = new Set(assessmentSnapshot.docs
    .filter((doc) => doc.data().calculationAuthority === "server" &&
      doc.data().verificationStatus === "verified" && typeof doc.data().userId === "string")
    .map((doc) => String(doc.data().userId)));
  const profileIds = new Set(snapshot.docs.map((doc) => doc.id));
  let authUsers = 0;
  let authWithoutProfile = 0;
  let pageToken: string | undefined;
  do {
    const page = await getAuth().listUsers(1000, pageToken);
    authUsers += page.users.length;
    authWithoutProfile += page.users.filter((user) => !profileIds.has(user.uid)).length;
    pageToken = page.pageToken;
  } while (pageToken);
  let changed = 0;
  let completionCleared = 0;
  let rolePolicyProfilesChanged = 0;
  let roleVerificationFieldsRemoved = 0;
  let appUserProfiles = 0;
  let staffProfiles = 0;
  const writer = dryRun ? null : database.bulkWriter();
  for (const document of snapshot.docs) {
    const data = document.data();
    if (isStaffProfile(data)) staffProfiles++;
    else appUserProfiles++;
    const patch: Record<string, unknown> = {};
    if (Number(data.profileVersion ?? 0) < 2) {
      const populationRole = mapLegacyPopulationRole(data.populationRole ?? data.role);
      patch.populationRole = populationRole ?? "";
      patch.declaredRole = populationRole ?? "";
      patch.accessRole = data.accessRole ?? mapLegacyAccessRole(data.role);
      patch.employeeId = data.employeeId ?? "";
      patch.yearLevel = data.yearLevel ?? "";
      patch.position = data.position ?? "";
      patch.profileVersion = 2;
    }
    const obsoleteFields = obsoleteRoleVerificationFields(data);
    if (obsoleteFields.length > 0) {
      for (const field of obsoleteFields) patch[field] = FieldValue.delete();
      rolePolicyProfilesChanged++;
      roleVerificationFieldsRemoved += obsoleteFields.length;
    }
    if (data.quickAssessmentCompleted === true && !verifiedQuickUsers.has(document.id)) {
      patch.quickAssessmentCompleted = false;
      patch.quickAssessmentCompletedAt = null;
      completionCleared++;
    }
    if (Object.keys(patch).length === 0) continue;
    patch.migratedAt = FieldValue.serverTimestamp();
    patch.updatedAt = FieldValue.serverTimestamp();
    changed++;
    if (writer) writer.set(document.ref, patch, {merge: true});
  }
  if (writer) await writer.close();
  return {
    scanned: snapshot.size,
    changed,
    completionCleared,
    authUsers,
    authWithoutProfile,
    rolePolicyProfilesChanged,
    roleVerificationFieldsRemoved,
    appUserProfiles,
    staffProfiles,
    assessmentDocuments: assessmentCount.data().count,
  };
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
