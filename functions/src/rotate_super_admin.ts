import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth, UserRecord} from "firebase-admin/auth";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";

const EXPECTED_PROJECT = "mindmate-dev-4e91c";
const ROTATION_COLLECTION = "_super_admin_rotations";
const ROTATION_DOCUMENT = "current";
const MODES = ["prepare", "cutover", "rollback", "finalize"] as const;
type RotationMode = typeof MODES[number];

type CheckMap = Record<string, boolean | number | string>;

export function validateTemporaryPassword(password: string): boolean {
  return password.length >= 12 && password.length <= 128 &&
    /[a-z]/.test(password) && /[A-Z]/.test(password) &&
    /[0-9]/.test(password) && /[^A-Za-z0-9]/.test(password) &&
    !/\s/.test(password);
}

export function validRotationTransition(status: string, mode: RotationMode): boolean {
  return mode === "prepare" ? !["prepared", "cutover", "finalizing"].includes(status) :
    mode === "cutover" ? status === "prepared" :
      mode === "rollback" ? ["prepared", "cutover", "rolledBack"].includes(status) :
        ["cutover", "finalizing", "finalized"].includes(status);
}

function selectedMode(): RotationMode {
  const index = process.argv.indexOf("--mode");
  const value = index >= 0 ? process.argv[index + 1] : "";
  if (!MODES.includes(value as RotationMode)) {
    throw new Error("Choose --mode prepare, cutover, rollback, or finalize.");
  }
  return value as RotationMode;
}

async function hiddenPrompt(label: string): Promise<string> {
  if (!process.stdin.isTTY || !process.stdout.isTTY || !process.stdin.setRawMode) {
    throw new Error("Secure credential input requires an interactive terminal.");
  }
  process.stdout.write(`${label}: `);
  process.stdin.setEncoding("utf8");
  process.stdin.setRawMode(true);
  process.stdin.resume();
  return await new Promise<string>((resolve, reject) => {
    let value = "";
    const finish = (error?: Error) => {
      process.stdin.off("data", onData);
      process.stdin.setRawMode(false);
      process.stdin.pause();
      process.stdout.write("\n");
      if (error) reject(error); else resolve(value);
    };
    const onData = (chunk: string) => {
      for (const character of chunk) {
        if (character === "\u0003") return finish(new Error("Credential input cancelled."));
        if (character === "\r" || character === "\n") return finish();
        if (character === "\u007f" || character === "\b") {
          value = value.slice(0, -1);
        } else if (character >= " ") {
          value += character;
        }
      }
    };
    process.stdin.on("data", onData);
  });
}

async function authUserForEmail(email: string): Promise<UserRecord | null> {
  try {
    return await getAuth().getUserByEmail(email);
  } catch (error) {
    if ((error as {code?: string}).code === "auth/user-not-found") return null;
    throw error;
  }
}

async function authUser(uid: string): Promise<UserRecord | null> {
  try {
    return await getAuth().getUser(uid);
  } catch (error) {
    if ((error as {code?: string}).code === "auth/user-not-found") return null;
    throw error;
  }
}

function output(mode: RotationMode, apply: boolean, status: string, checks: CheckMap): void {
  console.log(JSON.stringify({mode, apply, status, checks}));
}

function copiedProfileFields(data: FirebaseFirestore.DocumentData): Record<string, unknown> {
  const fields = [
    "firstName", "middleName", "lastName", "name", "employeeId", "employeeIdKey",
    "position", "department", "departmentId", "collegeId", "courseId",
    "populationRole", "declaredRole", "role", "profileVersion",
  ] as const;
  return Object.fromEntries(fields.filter((field) => data[field] != null).map((field) => [field, data[field]]));
}

function timestampMillis(value: unknown): number {
  return value instanceof Timestamp ? value.toMillis() : 0;
}

async function prepare(apply: boolean): Promise<void> {
  const db = getFirestore();
  const email = (await hiddenPrompt("New administrator email (hidden)")).trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error("Enter a valid email address.");

  const [admins, security, rotation, existingCandidate] = await Promise.all([
    db.collection("users").where("accessRole", "==", "admin").get(),
    db.collection("system_config").doc("security").get(),
    db.collection(ROTATION_COLLECTION).doc(ROTATION_DOCUMENT).get(),
    authUserForEmail(email),
  ]);
  const currentStatus = String(rotation.data()?.status ?? "none");
  const oldProfile = admins.size === 1 ? admins.docs[0] : null;
  const oldUid = oldProfile?.id ?? "";
  const oldData = oldProfile?.data() ?? {};
  const securityUid = String(security.data()?.superAdminUid ?? "");
  const employeeReservationId = String(oldData.employeeIdKey ?? "");
  const reservation = employeeReservationId ?
    await db.collection("employee_id_reservations").doc(employeeReservationId).get() : null;
  const checks = {
    exactlyOneAdmin: admins.size === 1,
    securityMatchesCurrentAdmin: Boolean(oldUid && securityUid === oldUid),
    noActiveRotation: validRotationTransition(currentStatus, "prepare"),
    candidateEmailAvailable: existingCandidate == null,
    candidateEmailDiffers: String(oldData.email ?? "").toLowerCase() !== email,
    employeeReservationMatches: Boolean(
      reservation?.exists && reservation.data()?.userId === oldUid,
    ),
  };
  output("prepare", apply, "preflight", checks);
  if (!Object.values(checks).every(Boolean) || !apply) return;

  const password = await hiddenPrompt("One-time password (hidden)");
  if (!validateTemporaryPassword(password)) {
    throw new Error("The one-time password must be 12-128 characters with upper, lower, number, and symbol characters and no spaces.");
  }
  const displayName = String(oldData.name ?? "MindMates Administrator");
  const candidate = await getAuth().createUser({
    email,
    password,
    emailVerified: false,
    disabled: false,
    displayName,
  });
  const preparedAt = Timestamp.now();
  try {
    await db.runTransaction(async (transaction) => {
      const rotationRef = db.collection(ROTATION_COLLECTION).doc(ROTATION_DOCUMENT);
      const latest = await transaction.get(rotationRef);
      if (!validRotationTransition(String(latest.data()?.status ?? "none"), "prepare")) {
        throw new Error("Another super-administrator rotation is active.");
      }
      transaction.create(db.collection("users").doc(candidate.uid), {
        ...copiedProfileFields(oldData),
        id: candidate.uid,
        email,
        accessRole: "portalStaff",
        staffAccountStatus: "pending",
        mustChangePassword: true,
        superAdminCandidate: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(rotationRef, {
        status: "prepared",
        oldUid,
        newUid: candidate.uid,
        employeeReservationId,
        preparedAt,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (error) {
    await getAuth().deleteUser(candidate.uid).catch(() => undefined);
    throw error;
  }
  output("prepare", true, "prepared", {candidateCreated: true, currentAdminPreserved: true});
}

async function cutover(apply: boolean): Promise<void> {
  const db = getFirestore();
  const rotationRef = db.collection(ROTATION_COLLECTION).doc(ROTATION_DOCUMENT);
  const rotation = await rotationRef.get();
  const data = rotation.data() ?? {};
  const status = String(data.status ?? "none");
  if (!validRotationTransition(status, "cutover")) {
    output("cutover", apply, status, {preparedRotationExists: false});
    return;
  }
  const oldUid = String(data.oldUid ?? "");
  const newUid = String(data.newUid ?? "");
  const reservationId = String(data.employeeReservationId ?? "");
  const [oldProfile, newProfile, security, reservation, candidate] = await Promise.all([
    db.collection("users").doc(oldUid).get(),
    db.collection("users").doc(newUid).get(),
    db.collection("system_config").doc("security").get(),
    db.collection("employee_id_reservations").doc(reservationId).get(),
    authUser(newUid),
  ]);
  const preparedAt = timestampMillis(data.preparedAt);
  const lastSignIn = Date.parse(candidate?.metadata.lastSignInTime ?? "");
  const checks = {
    oldProfileIsActiveAdmin: oldProfile.data()?.accessRole === "admin",
    candidateProfileIsPending: newProfile.data()?.accessRole === "portalStaff" &&
      newProfile.data()?.staffAccountStatus === "pending",
    securityMatchesOldAdmin: security.data()?.superAdminUid === oldUid,
    employeeReservationMatchesOldAdmin: reservation.data()?.userId === oldUid,
    candidateAuthEnabled: candidate != null && !candidate.disabled,
    candidateEmailVerified: candidate?.emailVerified === true,
    candidatePasswordConfigured: candidate?.providerData.some((item) => item.providerId === "password") === true,
    candidateSignedInAfterPreparation: Number.isFinite(lastSignIn) && lastSignIn >= preparedAt,
  };
  output("cutover", apply, "preflight", checks);
  if (!Object.values(checks).every(Boolean) || !apply) return;

  const cutoverAt = Timestamp.now();
  await db.runTransaction(async (transaction) => {
    const [latestRotation, latestOld, latestNew, latestSecurity, latestReservation] = await Promise.all([
      transaction.get(rotationRef),
      transaction.get(db.collection("users").doc(oldUid)),
      transaction.get(db.collection("users").doc(newUid)),
      transaction.get(db.collection("system_config").doc("security")),
      transaction.get(db.collection("employee_id_reservations").doc(reservationId)),
    ]);
    if (latestRotation.data()?.status !== "prepared" ||
        latestOld.data()?.accessRole !== "admin" ||
        latestNew.data()?.staffAccountStatus !== "pending" ||
        latestSecurity.data()?.superAdminUid !== oldUid ||
        latestReservation.data()?.userId !== oldUid) {
      throw new Error("Super-administrator rotation state changed during cutover.");
    }
    transaction.update(latestOld.ref, {
      accessRole: "portalStaff",
      previousAccessRole: "admin",
      staffAccountStatus: "disabled",
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(latestNew.ref, {
      accessRole: "admin",
      staffAccountStatus: "approved",
      verifiedBy: oldUid,
      verifiedAt: FieldValue.serverTimestamp(),
      superAdminCandidate: FieldValue.delete(),
      mustChangePassword: true,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(latestReservation.ref, {userId: newUid, updatedAt: FieldValue.serverTimestamp()});
    transaction.set(latestSecurity.ref, {superAdminUid: newUid, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    transaction.update(rotationRef, {status: "cutover", cutoverAt, updatedAt: FieldValue.serverTimestamp()});
    transaction.create(db.collection("admin_audit_logs").doc(), {
      actorId: oldUid,
      targetUserId: newUid,
      action: "superAdminIdentityRotated",
      reason: "Guarded super-administrator identity replacement",
      before: {activeUid: oldUid},
      after: {activeUid: newUid},
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  output("cutover", true, "cutover", {atomicCutoverCompleted: true, oldAuthPreservedForRollback: true});
}

async function rollback(apply: boolean): Promise<void> {
  const db = getFirestore();
  const rotationRef = db.collection(ROTATION_COLLECTION).doc(ROTATION_DOCUMENT);
  const rotation = await rotationRef.get();
  const data = rotation.data() ?? {};
  const status = String(data.status ?? "none");
  if (!validRotationTransition(status, "rollback")) {
    output("rollback", apply, status, {rollbackAvailable: false});
    return;
  }
  const oldUid = String(data.oldUid ?? "");
  const newUid = String(data.newUid ?? "");
  const reservationId = String(data.employeeReservationId ?? "");
  output("rollback", apply, status, {rollbackAvailable: true});
  if (!apply) return;

  if (status === "prepared") {
    await db.runTransaction(async (transaction) => {
      transaction.delete(db.collection("users").doc(newUid));
      transaction.update(rotationRef, {status: "rolledBack", updatedAt: FieldValue.serverTimestamp()});
    });
    await getAuth().deleteUser(newUid).catch((error) => {
      if ((error as {code?: string}).code !== "auth/user-not-found") throw error;
    });
  } else if (status === "cutover") {
    await db.runTransaction(async (transaction) => {
      const securityRef = db.collection("system_config").doc("security");
      const security = await transaction.get(securityRef);
      if (security.data()?.superAdminUid !== newUid) {
        throw new Error("The active super-administrator changed after cutover.");
      }
      transaction.update(db.collection("users").doc(oldUid), {
        accessRole: "admin",
        previousAccessRole: FieldValue.delete(),
        staffAccountStatus: "approved",
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(db.collection("users").doc(newUid), {
        accessRole: "portalStaff",
        staffAccountStatus: "disabled",
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(db.collection("employee_id_reservations").doc(reservationId), {
        userId: oldUid,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(securityRef, {superAdminUid: oldUid, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
      transaction.update(rotationRef, {status: "rolledBack", rolledBackAt: FieldValue.serverTimestamp()});
      transaction.create(db.collection("admin_audit_logs").doc(), {
        actorId: oldUid,
        targetUserId: newUid,
        action: "superAdminIdentityRotationRolledBack",
        reason: "Replacement verification did not complete",
        createdAt: FieldValue.serverTimestamp(),
      });
    });
    await getAuth().updateUser(newUid, {disabled: true});
  } else {
    await getAuth().updateUser(newUid, {disabled: true}).catch(() => undefined);
    await db.collection("users").doc(newUid).set({staffAccountStatus: "disabled"}, {merge: true});
  }
  output("rollback", true, "rolledBack", {currentAdminRestored: true, candidateInactive: true});
}

async function finalize(apply: boolean): Promise<void> {
  const db = getFirestore();
  const rotationRef = db.collection(ROTATION_COLLECTION).doc(ROTATION_DOCUMENT);
  const rotation = await rotationRef.get();
  const data = rotation.data() ?? {};
  const status = String(data.status ?? "none");
  if (status === "finalized") {
    output("finalize", apply, status, {alreadyFinalized: true});
    return;
  }
  if (!validRotationTransition(status, "finalize")) {
    output("finalize", apply, status, {finalizationAvailable: false});
    return;
  }
  const oldUid = String(data.oldUid ?? "");
  const newUid = String(data.newUid ?? "");
  const [security, newProfile, newUser] = await Promise.all([
    db.collection("system_config").doc("security").get(),
    db.collection("users").doc(newUid).get(),
    authUser(newUid),
  ]);
  const cutoverAt = timestampMillis(data.cutoverAt);
  const lastSignIn = Date.parse(newUser?.metadata.lastSignInTime ?? "");
  const checks = {
    replacementIsActiveSecurityUid: security.data()?.superAdminUid === newUid,
    replacementProfileIsAdmin: newProfile.data()?.accessRole === "admin" &&
      newProfile.data()?.staffAccountStatus === "approved",
    mandatoryPasswordChangeCompleted: newProfile.data()?.mustChangePassword === false,
    replacementSignedInAfterCutover: Number.isFinite(lastSignIn) && lastSignIn >= cutoverAt,
    oldIdentityIsNotActive: security.data()?.superAdminUid !== oldUid,
  };
  output("finalize", apply, status, checks);
  if (!Object.values(checks).every(Boolean) || !apply) return;

  if (status === "cutover") {
    await rotationRef.update({status: "finalizing", updatedAt: FieldValue.serverTimestamp()});
  }
  await getAuth().deleteUser(oldUid).catch((error) => {
    if ((error as {code?: string}).code !== "auth/user-not-found") throw error;
  });
  await db.runTransaction(async (transaction) => {
    const latestSecurity = await transaction.get(db.collection("system_config").doc("security"));
    if (latestSecurity.data()?.superAdminUid !== newUid) {
      throw new Error("Refusing to delete a profile while the security authority is changing.");
    }
    transaction.delete(db.collection("users").doc(oldUid));
    transaction.update(rotationRef, {status: "finalized", finalizedAt: FieldValue.serverTimestamp()});
    transaction.create(db.collection("admin_audit_logs").doc(), {
      actorId: newUid,
      targetUserId: oldUid,
      action: "previousSuperAdminIdentityDeleted",
      reason: "Replacement administrator passed login and password-change verification",
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  output("finalize", true, "finalized", {oldAuthDeleted: true, oldProfileDeleted: true, auditPreserved: true});
}

async function main(): Promise<void> {
  const mode = selectedMode();
  const apply = process.argv.includes("--apply");
  const project = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || EXPECTED_PROJECT;
  if (project !== EXPECTED_PROJECT) throw new Error("Refusing to operate on an unexpected Firebase project.");
  if (!getApps().length) initializeApp({projectId: EXPECTED_PROJECT});
  if (mode === "prepare") await prepare(apply);
  if (mode === "cutover") await cutover(apply);
  if (mode === "rollback") await rollback(apply);
  if (mode === "finalize") await finalize(apply);
}

if (require.main === module) {
  void main().catch((error) => {
    const message = error instanceof Error ? error.message : "Super-administrator rotation failed.";
    console.error(message.replace(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g, "[redacted-email]"));
    process.exitCode = 1;
  });
}
