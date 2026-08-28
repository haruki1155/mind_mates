import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {getAuth} from "firebase-admin/auth";
import {getDownloadURL, getStorage} from "firebase-admin/storage";
import {onDocumentCreated, onDocumentDeleted, onDocumentWritten} from "firebase-functions/v2/firestore";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {randomBytes, randomUUID} from "node:crypto";
import {superAdminUidFromSecurity} from "./admin_security";
import {recordServiceSuccess, serviceKeyForActivity} from "./service_monitoring";
export {aggregateMindAidFeedback, sendMindAidMessage, sendMindAidMessageDev} from "./mind_aid";
export {submitQuickAssessment, submitQuickAssessmentDev, submitFullAssessment,
  submitFullAssessmentDev} from "./assessment/submissions";
export {provisionAppUserProfile, provisionAppUserProfileDev, getAssessmentStatus,
  getAssessmentStatusDev} from "./account_integrity";
export {requestRecoveryEmailVerification, confirmRecoveryEmailVerification,
  requestPasswordRecovery, confirmPasswordRecovery,
  requestRecoveryEmailVerificationDev, confirmRecoveryEmailVerificationDev,
  requestPasswordRecoveryDev, confirmPasswordRecoveryDev} from "./account_recovery";
export {listPublicAppUsers, listPublicAppUsersDev, getAppUserDashboardSummary,
  getAppUserDashboardSummaryDev} from "./admin_directory";
export {getAdminServiceMonitoring, getAdminServiceMonitoringDev,
  purgeServiceMonitoring} from "./service_monitoring";
export {createAppointmentRequest, reviewAppointment, respondToAppointmentReschedule,
  scheduleAppointmentFollowUp, createAppointmentRequestDev, reviewAppointmentDev,
  respondToAppointmentRescheduleDev, scheduleAppointmentFollowUpDev,
  canonicalAppointmentStatus,
  canTransitionAppointment} from "./appointment_workflow";
export {startBreathingSession, startBreathingSessionDev, completeBreathingSession,
  completeBreathingSessionDev} from "./breathing_sessions";
export {logDailyMood} from "./mood_logging";
export {recordSecretChatPostActivity, recordSecretChatCommentActivity} from "./activity_triggers";
export {recordAppOpen} from "./activity_logging";
export {setSleepCloudConsent, setSleepCloudConsentDev, saveSleepEntry,
  saveSleepEntryDev, deleteSleepEntry, deleteSleepEntryDev,
  deleteAllSleepEntries, deleteAllSleepEntriesDev, revokeSleepCloud,
  revokeSleepCloudDev, setCounselorAssignment, setCounselorAssignmentDev,
  createSleepShare, createSleepShareDev, revokeSleepShare,
  revokeSleepShareDev} from "./sleep_wellness";

if (!getApps().length) initializeApp();

const db = getFirestore();
const posts = db.collection("secret_chats");
const stats = db.collection("secret_chat_profile_stats");
const events = db.collection("_secret_chat_events");
const analyticsEvents = db.collection("_analytics_events");
const secretChatProfiles = db.collection("secret_chat_profiles");
const secretChatAliases = db.collection("secret_chat_aliases");
const publicUserIds = db.collection("user_public_ids");
const publicUserIdReservations = db.collection("public_user_id_reservations");
const accountDeletionJobs = db.collection("_account_deletion_jobs");

const INACTIVE_ACCOUNT_DAYS = 7;
const INACTIVE_ACCOUNT_MS = INACTIVE_ACCOUNT_DAYS * 24 * 60 * 60 * 1000;

const SECRET_CHAT_ALIAS_PATTERN = /^[A-Za-z0-9]+(?: [A-Za-z0-9]+)*$/;
const SECRET_CHAT_PHOTO_PATTERN = /^secret_chat_profiles\/([^/]+)\/avatar_[0-9]+\.(jpg|png)$/;
const MAX_SECRET_CHAT_PHOTO_BYTES = 5 * 1024 * 1024;

function requireAuthenticatedUser(request: {auth?: {uid: string}}): string {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError("unauthenticated", "Sign in is required.");
  return userId;
}

export function normalizeSecretChatAlias(value: unknown): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "A public name is required.");
  }
  const alias = value.trim().replace(/\s+/g, " ");
  if (alias.length < 1 || alias.length > 30 || !SECRET_CHAT_ALIAS_PATTERN.test(alias)) {
    throw new HttpsError(
      "invalid-argument",
      "Use 1 to 30 letters, numbers, and single spaces only.",
    );
  }
  return alias;
}

export function isValidSecretChatPhotoPath(userId: string, photoPath: string): boolean {
  const match = SECRET_CHAT_PHOTO_PATTERN.exec(photoPath);
  return match !== null && match[1] === userId;
}

function callableProfile(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): Record<string, unknown> {
  const profile = snapshot.data() ?? {};
  const timestamp = profile.updatedAt;
  return {
    userId: snapshot.id,
    alias: String(profile.alias ?? "Anonymous"),
    aliasKey: String(profile.aliasKey ?? ""),
    ...(typeof profile.photoUrl === "string" ? {photoUrl: profile.photoUrl} : {}),
    ...(typeof profile.photoPath === "string" ? {photoPath: profile.photoPath} : {}),
    ...(timestamp instanceof Timestamp ? {updatedAt: timestamp.toDate().toISOString()} : {}),
  };
}

async function saveSecretChatProfileHandler(request: CallableRequest) {
  const userId = requireAuthenticatedUser(request);
  const alias = normalizeSecretChatAlias(request.data?.alias);
  const aliasKey = alias.toLowerCase();
  const profileRef = secretChatProfiles.doc(userId);
  const aliasRef = secretChatAliases.doc(aliasKey);

  await db.runTransaction(async (transaction) => {
    const profileSnapshot = await transaction.get(profileRef);
    const aliasSnapshot = await transaction.get(aliasRef);
    const previousKey = String(profileSnapshot.data()?.aliasKey ?? "");
    const previousAliasRef = previousKey && previousKey !== aliasKey ?
      secretChatAliases.doc(previousKey) : null;
    const previousAliasSnapshot = previousAliasRef ?
      await transaction.get(previousAliasRef) : null;

    if (aliasSnapshot.exists && aliasSnapshot.data()?.userId !== userId) {
      throw new HttpsError("already-exists", "That Secret Chat name is already taken.");
    }

    transaction.set(aliasRef, {
      userId,
      alias,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(profileRef, {
      userId,
      alias,
      aliasKey,
      createdAt: profileSnapshot.data()?.createdAt instanceof Timestamp ?
        profileSnapshot.data()?.createdAt : FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    if (previousAliasRef && previousAliasSnapshot?.data()?.userId === userId) {
      transaction.delete(previousAliasRef);
    }
  });

  return {profile: callableProfile(await profileRef.get())};
}

export const saveSecretChatProfile = onCall({enforceAppCheck: true}, saveSecretChatProfileHandler);
export const saveSecretChatProfileDev = onCall({enforceAppCheck: false}, saveSecretChatProfileHandler);

async function finalizeSecretChatProfilePhotoHandler(request: CallableRequest) {
  const userId = requireAuthenticatedUser(request);
  const photoPath = typeof request.data?.photoPath === "string" ?
    request.data.photoPath : "";
  if (!isValidSecretChatPhotoPath(userId, photoPath)) {
    throw new HttpsError("invalid-argument", "The profile photo path is invalid.");
  }

  const file = getStorage().bucket().file(photoPath);
  const [exists] = await file.exists();
  if (!exists) throw new HttpsError("not-found", "The uploaded photo was not found.");
  const [metadata] = await file.getMetadata();
  const size = Number(metadata.size ?? 0);
  if (size < 1 || size > MAX_SECRET_CHAT_PHOTO_BYTES ||
      (metadata.contentType !== "image/jpeg" && metadata.contentType !== "image/png")) {
    throw new HttpsError("invalid-argument", "The uploaded photo is not a valid JPEG or PNG.");
  }

  const profileRef = secretChatProfiles.doc(userId);
  const before = await profileRef.get();
  if (!before.exists || typeof before.data()?.alias !== "string") {
    throw new HttpsError("failed-precondition", "Save a public name before adding a photo.");
  }
  const photoUrl = await getDownloadURL(file);
  await profileRef.set({
    photoUrl,
    photoPath,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  const previousPath = before.data()?.photoPath;
  if (typeof previousPath === "string" && previousPath !== photoPath) {
    await getStorage().bucket().file(previousPath).delete({ignoreNotFound: true}).catch(() => undefined);
  }
  return {profile: callableProfile(await profileRef.get())};
}

export const finalizeSecretChatProfilePhoto = onCall({enforceAppCheck: true}, finalizeSecretChatProfilePhotoHandler);
export const finalizeSecretChatProfilePhotoDev = onCall({enforceAppCheck: false}, finalizeSecretChatProfilePhotoHandler);

async function removeSecretChatProfilePhotoHandler(request: CallableRequest) {
  const userId = requireAuthenticatedUser(request);
  const profileRef = secretChatProfiles.doc(userId);
  const before = await profileRef.get();
  if (!before.exists) {
    throw new HttpsError("not-found", "The Secret Chat profile was not found.");
  }
  await profileRef.set({
    photoUrl: FieldValue.delete(),
    photoPath: FieldValue.delete(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  const previousPath = before.data()?.photoPath;
  if (typeof previousPath === "string") {
    await getStorage().bucket().file(previousPath).delete({ignoreNotFound: true}).catch(() => undefined);
  }
  return {profile: callableProfile(await profileRef.get())};
}

export const removeSecretChatProfilePhoto = onCall({enforceAppCheck: true}, removeSecretChatProfilePhotoHandler);
export const removeSecretChatProfilePhotoDev = onCall({enforceAppCheck: false}, removeSecretChatProfilePhotoHandler);

async function deleteSecretChatPostHandler(request: CallableRequest) {
  const userId = requireAuthenticatedUser(request);
  const postId = typeof request.data?.postId === "string" ? request.data.postId.trim() : "";
  if (!postId || postId.length > 150 || postId.includes("/")) {
    throw new HttpsError("invalid-argument", "The Secret Chat post ID is invalid.");
  }

  const postRef = posts.doc(postId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(postRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "This Secret Chat post no longer exists.");
    }
    if (snapshot.data()?.authorId !== userId) {
      throw new HttpsError("permission-denied", "Only the post owner can delete it.");
    }
    transaction.update(postRef, {
      moderationStatus: "deleting",
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  const [commentsSnapshot, interactionsSnapshot] = await Promise.all([
    db.collection("secret_chat_comments").where("postId", "==", postId).get(),
    db.collection("secret_chat_interactions").where("postId", "==", postId).get(),
  ]);
  await postRef.delete();
  const writer = db.bulkWriter();
  for (const document of commentsSnapshot.docs) writer.delete(document.ref);
  for (const document of interactionsSnapshot.docs) writer.delete(document.ref);
  await writer.close();
  return {deleted: true, postId};
}

export const deleteSecretChatPost = onCall({enforceAppCheck: true}, deleteSecretChatPostHandler);
export const deleteSecretChatPostDev = onCall({enforceAppCheck: false}, deleteSecretChatPostHandler);

function manilaDateKey(date: Date): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Manila",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

async function requireStaff(uid: string): Promise<FirebaseFirestore.DocumentData> {
  const user = await db.collection("users").doc(uid).get();
  const legacyRole = String(user.data()?.role ?? "").toLowerCase();
  const accessRole = String(user.data()?.accessRole ??
    (legacyRole === "admin" || legacyRole === "counselor" ? legacyRole : "appUser"));
  if (!["portalStaff", "counselor", "admin"].includes(accessRole)) {
    throw new HttpsError("permission-denied", "Staff access is required.");
  }
  if (accessRole !== "admin" && user.data()?.staffAccountStatus !== "approved") {
    throw new HttpsError("permission-denied", "This staff account is not approved.");
  }
  if (accessRole === "admin" && await configuredSuperAdminUid() !== uid) {
    throw new HttpsError("permission-denied", "Administrator access is not configured for this account.");
  }
  return {...(user.data() ?? {}), accessRole};
}

async function configuredSuperAdminUid(): Promise<string> {
  const security = await db.collection("system_config").doc("security").get();
  const value = superAdminUidFromSecurity(security.data());
  if (!value) {
    throw new HttpsError(
      "failed-precondition",
      "The super-administrator security record is not configured.",
    );
  }
  return value;
}

async function requireSuperAdmin(uid: string): Promise<FirebaseFirestore.DocumentData> {
  if (uid !== await configuredSuperAdminUid()) {
    throw new HttpsError("permission-denied", "Super-administrator access is required.");
  }
  const actor = await requireStaff(uid);
  if (actor.accessRole !== "admin") {
    throw new HttpsError("permission-denied", "The configured account is not an administrator.");
  }
  return actor;
}

function normalizedEmployeeId(value: unknown): string {
  const employeeId = requiredText(value, "Employee ID", 3, 40).toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (employeeId.length < 3) throw new HttpsError("invalid-argument", "Enter a valid employee ID.");
  return employeeId;
}

const STAFF_ACCESS_ROLES = ["portalStaff", "counselor"] as const;
const STAFF_ACCOUNT_STATUSES = ["pending", "approved", "rejected", "disabled"] as const;
const BUNDLED_STAFF_DEPARTMENTS = [
  "Administration", "Registrar", "Finance", "Library", "Guidance/PACC",
  "Health Services", "IT/MIS", "Maintenance/Facilities", "Security", "Other",
] as const;

async function registerStaffAccountHandler(request: CallableRequest) {
  const userId = requireAuthenticatedUser(request);
  const authUser = await getAuth().getUser(userId);
  const email = String(authUser.email ?? "").trim().toLowerCase();
  if (!email) throw new HttpsError("failed-precondition", "An email address is required.");
  const employeeId = requiredText(request.data?.employeeId, "Employee ID", 3, 40);
  const employeeIdKey = normalizedEmployeeId(employeeId);
  const firstName = requiredText(request.data?.firstName, "First name", 1, 80);
  const lastName = requiredText(request.data?.lastName, "Last name", 1, 80);
  const position = requiredText(request.data?.position, "Position", 2, 100);
  const department = requiredText(request.data?.department, "Department", 2, 120);
  const departmentId = typeof request.data?.departmentId === "string" ? request.data.departmentId.trim() : "";
  if (!departmentId && !BUNDLED_STAFF_DEPARTMENTS.includes(
    department as typeof BUNDLED_STAFF_DEPARTMENTS[number],
  )) {
    throw new HttpsError("invalid-argument", "Choose a valid staff department.");
  }
  const collegeId = typeof request.data?.collegeId === "string" ? request.data.collegeId.trim() : "";
  const courseId = typeof request.data?.courseId === "string" ? request.data.courseId.trim() : "";
  const userRef = db.collection("users").doc(userId);
  const reservationRef = db.collection("employee_id_reservations").doc(employeeIdKey);

  await db.runTransaction(async (transaction) => {
    const [existing, reservation] = await Promise.all([
      transaction.get(userRef), transaction.get(reservationRef),
    ]);
    if (existing.exists) throw new HttpsError("already-exists", "An account profile already exists.");
    if (reservation.exists && reservation.data()?.userId !== userId) {
      throw new HttpsError("already-exists", "That employee ID is already registered.");
    }
    if (departmentId) {
      const canonicalDepartment = await transaction.get(db.collection("departments").doc(departmentId));
      if (!canonicalDepartment.exists || canonicalDepartment.data()?.active !== true) {
        throw new HttpsError("failed-precondition", "Choose an active department.");
      }
    }
    if (courseId) {
      const course = await transaction.get(db.collection("courses").doc(courseId));
      if (!course.exists || course.data()?.active !== true || course.data()?.collegeId !== collegeId) {
        throw new HttpsError("failed-precondition", "Choose a course belonging to the selected college.");
      }
    }
    transaction.create(reservationRef, {userId, employeeId, createdAt: FieldValue.serverTimestamp()});
    transaction.create(userRef, {
      id: userId, email, firstName, lastName, name: `${firstName} ${lastName}`,
      employeeId, employeeIdKey, position, department, departmentId, collegeId, courseId,
      populationRole: "nonTeaching", declaredRole: "nonTeaching", role: "staff",
      accessRole: "appUser", staffAccountStatus: "pending",
      profileVersion: 3, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return {ok: true};
}

export const registerStaffAccount = onCall({enforceAppCheck: true}, registerStaffAccountHandler);
export const registerStaffAccountDev = onCall({enforceAppCheck: false}, registerStaffAccountHandler);

async function reviewStaffRegistrationHandler(request: CallableRequest) {
  const actorId = requireAuthenticatedUser(request);
  const actor = await requireSuperAdmin(actorId);
  const targetUserId = requiredText(request.data?.userId, "User ID", 1, 128);
  const approve = request.data?.approve === true;
  const accessRole = String(request.data?.accessRole ?? "portalStaff");
  const reason = requiredText(request.data?.reason, "Reason", 3, 500);
  if (targetUserId === actorId) throw new HttpsError("permission-denied", "You cannot review yourself.");
  if (approve && !STAFF_ACCESS_ROLES.includes(accessRole as typeof STAFF_ACCESS_ROLES[number])) {
    throw new HttpsError("invalid-argument", "Choose Portal Staff or Counselor.");
  }
  const target = db.collection("users").doc(targetUserId);
  const audit = db.collection("admin_audit_logs").doc();
  await db.runTransaction(async (transaction) => {
    const before = await transaction.get(target);
    if (!before.exists || before.data()?.staffAccountStatus !== "pending") {
      throw new HttpsError("failed-precondition", "This registration is no longer pending.");
    }
    const status = approve ? "approved" : "rejected";
    transaction.update(target, {staffAccountStatus: status, accessRole: approve ? accessRole : "appUser",
      verifiedBy: actorId,
      verifiedAt: approve ? FieldValue.serverTimestamp() : null, updatedAt: FieldValue.serverTimestamp()});
    transaction.create(audit, {actorId, actorAccessRole: actor.accessRole, targetUserId,
      action: approve ? "staffRegistrationApproved" : "staffRegistrationRejected", reason,
      before: {staffAccountStatus: "pending", accessRole: "appUser"},
      after: {staffAccountStatus: status, accessRole: approve ? accessRole : "appUser"},
      createdAt: FieldValue.serverTimestamp()});
  });
  if (!approve) await getAuth().revokeRefreshTokens(targetUserId);
  return {ok: true};
}

export const reviewStaffRegistration = onCall({enforceAppCheck: true}, reviewStaffRegistrationHandler);
export const reviewStaffRegistrationDev = onCall({enforceAppCheck: false}, reviewStaffRegistrationHandler);

async function setStaffAccountEnabledHandler(request: CallableRequest) {
  const actorId = requireAuthenticatedUser(request);
  const actor = await requireSuperAdmin(actorId);
  const targetUserId = requiredText(request.data?.userId, "User ID", 1, 128);
  const enabled = request.data?.enabled === true;
  const reason = requiredText(request.data?.reason, "Reason", 3, 500);
  if (targetUserId === actorId || targetUserId === await configuredSuperAdminUid()) {
    throw new HttpsError("permission-denied", "The super-administrator cannot be modified.");
  }
  const target = db.collection("users").doc(targetUserId);
  const audit = db.collection("admin_audit_logs").doc();
  await db.runTransaction(async (transaction) => {
    const before = await transaction.get(target);
    if (!before.exists) throw new HttpsError("not-found", "Staff profile not found.");
    const previous = String(before.data()?.staffAccountStatus ?? "pending");
    if (!STAFF_ACCOUNT_STATUSES.includes(previous as typeof STAFF_ACCOUNT_STATUSES[number])) {
      throw new HttpsError("failed-precondition", "This is not a staff account.");
    }
    const status = enabled ? "approved" : "disabled";
    transaction.update(target, {staffAccountStatus: status, accessRole: enabled ? before.data()?.previousAccessRole ?? "portalStaff" : "appUser",
      previousAccessRole: enabled ? FieldValue.delete() : before.data()?.accessRole ?? "portalStaff", updatedAt: FieldValue.serverTimestamp()});
    transaction.create(audit, {actorId, actorAccessRole: actor.accessRole, targetUserId,
      action: enabled ? "staffAccountEnabled" : "staffAccountDisabled", reason,
      before: {staffAccountStatus: previous, accessRole: before.data()?.accessRole},
      after: {staffAccountStatus: status}, createdAt: FieldValue.serverTimestamp()});
  });
  await getAuth().updateUser(targetUserId, {disabled: !enabled});
  if (!enabled) await getAuth().revokeRefreshTokens(targetUserId);
  return {ok: true};
}

export const setStaffAccountEnabled = onCall({enforceAppCheck: true}, setStaffAccountEnabledHandler);
export const setStaffAccountEnabledDev = onCall({enforceAppCheck: false}, setStaffAccountEnabledHandler);

const ACCESS_ROLES = ["appUser", "portalStaff", "counselor", "admin"] as const;
export type AccessRoleValue = typeof ACCESS_ROLES[number];
export const canAccessClinicalData = (role: string): boolean =>
  role === "counselor" || role === "admin";
export const canManageAccess = (role: string): boolean => role === "admin";

function requiredText(value: unknown, label: string, min: number, max: number): string {
  const text = typeof value === "string" ? value.trim() : "";
  if (text.length < min || text.length > max) {
    throw new HttpsError("invalid-argument", `${label} must be ${min}-${max} characters.`);
  }
  return text;
}

export function newPublicUserId(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = randomBytes(6);
  return `USR-${Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("")}`;
}

export type InactiveAppUserDecision =
  "eligible" | "active" | "missing-activity" | "protected-account";

export function inactiveAppUserDecision(
  data: FirebaseFirestore.DocumentData,
  cutoff: Timestamp,
): InactiveAppUserDecision {
  if (data.accessRole !== "appUser" || data.staffAccountStatus != null) {
    return "protected-account";
  }
  const activity = data.lastActiveAt instanceof Timestamp ? data.lastActiveAt :
    data.createdAt instanceof Timestamp ? data.createdAt : null;
  if (!activity) return "missing-activity";
  return activity.toMillis() <= cutoff.toMillis() ? "eligible" : "active";
}

function inactiveCutoff(): Timestamp {
  return Timestamp.fromMillis(Date.now() - INACTIVE_ACCOUNT_MS);
}

async function ensurePublicUserId(userId: string): Promise<string> {
  const mappingRef = publicUserIds.doc(userId);
  const existing = await mappingRef.get();
  if (existing.exists) return String(existing.data()?.publicUserId ?? "");
  for (let attempt = 0; attempt < 12; attempt++) {
    const publicUserId = newPublicUserId();
    const reservationRef = publicUserIdReservations.doc(publicUserId);
    try {
      await db.runTransaction(async (transaction) => {
        const [mapping, reservation] = await Promise.all([
          transaction.get(mappingRef), transaction.get(reservationRef),
        ]);
        if (mapping.exists) return;
        if (reservation.exists) throw new Error("PUBLIC_ID_COLLISION");
        transaction.create(reservationRef, {userId, createdAt: FieldValue.serverTimestamp()});
        transaction.create(mappingRef, {publicUserId, createdAt: FieldValue.serverTimestamp()});
      });
      const saved = await mappingRef.get();
      if (saved.exists) return String(saved.data()?.publicUserId ?? publicUserId);
    } catch (error) {
      if (!(error instanceof Error) || error.message !== "PUBLIC_ID_COLLISION") throw error;
    }
  }
  throw new HttpsError("resource-exhausted", "Unable to allocate a public user ID.");
}

export const assignPublicIdOnUserCreate = onDocumentCreated("users/{userId}", async (event) => {
  const data = event.data?.data();
  if (!data || data.staffAccountStatus != null || data.accessRole !== "appUser") return;
  await ensurePublicUserId(event.params.userId);
});

async function backfillPublicAppUserIdsHandler(request: CallableRequest) {
  const actorId = requireAuthenticatedUser(request);
  await requireSuperAdmin(actorId);
  const snapshots = await db.collection("users").get();
  const appUsers = snapshots.docs.filter((doc) => {
    const data = doc.data();
    return data.staffAccountStatus == null && data.accessRole === "appUser";
  });
  await Promise.all(appUsers.map((doc) => ensurePublicUserId(doc.id)));
  return {ok: true, processed: appUsers.length};
}

export const backfillPublicAppUserIds = onCall({enforceAppCheck: true}, backfillPublicAppUserIdsHandler);
export const backfillPublicAppUserIdsDev = onCall({enforceAppCheck: false}, backfillPublicAppUserIdsHandler);

type CleanupCandidate = {
  uid: string;
  publicUserId: string;
};

async function inactiveCleanupCandidates(cutoff: Timestamp): Promise<{
  candidates: CleanupCandidate[];
  skippedMissingActivity: number;
}> {
  const snapshot = await db.collection("users").get();
  const superAdminId = await configuredSuperAdminUid();
  const candidates: CleanupCandidate[] = [];
  let skippedMissingActivity = 0;
  for (const document of snapshot.docs) {
    const decision = inactiveAppUserDecision(document.data(), cutoff);
    if (decision === "missing-activity") skippedMissingActivity++;
    if (decision !== "eligible" || document.id === superAdminId) continue;
    candidates.push({
      uid: document.id,
      publicUserId: await ensurePublicUserId(document.id),
    });
  }
  return {candidates, skippedMissingActivity};
}

async function previewInactiveAppUserDeletionHandler(request: CallableRequest) {
  const actorId = requireAuthenticatedUser(request);
  await requireSuperAdmin(actorId);
  const cutoff = inactiveCutoff();
  const result = await inactiveCleanupCandidates(cutoff);
  return {
    cutoff: cutoff.toDate().toISOString(),
    inactiveDays: INACTIVE_ACCOUNT_DAYS,
    eligibleCount: result.candidates.length,
    skippedMissingActivity: result.skippedMissingActivity,
    publicUserIds: result.candidates.map((candidate) => candidate.publicUserId).sort(),
  };
}

export const previewInactiveAppUserDeletion = onCall({enforceAppCheck: true}, previewInactiveAppUserDeletionHandler);
export const previewInactiveAppUserDeletionDev = onCall({enforceAppCheck: false}, previewInactiveAppUserDeletionHandler);

async function deleteQuery(query: FirebaseFirestore.Query): Promise<number> {
  const snapshot = await query.get();
  if (snapshot.empty) return 0;
  const writer = db.bulkWriter();
  for (const document of snapshot.docs) writer.delete(document.ref);
  await writer.close();
  return snapshot.size;
}

async function deleteUserFieldDocuments(
  uid: string,
  collections: readonly string[],
): Promise<number> {
  let deleted = 0;
  for (const collection of collections) {
    deleted += await deleteQuery(db.collection(collection).where("userId", "==", uid));
  }
  return deleted;
}

async function deleteTargetAuditDocuments(uid: string): Promise<number> {
  let deleted = 0;
  for (const collection of ["admin_audit_logs", "role_audit_logs"]) {
    deleted += await deleteQuery(db.collection(collection).where("targetUserId", "==", uid));
  }
  return deleted;
}

async function deleteAddressedMail(addresses: string[]): Promise<number> {
  let deleted = 0;
  for (const address of new Set(addresses.map((value) => value.trim().toLowerCase()).filter(Boolean))) {
    deleted += await deleteQuery(db.collection("mail").where("to", "array-contains", address));
  }
  return deleted;
}

async function deleteSecretChatData(uid: string): Promise<number> {
  let deleted = 0;
  const postsSnapshot = await posts.where("authorId", "==", uid).get();
  for (const post of postsSnapshot.docs) {
    deleted += await deleteQuery(db.collection("secret_chat_comments").where("postId", "==", post.id));
    deleted += await deleteQuery(db.collection("secret_chat_interactions").where("postId", "==", post.id));
    await post.ref.delete();
    deleted++;
  }
  deleted += await deleteQuery(db.collection("secret_chat_comments").where("authorId", "==", uid));
  deleted += await deleteQuery(db.collection("secret_chat_interactions").where("userId", "==", uid));
  deleted += await deleteQuery(secretChatAliases.where("userId", "==", uid));
  return deleted;
}

async function recursivelyDeleteUserParents(uid: string): Promise<number> {
  let deleted = 0;
  const appointments = await db.collection("appointments").where("userId", "==", uid).get();
  for (const appointment of appointments.docs) {
    await db.recursiveDelete(appointment.ref);
    deleted++;
  }
  const devices = db.collection("user_devices").doc(uid);
  await db.recursiveDelete(devices);
  deleted++;
  return deleted;
}

const USER_FIELD_COLLECTIONS = [
  "assessments", "assessment_limits", "moods", "reports",
  // The feature is removed; retain deletion-only handling for historical data.
  "journals",
  "user_activities", "breathing_sessions", "mind_aid_messages", "mind_aid_feedback",
  "sleep_entries", "notifications", "inquiries", "role_correction_requests",
  "recovery_email_tokens", "password_recovery_tokens", "_analytics_events",
  "_mind_aid_events",
] as const;

async function cleanUserAccount(uid: string, publicUserId: string): Promise<number> {
  const profileRef = db.collection("users").doc(uid);
  const [profile, privateProfile, authUser] = await Promise.all([
    profileRef.get(),
    db.collection("user_private").doc(uid).get(),
    getAuth().getUser(uid).catch((error: {code?: string}) => {
      if (error.code === "auth/user-not-found") return null;
      throw error;
    }),
  ]);
  const emailAddresses = [
    String(authUser?.email ?? ""),
    String(profile.data()?.email ?? ""),
    String(privateProfile.data()?.recoveryEmail ?? ""),
    String(privateProfile.data()?.recoveryEmailPending ?? ""),
  ];

  if (authUser) await getAuth().deleteUser(uid);
  await profileRef.delete();

  let deleted = 1;
  deleted += await recursivelyDeleteUserParents(uid);
  deleted += await deleteUserFieldDocuments(uid, USER_FIELD_COLLECTIONS);
  deleted += await deleteTargetAuditDocuments(uid);
  deleted += await deleteSecretChatData(uid);
  deleted += await deleteAddressedMail(emailAddresses);
  deleted += await deleteQuery(db.collectionGroup("users").where("userId", "==", uid));

  const directRefs = [
    db.collection("user_private").doc(uid),
    db.collection("_password_recovery_limits").doc(uid),
    db.collection("assessment_limits").doc(uid),
    db.collection("admin_status_summaries").doc(uid),
    db.collection("sleep_preferences").doc(uid),
    db.collection("mind_aid_preferences").doc(uid),
    db.collection("_mind_aid_rate_limits").doc(uid),
    secretChatProfiles.doc(uid),
    stats.doc(uid),
    publicUserIds.doc(uid),
    publicUserIdReservations.doc(publicUserId),
  ];
  const writer = db.bulkWriter();
  for (const ref of directRefs) writer.delete(ref);
  await writer.close();
  deleted += directRefs.length;

  await getStorage().bucket().deleteFiles({
    prefix: `secret_chat_profiles/${uid}/`,
    force: true,
  });

  // A second sweep catches writes that raced with the first pass. The deleted
  // Auth account/profile prevents new legitimate writes for this UID.
  deleted += await deleteUserFieldDocuments(uid, USER_FIELD_COLLECTIONS);
  deleted += await deleteSecretChatData(uid);
  await profileRef.delete();
  return deleted;
}

async function deleteInactiveAppUsersHandler(request: CallableRequest) {
  const actorId = requireAuthenticatedUser(request);
  const actor = await requireSuperAdmin(actorId);
  const superAdminId = await configuredSuperAdminUid();
  if (request.data?.confirmation !== "DELETE") {
    throw new HttpsError("invalid-argument", "Type DELETE to confirm permanent account removal.");
  }
  const cutoff = inactiveCutoff();
  const preview = await inactiveCleanupCandidates(cutoff);
  const runId = randomUUID();

  for (const candidate of preview.candidates) {
    await db.runTransaction(async (transaction) => {
      const profile = await transaction.get(db.collection("users").doc(candidate.uid));
      if (!profile.exists || candidate.uid === superAdminId ||
          inactiveAppUserDecision(profile.data()!, cutoff) !== "eligible") return;
      transaction.set(accountDeletionJobs.doc(candidate.uid), {
        uid: candidate.uid,
        publicUserId: candidate.publicUserId,
        runId,
        status: "pending",
        cutoff,
        createdAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  }

  const jobs = await accountDeletionJobs.get();
  const deletedPublicUserIds: string[] = [];
  const failedPublicUserIds: string[] = [];
  let deletedDocumentCount = 0;
  for (const job of jobs.docs) {
    const uid = job.id;
    const publicUserId = String(job.data().publicUserId ?? "Unknown");
    try {
      let claimed = false;
      await db.runTransaction(async (transaction) => {
        claimed = false;
        const [currentJob, currentProfile] = await Promise.all([
          transaction.get(job.ref),
          transaction.get(db.collection("users").doc(uid)),
        ]);
        if (!currentJob.exists) return;
        const status = String(currentJob.data()?.status ?? "pending");
        const lease = currentJob.data()?.leaseExpiresAt;
        if (status === "processing" && lease instanceof Timestamp && lease.toMillis() > Date.now()) return;
        if (currentProfile.exists && (uid === superAdminId ||
            inactiveAppUserDecision(currentProfile.data()!, cutoff) !== "eligible")) {
          transaction.delete(job.ref);
          return;
        }
        claimed = true;
        transaction.set(job.ref, {
          status: "processing",
          attempts: FieldValue.increment(1),
          leaseExpiresAt: Timestamp.fromMillis(Date.now() + 30 * 60 * 1000),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
      if (!claimed) continue;
      deletedDocumentCount += await cleanUserAccount(uid, publicUserId);
      await job.ref.delete();
      deletedPublicUserIds.push(publicUserId);
    } catch (error) {
      console.error("inactive_account_cleanup_failed", {runId, publicUserId, error});
      await job.ref.set({
        status: "failed",
        lastError: error instanceof Error ? error.message.slice(0, 300) : "Unknown cleanup error",
        leaseExpiresAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      failedPublicUserIds.push(publicUserId);
    }
  }

  await db.collection("admin_audit_logs").add({
    actorId,
    actorAccessRole: actor.accessRole,
    targetUserId: "",
    action: "inactiveAppUsersDeleted",
    reason: `Debug cleanup of accounts inactive for ${INACTIVE_ACCOUNT_DAYS} days`,
    runId,
    cutoff,
    deletedCount: deletedPublicUserIds.length,
    failureCount: failedPublicUserIds.length,
    skippedMissingActivity: preview.skippedMissingActivity,
    createdAt: FieldValue.serverTimestamp(),
  });
  return {
    runId,
    cutoff: cutoff.toDate().toISOString(),
    deletedCount: deletedPublicUserIds.length,
    failedCount: failedPublicUserIds.length,
    skippedMissingActivity: preview.skippedMissingActivity,
    deletedDocumentCount,
    deletedPublicUserIds: deletedPublicUserIds.sort(),
    failedPublicUserIds: failedPublicUserIds.sort(),
  };
}

export const deleteInactiveAppUsers = onCall({...{timeoutSeconds: 3600, memory: "1GiB"}, enforceAppCheck: true}, deleteInactiveAppUsersHandler);
export const deleteInactiveAppUsersDev = onCall({...{timeoutSeconds: 3600, memory: "1GiB"}, enforceAppCheck: false}, deleteInactiveAppUsersHandler);

async function confirmSuperAdminHandler(request: CallableRequest) {
  const correlationId = randomUUID();
  try {
    const actorId = requireAuthenticatedUser(request);
    await requireSuperAdmin(actorId);
    return {isSuperAdmin: true, correlationId};
  } catch (error) {
    if (error instanceof HttpsError) {
      const details = error.details && typeof error.details === "object" ?
        error.details as Record<string, unknown> : {};
      throw new HttpsError(error.code, error.message, {...details, correlationId});
    }
    console.error("super_admin_confirmation_failed", {correlationId});
    throw new HttpsError(
      "internal",
      "Unable to confirm super-administrator access.",
      {correlationId},
    );
  }
}

export const confirmSuperAdmin = onCall({enforceAppCheck: true}, confirmSuperAdminHandler);
export const confirmSuperAdminDev = onCall({enforceAppCheck: false}, confirmSuperAdminHandler);

async function completeAdminPasswordChangeHandler(request: CallableRequest) {
  const actorId = requireAuthenticatedUser(request);
  const actor = await requireSuperAdmin(actorId);
  const target = db.collection("users").doc(actorId);
  const audit = db.collection("admin_audit_logs").doc();
  await db.runTransaction(async (transaction) => {
    const profile = await transaction.get(target);
    if (!profile.exists) throw new HttpsError("not-found", "Administrator profile not found.");
    transaction.update(target, {mustChangePassword: false, passwordChangedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
    transaction.create(audit, {actorId, actorAccessRole: actor.accessRole, targetUserId: actorId,
      action: "initialAdminPasswordChanged", reason: "Mandatory initial password change completed",
      before: {mustChangePassword: profile.data()?.mustChangePassword === true},
      after: {mustChangePassword: false}, createdAt: FieldValue.serverTimestamp()});
  });
  return {ok: true};
}

export const completeAdminPasswordChange = onCall({enforceAppCheck: true}, completeAdminPasswordChangeHandler);
export const completeAdminPasswordChangeDev = onCall({enforceAppCheck: false}, completeAdminPasswordChangeHandler);

async function assignAccessRoleHandler(request: CallableRequest) {
  const actorId = requireAuthenticatedUser(request);
  const actor = await requireSuperAdmin(actorId);
  const targetUserId = requiredText(request.data?.userId, "User ID", 1, 128);
  const accessRole = String(request.data?.accessRole ?? "");
  const reason = requiredText(request.data?.reason, "Reason", 3, 500);
  if (![...STAFF_ACCESS_ROLES, "appUser"].includes(accessRole as "portalStaff" | "counselor" | "appUser")) {
    throw new HttpsError("invalid-argument", "Choose Portal Staff, Counselor, or revoke access.");
  }
  if (targetUserId === actorId || targetUserId === await configuredSuperAdminUid()) {
    throw new HttpsError("permission-denied", "The super-administrator cannot be modified.");
  }
  const target = db.collection("users").doc(targetUserId);
  const audit = db.collection("role_audit_logs").doc();
  await db.runTransaction(async (transaction) => {
    const before = await transaction.get(target);
    if (!before.exists) throw new HttpsError("not-found", "User profile not found.");
    transaction.update(target, {accessRole, profileVersion: 2, updatedAt: FieldValue.serverTimestamp()});
    transaction.create(audit, {
      targetUserId,
      actorId,
      actorAccessRole: actor.accessRole,
      action: "accessRoleAssigned",
      reason,
      before: {accessRole: before.data()?.accessRole ?? "appUser"},
      after: {accessRole},
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return {ok: true};
}

export const assignAccessRole = onCall({enforceAppCheck: true}, assignAccessRoleHandler);
export const assignAccessRoleDev = onCall({enforceAppCheck: false}, assignAccessRoleHandler);

async function saveOrganizationRecordHandler(request: CallableRequest) {
  const actorId = requireAuthenticatedUser(request);
  await requireSuperAdmin(actorId);
  const kind = String(request.data?.kind ?? "");
  const collection = ({college: "colleges", department: "departments", course: "courses"} as const)[kind as "college" | "department" | "course"];
  if (!collection) throw new HttpsError("invalid-argument", "Choose a valid directory type.");
  const recordId = typeof request.data?.id === "string" && request.data.id.trim() ? request.data.id.trim() : db.collection(collection).doc().id;
  const name = requiredText(request.data?.name, "Name", 2, 120);
  const code = requiredText(request.data?.code, "Code", 1, 30).toUpperCase();
  const active = request.data?.active !== false;
  const collegeId = kind === "course" ? requiredText(request.data?.collegeId, "College", 1, 128) : "";
  if (kind === "course") {
    const college = await db.collection("colleges").doc(collegeId).get();
    if (!college.exists || college.data()?.active !== true) {
      throw new HttpsError("failed-precondition", "Choose an active college.");
    }
  }
  const duplicate = await db.collection(collection).where("normalizedName", "==", name.toLowerCase()).limit(1).get();
  if (duplicate.docs.some((doc) => doc.id !== recordId)) {
    throw new HttpsError("already-exists", `A ${kind} with that name already exists.`);
  }
  await db.collection(collection).doc(recordId).set({name, code, normalizedName: name.toLowerCase(), active,
    ...(kind === "course" ? {collegeId} : {}), updatedBy: actorId, updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp()}, {merge: true});
  return {ok: true, id: recordId};
}

export const saveOrganizationRecord = onCall({enforceAppCheck: true}, saveOrganizationRecordHandler);
export const saveOrganizationRecordDev = onCall({enforceAppCheck: false}, saveOrganizationRecordHandler);

async function updateStaffOrganizationHandler(request: CallableRequest) {
  const actorId = requireAuthenticatedUser(request);
  const actor = await requireSuperAdmin(actorId);
  const targetUserId = requiredText(request.data?.userId, "User ID", 1, 128);
  const departmentId = requiredText(request.data?.departmentId, "Department", 1, 128);
  const collegeId = typeof request.data?.collegeId === "string" ? request.data.collegeId.trim() : "";
  const courseId = typeof request.data?.courseId === "string" ? request.data.courseId.trim() : "";
  const reason = requiredText(request.data?.reason, "Reason", 3, 500);
  const [department, course, target] = await Promise.all([
    db.collection("departments").doc(departmentId).get(),
    courseId ? db.collection("courses").doc(courseId).get() : Promise.resolve(null),
    db.collection("users").doc(targetUserId).get(),
  ]);
  if (!target.exists || !("staffAccountStatus" in (target.data() ?? {}))) throw new HttpsError("failed-precondition", "Only staff accounts can be updated.");
  if (!department.exists || department.data()?.active !== true) throw new HttpsError("failed-precondition", "Choose an active department.");
  if (course && (!course.exists || course.data()?.active !== true || course.data()?.collegeId !== collegeId)) {
    throw new HttpsError("failed-precondition", "Choose a course belonging to the selected college.");
  }
  await db.runTransaction(async (transaction) => {
    transaction.update(target.ref, {departmentId, collegeId, courseId, updatedAt: FieldValue.serverTimestamp()});
    transaction.create(db.collection("admin_audit_logs").doc(), {actorId, actorAccessRole: actor.accessRole,
      targetUserId, action: "staffOrganizationUpdated", reason,
      before: {departmentId: target.data()?.departmentId ?? "", collegeId: target.data()?.collegeId ?? "", courseId: target.data()?.courseId ?? ""},
      after: {departmentId, collegeId, courseId}, createdAt: FieldValue.serverTimestamp()});
  });
  return {ok: true};
}

export const updateStaffOrganization = onCall({enforceAppCheck: true}, updateStaffOrganizationHandler);
export const updateStaffOrganizationDev = onCall({enforceAppCheck: false}, updateStaffOrganizationHandler);

export function reactionDelta(before: unknown, after: unknown): number {
  return Number(after === true) - Number(before === true);
}

export function activeCommentDelta(before: unknown, after: unknown): number {
  return Number(after === "active") - Number(before === "active");
}

async function rebuildMySecretChatStatsHandler(request: CallableRequest) {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError("unauthenticated", "Sign in is required.");
  const statsRef = stats.doc(userId);
  if ((await statsRef.get()).exists) return {rebuilt: false};
  const snapshot = await posts.where("authorId", "==", userId).get();
  const totals = snapshot.docs.reduce((value, document) => {
    const post = document.data();
    value.reads += Number(post.readCount ?? 0);
    value.reactions += Number(post.likeCount ?? 0);
    value.comments += Number(post.commentCount ?? 0);
    return value;
  }, {reads: 0, reactions: 0, comments: 0});
  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(statsRef)).exists) return;
    transaction.create(statsRef, {
      userId,
      ...totals,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return {rebuilt: true};
}

export const rebuildMySecretChatStats = onCall({enforceAppCheck: true}, rebuildMySecretChatStatsHandler);
export const rebuildMySecretChatStatsDev = onCall({enforceAppCheck: false}, rebuildMySecretChatStatsHandler);

async function once(eventId: string, apply: (
  transaction: FirebaseFirestore.Transaction,
  marker: FirebaseFirestore.DocumentReference,
) => Promise<void>): Promise<void> {
  const marker = events.doc(eventId);
  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(marker)).exists) return;
    await apply(transaction, marker);
    transaction.create(marker, {processedAt: FieldValue.serverTimestamp()});
  });
}

export const syncSecretChatInteraction = onDocumentWritten(
  {document: "secret_chat_interactions/{interactionId}", retry: true},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const postId = String(after?.postId ?? before?.postId ?? "");
    if (!postId) return;
    const reactionChange = reactionDelta(before?.liked, after?.liked);
    const firstRead = !(before?.readAt instanceof Timestamp) && after?.readAt instanceof Timestamp;
    if (reactionChange === 0 && !firstRead) return;

    await once(`interaction_${event.id}`, async (transaction, marker) => {
      const postRef = posts.doc(postId);
      const postSnapshot = await transaction.get(postRef);
      if (!postSnapshot.exists) return;
      const post = postSnapshot.data()!;
      const authorId = String(post.authorId ?? "");
      if (!authorId) return;
      if (!(await transaction.get(db.collection("users").doc(authorId))).exists) return;
      const statsRef = stats.doc(authorId);
      await transaction.get(statsRef);
      const readerId = String(after?.userId ?? "");
      const readDelta = firstRead && readerId !== authorId ? 1 : 0;
      transaction.set(postRef, {
        likeCount: FieldValue.increment(reactionChange),
        readCount: FieldValue.increment(readDelta),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(statsRef, {
        userId: authorId,
        reactions: FieldValue.increment(reactionChange),
        reads: FieldValue.increment(readDelta),
        comments: FieldValue.increment(0),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  },
);

export const syncSecretChatComment = onDocumentWritten(
  {document: "secret_chat_comments/{commentId}", retry: true},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const wasActive = before?.moderationStatus === "active";
    const isActive = after?.moderationStatus === "active";
    const delta = activeCommentDelta(
      wasActive ? "active" : undefined,
      isActive ? "active" : undefined,
    );
    const postId = String(after?.postId ?? before?.postId ?? "");
    if (!postId || delta === 0) return;

    await once(`comment_${event.id}`, async (transaction, marker) => {
      const postRef = posts.doc(postId);
      const postSnapshot = await transaction.get(postRef);
      if (!postSnapshot.exists) return;
      const authorId = String(postSnapshot.data()?.authorId ?? "");
      if (!authorId) return;
      if (!(await transaction.get(db.collection("users").doc(authorId))).exists) return;
      const statsRef = stats.doc(authorId);
      await transaction.get(statsRef);
      transaction.set(postRef, {
        commentCount: FieldValue.increment(delta),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(statsRef, {
        userId: authorId,
        comments: FieldValue.increment(delta),
        reactions: FieldValue.increment(0),
        reads: FieldValue.increment(0),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  },
);

export const removeDeletedPostStats = onDocumentDeleted(
  {document: "secret_chats/{postId}", retry: true},
  async (event) => {
    const post = event.data?.data();
    const authorId = String(post?.authorId ?? "");
    if (!authorId) return;
    if (!(await db.collection("users").doc(authorId).get()).exists) return;
    await once(`post_delete_${event.id}`, async (transaction, marker) => {
      const statsRef = stats.doc(authorId);
      await transaction.get(statsRef);
      transaction.set(statsRef, {
        userId: authorId,
        reactions: FieldValue.increment(-Number(post?.likeCount ?? 0)),
        comments: FieldValue.increment(-Number(post?.commentCount ?? 0)),
        reads: FieldValue.increment(-Number(post?.readCount ?? 0)),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  },
);

export const aggregateUserActivity = onDocumentCreated(
  {document: "user_activities/{activityId}", retry: true},
  async (event) => {
    const activity = event.data?.data();
    const userId = String(activity?.userId ?? "");
    const type = String(activity?.type ?? "unknown").replace(/[^A-Za-z0-9_]/g, "_");
    if (!userId) return;
    const profile = await db.collection("users").doc(userId).get();
    const profileData = profile.data();
    // Portal activity is operational data, not app-user engagement.
    if (!profile.exists || profileData?.accessRole !== "appUser" ||
        profileData.staffAccountStatus != null) return;
    // Invalid activity timestamps must not contaminate today's aggregates.
    if (!(activity?.createdAt instanceof Timestamp)) return;
    const occurred = activity.createdAt.toDate();
    const dateKey = manilaDateKey(occurred);
    const marker = analyticsEvents.doc(event.params.activityId);
    const day = db.collection("analytics_daily").doc(dateKey);
    const dailyUser = day.collection("users").doc(userId);

    await db.runTransaction(async (transaction) => {
      if ((await transaction.get(marker)).exists) return;
      const isNewDailyUser = !(await transaction.get(dailyUser)).exists;
      transaction.set(day, {
        dateKey,
        eventCount: FieldValue.increment(1),
        activeUserCount: FieldValue.increment(isNewDailyUser ? 1 : 0),
        [`activityCounts.${type}`]: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(dailyUser, {
        userId,
        lastActivityType: type,
        lastActiveAt: activity.createdAt,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.create(marker, {
        activityId: event.params.activityId,
        userId,
        dateKey,
        processedAt: FieldValue.serverTimestamp(),
      });
    });
    const serviceKey = serviceKeyForActivity(type);
    if (serviceKey) {
      try {
        await recordServiceSuccess(serviceKey);
      } catch (_) {
        // Monitoring is non-blocking and must never affect user activity.
      }
    }
  },
);

/*
 * Historical implementation retained temporarily in source history only.
 * The deployed exports are the App Check-protected implementations in
 * appointment_workflow.ts above. Keeping this block commented ensures it
 * cannot register an unprotected callable while existing dirty work is
 * reconciled in a later cleanup commit.
export type AppointmentLifecycleStatus =
  "pending" | "confirmed" | "ongoing" | "reschedule_proposed" |
  "completed" | "declined" | "cancelled";

const TERMINAL_APPOINTMENT_STATUSES = new Set<AppointmentLifecycleStatus>([
  "completed", "declined", "cancelled",
]);

function legacyCanonicalAppointmentStatus(value: unknown): AppointmentLifecycleStatus {
  const status = String(value ?? "pending").trim().toLowerCase().replace(/[ -]/g, "_");
  if (["pending", "requested"].includes(status)) return "pending";
  if (["confirmed", "upcoming", "scheduled"].includes(status)) return "confirmed";
  if (["ongoing", "in_progress", "inprogress"].includes(status)) return "ongoing";
  if (["reschedule_proposed", "reschedule", "rescheduled"].includes(status)) return "reschedule_proposed";
  if (["completed", "complete", "done"].includes(status)) return "completed";
  if (["declined", "rejected"].includes(status)) return "declined";
  if (["cancelled", "canceled"].includes(status)) return "cancelled";
  return "pending";
}

function legacyCanTransitionAppointment(
  before: AppointmentLifecycleStatus,
  action: AppointmentLifecycleStatus,
): boolean {
  const transitions: Record<AppointmentLifecycleStatus, AppointmentLifecycleStatus[]> = {
    pending: ["confirmed", "declined", "reschedule_proposed"],
    reschedule_proposed: ["confirmed", "declined", "reschedule_proposed"],
    confirmed: ["ongoing", "declined", "reschedule_proposed"],
    ongoing: ["completed"],
    completed: [],
    declined: [],
    cancelled: [],
  };
  return transitions[before].includes(action);
}

const legacyReviewAppointment = onCall(async (request) => {
  const staffId = request.auth?.uid;
  if (!staffId) throw new HttpsError("unauthenticated", "Sign in is required.");
  const staff = await requireStaff(staffId);
  const input = request.data as Record<string, unknown>;
  const appointmentId = String(input.appointmentId ?? "").trim();
  const action = legacyCanonicalAppointmentStatus(input.action);
  const reply = String(input.reply ?? "").trim();
  const proposedMillis = Number(input.proposedScheduledAt ?? 0);
  const proposedTime = String(input.proposedScheduledTime ?? "").trim();
  if (!appointmentId || !["confirmed", "declined", "reschedule_proposed", "ongoing", "completed"].includes(action)) {
    throw new HttpsError("invalid-argument", "A valid appointment action is required.");
  }
  if (!reply) throw new HttpsError("invalid-argument", "A reply to the student is required.");
  if (action === "reschedule_proposed" && (!Number.isFinite(proposedMillis) || proposedMillis <= 0 || !proposedTime)) {
    throw new HttpsError("invalid-argument", "A proposed date and time are required.");
  }

  const appointment = db.collection("appointments").doc(appointmentId);
  const notification = db.collection("notifications").doc();
  const history = appointment.collection("history").doc();
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(appointment);
    if (!current.exists) throw new HttpsError("not-found", "Appointment not found.");
    const data = current.data()!;
    const before = legacyCanonicalAppointmentStatus(data.status);
    if (!legacyCanTransitionAppointment(before, action)) {
      const message = TERMINAL_APPOINTMENT_STATUSES.has(before) ?
        "This appointment is already archived." : "This appointment cannot take that action yet.";
      throw new HttpsError("failed-precondition", message);
    }
    const userId = String(data.userId ?? "");
    if (!userId) throw new HttpsError("failed-precondition", "Appointment has no student.");
    const staffName = String(staff.name ?? staff.email ?? "Counseling staff");
    const patch: Record<string, unknown> = {
      status: action,
      assignedStaffId: staffId,
      counselorName: staffName,
      staffReply: reply,
      reviewedAt: FieldValue.serverTimestamp(),
      ...(action === "ongoing" ? {startedAt: FieldValue.serverTimestamp()} : {}),
      ...(action === "completed" ? {completedAt: FieldValue.serverTimestamp()} : {}),
      updatedAt: FieldValue.serverTimestamp(),
      proposedScheduledAt: action === "reschedule_proposed" ? Timestamp.fromMillis(proposedMillis) : null,
      proposedScheduledTime: action === "reschedule_proposed" ? proposedTime : "",
    };
    transaction.update(appointment, patch);
    transaction.create(history, {
      previousStatus: before,
      status: action,
      reply,
      proposedScheduledAt: patch.proposedScheduledAt ?? null,
      proposedScheduledTime: patch.proposedScheduledTime,
      staffId,
      staffName,
      createdAt: FieldValue.serverTimestamp(),
    });
    const title = action === "confirmed" ? "Appointment confirmed" :
      action === "ongoing" ? "Counseling session started" :
      action === "completed" ? "Counseling session completed" :
      action === "declined" ? "Appointment update" : "New appointment time proposed";
    transaction.create(notification, {
      userId,
      appointmentId,
      type: "appointment",
      title,
      body: reply,
      createdAt: FieldValue.serverTimestamp(),
      readAt: null,
    });
  });
  return {ok: true};
});

const legacyScheduleAppointmentFollowUp = onCall(async (request) => {
  const staffId = requireAuthenticatedUser(request);
  const staff = await requireStaff(staffId);
  const input = request.data as Record<string, unknown>;
  const sourceAppointmentId = String(input.sourceAppointmentId ?? "").trim();
  const scheduledMillis = Number(input.scheduledAt ?? 0);
  const scheduledTime = String(input.scheduledTime ?? "").trim();
  const location = String(input.location ?? "").trim();
  const reply = String(input.reply ?? "").trim();
  if (!sourceAppointmentId || !Number.isFinite(scheduledMillis) || scheduledMillis <= 0 ||
      !scheduledTime || !location || !reply) {
    throw new HttpsError("invalid-argument", "A follow-up date, time, location, and message are required.");
  }

  const source = db.collection("appointments").doc(sourceAppointmentId);
  const followUp = db.collection("appointments").doc();
  const notification = db.collection("notifications").doc();
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(source);
    if (!current.exists) throw new HttpsError("not-found", "Appointment not found.");
    const sourceData = current.data()!;
    if (legacyCanonicalAppointmentStatus(sourceData.status) !== "completed") {
      throw new HttpsError("failed-precondition", "Only a completed appointment can receive a follow-up.");
    }
    const userId = String(sourceData.userId ?? "");
    if (!userId) throw new HttpsError("failed-precondition", "Appointment has no app user.");
    const staffName = String(staff.name ?? staff.email ?? "Counseling staff");
    const rootAppointmentId = String(sourceData.rootAppointmentId ?? sourceAppointmentId);
    const copyFields = ["fullName", "age", "address", "contactNumber", "email", "facebook", "sex",
      "course", "yearLevel", "preferredContactMethod", "therapyBefore", "concern", "bestTime"];
    const followUpData: Record<string, unknown> = {
      userId,
      status: "pending",
      scheduledAt: Timestamp.fromMillis(scheduledMillis),
      scheduledTime,
      location,
      parentAppointmentId: sourceAppointmentId,
      rootAppointmentId,
      assignedStaffId: staffId,
      counselorName: staffName,
      staffReply: reply,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    for (const field of copyFields) if (sourceData[field] !== undefined) followUpData[field] = sourceData[field];
    transaction.create(followUp, followUpData);
    transaction.create(source.collection("history").doc(), {
      previousStatus: "completed",
      status: "follow_up_scheduled",
      linkedAppointmentId: followUp.id,
      reply, staffId, staffName, createdAt: FieldValue.serverTimestamp(),
    });
    transaction.create(followUp.collection("history").doc(), {
      previousStatus: null,
      status: "follow_up_created",
      parentAppointmentId: sourceAppointmentId,
      rootAppointmentId, reply, staffId, staffName, createdAt: FieldValue.serverTimestamp(),
    });
    transaction.create(notification, {
      userId, appointmentId: followUp.id, type: "appointment",
      title: "Follow-up appointment scheduled", body: reply,
      createdAt: FieldValue.serverTimestamp(), readAt: null,
    });
  });
  return {ok: true, appointmentId: followUp.id};
});
*/

export const sendAppointmentNotification = onDocumentCreated(
  {document: "notifications/{notificationId}", retry: true},
  async (event) => {
    const notification = event.data?.data();
    if (notification?.type !== "appointment") return;
    const userId = String(notification.userId ?? "");
    if (!userId) return;
    const tokens = await db.collection("user_devices").doc(userId).collection("tokens").get();
    const values = tokens.docs.map((document) => String(document.data().token ?? "")).filter(Boolean);
    if (!values.length) return;
    const result = await getMessaging().sendEachForMulticast({
      tokens: values,
      notification: {title: String(notification.title ?? "MindMate"), body: String(notification.body ?? "")},
      data: {type: "appointment", appointmentId: String(notification.appointmentId ?? "")},
    });
    const invalid = result.responses
      .map((response, index) => !response.success ? values[index] : "")
      .filter(Boolean);
    await Promise.all(invalid.map((token) => db.collection("user_devices").doc(userId).collection("tokens").doc(token).delete()));
  },
);
