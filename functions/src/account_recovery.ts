import {createHash, randomBytes} from "node:crypto";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";

const db = getFirestore();
const PUBLIC_URL = "https://mindmate-dev-4e91c.web.app";
const GENERIC_RESPONSE = {ok: true, message: "If the account can be recovered, instructions will be sent."};

function token(): string {
  return randomBytes(32).toString("base64url");
}

function hash(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function normalizedEmail(value: unknown): string {
  const email = typeof value === "string" ? value.trim().toLowerCase() : "";
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.endsWith("@mindmate.local")) {
    throw new HttpsError("invalid-argument", "Enter a valid personal recovery email.");
  }
  return email;
}

export function authEmailForSchoolId(value: unknown): string {
  const schoolId = typeof value === "string" ? value.trim().toLowerCase() : "";
  const local = schoolId.replace(/[^a-z0-9]+/g, ".").replace(/\.+/g, ".").replace(/^\.|\.$/g, "");
  if (!local || local.length > 120) throw new HttpsError("invalid-argument", "Enter a valid School ID.");
  return `${local}@mindmate.local`;
}

function password(value: unknown): string {
  const result = typeof value === "string" ? value : "";
  if (result.length < 8 || result.length > 128) {
    throw new HttpsError("invalid-argument", "Password must be 8-128 characters.");
  }
  return result;
}

function mail(to: string, subject: string, html: string): Record<string, unknown> {
  return {to: [to], message: {subject, html}};
}

async function requestRecoveryEmailVerificationHandler(request: CallableRequest) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  const email = normalizedEmail(request.data?.email);
  const rawToken = token();
  const now = Timestamp.now();
  const privateRef = db.collection("user_private").doc(uid);
  const verificationRef = db.collection("recovery_email_tokens").doc(hash(rawToken));
  const mailRef = db.collection("mail").doc();
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(privateRef);
    const lastSent = current.data()?.verificationSentAt;
    if (lastSent instanceof Timestamp && now.toMillis() - lastSent.toMillis() < 60_000) {
      throw new HttpsError("resource-exhausted", "Wait one minute before requesting another email.");
    }
    transaction.set(privateRef, {recoveryEmailPending: email, recoveryEmailVerified: false,
      verificationExpiresAt: Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000),
      verificationSentAt: now, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    transaction.create(verificationRef, {userId: uid, email,
      expiresAt: Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000), state: "active",
      createdAt: FieldValue.serverTimestamp()});
    const link = `${PUBLIC_URL}/#/verify-recovery-email?token=${encodeURIComponent(rawToken)}`;
    transaction.create(mailRef, mail(email, "Verify your MindMate recovery email",
      `<p>Verify this address for MindMate account recovery.</p><p><a href="${link}">Verify recovery email</a></p><p>This link expires in 24 hours.</p>`));
  });
  return {ok: true};
}

export const requestRecoveryEmailVerification = onCall({enforceAppCheck: true}, requestRecoveryEmailVerificationHandler);
export const requestRecoveryEmailVerificationDev = onCall({enforceAppCheck: false}, requestRecoveryEmailVerificationHandler);

async function confirmRecoveryEmailVerificationHandler(request: CallableRequest) {
  const rawToken = typeof request.data?.token === "string" ? request.data.token : "";
  if (rawToken.length < 20 || rawToken.length > 200) throw new HttpsError("invalid-argument", "The verification link is invalid.");
  const tokenRef = db.collection("recovery_email_tokens").doc(hash(rawToken));
  await db.runTransaction(async (transaction) => {
    const tokenSnapshot = await transaction.get(tokenRef);
    const tokenData = tokenSnapshot.data();
    if (!tokenSnapshot.exists || tokenData?.state !== "active" ||
      !(tokenData?.expiresAt instanceof Timestamp) || tokenData.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError("failed-precondition", "The verification link is invalid or expired.");
    }
    const uid = String(tokenData.userId ?? "");
    const email = String(tokenData.email ?? "");
    if (!uid || !email) throw new HttpsError("failed-precondition", "The verification link is invalid.");
    transaction.set(db.collection("user_private").doc(uid), {recoveryEmail: email, recoveryEmailVerified: true,
      recoveryEmailPending: FieldValue.delete(),
      verificationExpiresAt: FieldValue.delete(), verifiedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
    transaction.update(tokenRef, {state: "consumed", consumedAt: FieldValue.serverTimestamp()});
  });
  return {ok: true};
}

export const confirmRecoveryEmailVerification = onCall({enforceAppCheck: true}, confirmRecoveryEmailVerificationHandler);
export const confirmRecoveryEmailVerificationDev = onCall({enforceAppCheck: false}, confirmRecoveryEmailVerificationHandler);

async function requestPasswordRecoveryHandler(request: CallableRequest) {
  let authUser;
  try {
    authUser = await getAuth().getUserByEmail(authEmailForSchoolId(request.data?.schoolId));
  } catch {
    return GENERIC_RESPONSE;
  }
  const privateRef = db.collection("user_private").doc(authUser.uid);
  const privateSnapshot = await privateRef.get();
  const recoveryEmail = privateSnapshot.data()?.recoveryEmail;
  if (privateSnapshot.data()?.recoveryEmailVerified !== true || typeof recoveryEmail !== "string") return GENERIC_RESPONSE;
  const rateRef = db.collection("_password_recovery_limits").doc(authUser.uid);
  const now = Timestamp.now();
  const rawToken = token();
  const tokenRef = db.collection("password_recovery_tokens").doc(hash(rawToken));
  const mailRef = db.collection("mail").doc();
  await db.runTransaction(async (transaction) => {
    const rate = await transaction.get(rateRef);
    const lastSent = rate.data()?.lastSentAt;
    if (lastSent instanceof Timestamp && now.toMillis() - lastSent.toMillis() < 5 * 60_000) return;
    transaction.set(rateRef, {lastSentAt: now, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    transaction.create(tokenRef, {userId: authUser.uid, expiresAt: Timestamp.fromMillis(now.toMillis() + 30 * 60_000),
      state: "active", createdAt: FieldValue.serverTimestamp()});
    const link = `${PUBLIC_URL}/#/reset-password?token=${encodeURIComponent(rawToken)}`;
    transaction.create(mailRef, mail(recoveryEmail, "Reset your MindMate password",
      `<p>A password reset was requested for your MindMate account.</p><p><a href="${link}">Reset password</a></p><p>This one-time link expires in 30 minutes.</p>`));
  });
  return GENERIC_RESPONSE;
}

export const requestPasswordRecovery = onCall({enforceAppCheck: true}, requestPasswordRecoveryHandler);
export const requestPasswordRecoveryDev = onCall({enforceAppCheck: false}, requestPasswordRecoveryHandler);

async function confirmPasswordRecoveryHandler(request: CallableRequest) {
  const rawToken = typeof request.data?.token === "string" ? request.data.token : "";
  const newPassword = password(request.data?.password);
  if (rawToken.length < 20 || rawToken.length > 200) throw new HttpsError("invalid-argument", "The reset link is invalid.");
  const ref = db.collection("password_recovery_tokens").doc(hash(rawToken));
  let userId = "";
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data();
    if (!snapshot.exists || data?.state !== "active" || !(data?.expiresAt instanceof Timestamp) || data.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError("failed-precondition", "The reset link is invalid, expired, or already used.");
    }
    userId = String(data.userId ?? "");
    if (!userId) throw new HttpsError("failed-precondition", "The reset link is invalid.");
    transaction.update(ref, {state: "consuming", consumingAt: FieldValue.serverTimestamp()});
  });
  try {
    await getAuth().updateUser(userId, {password: newPassword});
    await getAuth().revokeRefreshTokens(userId);
    await ref.update({state: "consumed", consumedAt: FieldValue.serverTimestamp()});
  } catch (error) {
    await ref.update({state: "active", consumingAt: FieldValue.delete()}).catch(() => undefined);
    throw new HttpsError("internal", "The password could not be reset.");
  }
  return {ok: true};
}

export const confirmPasswordRecovery = onCall({enforceAppCheck: true}, confirmPasswordRecoveryHandler);
export const confirmPasswordRecoveryDev = onCall({enforceAppCheck: false}, confirmPasswordRecoveryHandler);
