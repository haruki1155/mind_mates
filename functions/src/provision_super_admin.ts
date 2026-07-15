import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth, UserRecord} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {randomBytes} from "node:crypto";
import {writeFile} from "node:fs/promises";
import {resolve} from "node:path";

const EXPECTED_PROJECT = "mind-mates-cd2cf";
if (!getApps().length) initializeApp({projectId: EXPECTED_PROJECT});
const db = getFirestore();
const auth = getAuth();

function argument(name: string, fallback: string): string {
  const index = process.argv.indexOf(`--${name}`);
  return (index >= 0 ? process.argv[index + 1] : fallback)?.trim() ?? "";
}

function temporaryPassword(): string {
  return `Mm!${randomBytes(18).toString("base64url")}9a`;
}

async function authUserForEmail(email: string): Promise<UserRecord | null> {
  try {
    return await auth.getUserByEmail(email);
  } catch (error) {
    if ((error as {code?: string}).code === "auth/user-not-found") return null;
    throw error;
  }
}

async function main(): Promise<void> {
  const apply = process.argv.includes("--apply");
  const project = argument("project", EXPECTED_PROJECT);
  if (project !== EXPECTED_PROJECT) throw new Error(`Refusing project ${project}. Expected ${EXPECTED_PROJECT}.`);
  const email = argument("email", "tacap25132@lasttea.com").toLowerCase();
  const employeeId = argument("employee-id", "20221234");
  const firstName = argument("first-name", "Morris");
  const middleName = argument("middle-name", "Jinn");
  const lastName = argument("last-name", "Guntang");
  const position = argument("position", "System Administrator");
  const department = argument("department", "Administration");
  const employeeIdKey = employeeId.toUpperCase().replace(/[^A-Z0-9]/g, "");

  const [existingAuth, security, reservation, admins] = await Promise.all([
    authUserForEmail(email), db.collection("system_config").doc("security").get(),
    db.collection("employee_id_reservations").doc(employeeIdKey).get(),
    db.collection("users").where("accessRole", "==", "admin").get(),
  ]);
  const candidateUid = existingAuth?.uid ?? null;
  const configuredUid = String(security.data()?.superAdminUid ?? "");
  const conflictingAdmin = admins.docs.find((doc) => candidateUid == null || doc.id !== candidateUid);
  if (conflictingAdmin) throw new Error(`Another administrator already exists: ${conflictingAdmin.id}`);
  if (configuredUid && candidateUid && configuredUid !== candidateUid) throw new Error(`Security configuration belongs to another UID: ${configuredUid}`);
  if (configuredUid && !candidateUid) throw new Error(`Security configuration already reserves UID ${configuredUid}`);
  if (reservation.exists && candidateUid && reservation.data()?.userId !== candidateUid) throw new Error("Employee ID belongs to another account.");
  if (reservation.exists && !candidateUid) throw new Error("Employee ID is already reserved.");

  console.log(JSON.stringify({mode: apply ? "apply" : "dry-run", project, email, employeeId,
    existingAuth: existingAuth != null, configuredUid: configuredUid || null, existingAdmins: admins.size}));
  if (!apply) return;

  const password = temporaryPassword();
  const displayName = [firstName, middleName, lastName].filter(Boolean).join(" ");
  const user = existingAuth == null ? await auth.createUser({email, password, emailVerified: true, displayName}) :
    await auth.updateUser(existingAuth.uid, {password, emailVerified: true, displayName, disabled: false});
  const userRef = db.collection("users").doc(user.uid);
  const reservationRef = db.collection("employee_id_reservations").doc(employeeIdKey);
  const securityRef = db.collection("system_config").doc("security");
  await db.runTransaction(async (transaction) => {
    const [profile, currentReservation, currentSecurity] = await Promise.all([
      transaction.get(userRef), transaction.get(reservationRef), transaction.get(securityRef),
    ]);
    if (profile.exists && String(profile.data()?.email ?? "").toLowerCase() !== email) throw new Error("UID profile email conflict.");
    if (currentReservation.exists && currentReservation.data()?.userId !== user.uid) throw new Error("Employee ID conflict.");
    if (currentSecurity.exists && currentSecurity.data()?.superAdminUid !== user.uid) throw new Error("Super-admin UID conflict.");
    transaction.set(reservationRef, {userId: user.uid, employeeId, createdAt: currentReservation.data()?.createdAt ?? FieldValue.serverTimestamp()}, {merge: true});
    transaction.set(userRef, {
      id: user.uid, email, firstName, middleName, lastName, name: displayName,
      employeeId, employeeIdKey, position, department, populationRole: "nonTeaching",
      declaredRole: "nonTeaching", role: "staff", accessRole: "admin",
      staffAccountStatus: "approved", verificationStatus: "verified", verifiedBy: user.uid,
      verifiedAt: profile.data()?.verifiedAt ?? FieldValue.serverTimestamp(), mustChangePassword: true,
      profileVersion: 3, createdAt: profile.data()?.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.set(securityRef, {superAdminUid: user.uid, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
  const envPath = resolve(process.cwd(), `.env.${EXPECTED_PROJECT}`);
  await writeFile(envPath, `SUPER_ADMIN_UID=${user.uid}\n`, {encoding: "utf8", mode: 0o600});
  console.log(`ADMIN_UID=${user.uid}`);
  console.log(`ADMIN_EMAIL=${email}`);
  console.log(`TEMPORARY_PASSWORD=${password}`);
  console.log(`ENV_FILE=${envPath}`);
  console.log("IMPORTANT: This password was not stored by the provisioning script. Change it on first login.");
}

void main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
