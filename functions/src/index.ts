import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {getDownloadURL, getStorage} from "firebase-admin/storage";
import {onDocumentCreated, onDocumentDeleted, onDocumentWritten} from "firebase-functions/v2/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
export {aggregateMindAidFeedback, sendMindAidMessage} from "./mind_aid";

if (!getApps().length) initializeApp();

const db = getFirestore();
const posts = db.collection("secret_chats");
const stats = db.collection("secret_chat_profile_stats");
const events = db.collection("_secret_chat_events");
const analyticsEvents = db.collection("_analytics_events");
const secretChatProfiles = db.collection("secret_chat_profiles");
const secretChatAliases = db.collection("secret_chat_aliases");

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

export const saveSecretChatProfile = onCall(async (request) => {
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
});

export const finalizeSecretChatProfilePhoto = onCall(async (request) => {
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
});

export const removeSecretChatProfilePhoto = onCall(async (request) => {
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
});

export const deleteSecretChatPost = onCall(async (request) => {
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
});

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
  return {...(user.data() ?? {}), accessRole};
}

const POPULATION_ROLES = ["student", "teaching", "nonTeaching"] as const;
const ACCESS_ROLES = ["appUser", "portalStaff", "counselor", "admin"] as const;
export type AccessRoleValue = typeof ACCESS_ROLES[number];
export const canReviewVerification = (role: string): boolean =>
  ["portalStaff", "counselor", "admin"].includes(role);
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

export const requestRoleCorrection = onCall(async (request) => {
  const userId = requireAuthenticatedUser(request);
  const requestedRole = String(request.data?.requestedRole ?? "");
  if (!POPULATION_ROLES.includes(requestedRole as typeof POPULATION_ROLES[number])) {
    throw new HttpsError("invalid-argument", "Choose a valid population role.");
  }
  const reason = requiredText(request.data?.reason, "Reason", 10, 500);
  const userRef = db.collection("users").doc(userId);
  const requestRef = db.collection("role_correction_requests").doc();
  await db.runTransaction(async (transaction) => {
    const user = await transaction.get(userRef);
    if (!user.exists) throw new HttpsError("not-found", "User profile not found.");
    const currentRole = String(user.data()?.populationRole ?? user.data()?.declaredRole ?? "");
    if (currentRole === requestedRole) {
      throw new HttpsError("failed-precondition", "This is already your current role.");
    }
    transaction.create(requestRef, {
      userId,
      currentRole,
      requestedRole,
      reason,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return {ok: true, requestId: requestRef.id};
});

export const reviewProfileVerification = onCall(async (request) => {
  const actorId = requireAuthenticatedUser(request);
  const actor = await requireStaff(actorId);
  const targetUserId = requiredText(request.data?.userId, "User ID", 1, 128);
  const decision = String(request.data?.decision ?? "");
  const reason = requiredText(request.data?.reason, "Reason", 3, 500);
  if (!["verified", "rejected", "needsReview"].includes(decision)) {
    throw new HttpsError("invalid-argument", "Choose a valid verification decision.");
  }
  if (actorId === targetUserId) {
    throw new HttpsError("permission-denied", "You cannot verify your own profile.");
  }
  const target = db.collection("users").doc(targetUserId);
  const audit = db.collection("role_audit_logs").doc();
  await db.runTransaction(async (transaction) => {
    const before = await transaction.get(target);
    if (!before.exists) throw new HttpsError("not-found", "User profile not found.");
    transaction.update(target, {
      verificationStatus: decision,
      verifiedAt: decision === "verified" ? FieldValue.serverTimestamp() : null,
      verifiedBy: decision === "verified" ? actorId : "",
      profileVersion: 2,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(audit, {
      targetUserId,
      actorId,
      actorAccessRole: actor.accessRole,
      action: "verificationReviewed",
      reason,
      before: {verificationStatus: before.data()?.verificationStatus ?? "needsReview"},
      after: {verificationStatus: decision},
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return {ok: true};
});

export const reviewRoleCorrection = onCall(async (request) => {
  const actorId = requireAuthenticatedUser(request);
  const actor = await requireStaff(actorId);
  if (actor.accessRole !== "admin") {
    throw new HttpsError("permission-denied", "Administrator access is required.");
  }
  const requestId = requiredText(request.data?.requestId, "Request ID", 1, 128);
  const approve = request.data?.approve === true;
  const reason = requiredText(request.data?.reason, "Reason", 3, 500);
  const requestRef = db.collection("role_correction_requests").doc(requestId);
  const audit = db.collection("role_audit_logs").doc();
  await db.runTransaction(async (transaction) => {
    const correction = await transaction.get(requestRef);
    if (!correction.exists || correction.data()?.status !== "pending") {
      throw new HttpsError("failed-precondition", "This request is no longer pending.");
    }
    const targetUserId = String(correction.data()?.userId ?? "");
    if (targetUserId === actorId) {
      throw new HttpsError("permission-denied", "You cannot approve your own role change.");
    }
    const target = db.collection("users").doc(targetUserId);
    const before = await transaction.get(target);
    if (!before.exists) throw new HttpsError("not-found", "User profile not found.");
    const requestedRole = String(correction.data()?.requestedRole ?? "");
    transaction.update(requestRef, {
      status: approve ? "approved" : "rejected",
      reviewReason: reason,
      reviewedBy: actorId,
      reviewedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (approve) {
      transaction.update(target, {
        populationRole: requestedRole,
        declaredRole: requestedRole,
        verificationStatus: "verified",
        verifiedAt: FieldValue.serverTimestamp(),
        verifiedBy: actorId,
        profileVersion: 2,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    transaction.create(audit, {
      targetUserId,
      actorId,
      actorAccessRole: actor.accessRole,
      action: approve ? "roleCorrectionApproved" : "roleCorrectionRejected",
      reason,
      requestId,
      before: {populationRole: before.data()?.populationRole ?? before.data()?.role ?? ""},
      after: {populationRole: approve ? requestedRole : before.data()?.populationRole ?? ""},
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return {ok: true};
});

export const assignAccessRole = onCall(async (request) => {
  const actorId = requireAuthenticatedUser(request);
  const actor = await requireStaff(actorId);
  if (actor.accessRole !== "admin") {
    throw new HttpsError("permission-denied", "Administrator access is required.");
  }
  const targetUserId = requiredText(request.data?.userId, "User ID", 1, 128);
  const accessRole = String(request.data?.accessRole ?? "");
  const reason = requiredText(request.data?.reason, "Reason", 3, 500);
  if (!ACCESS_ROLES.includes(accessRole as typeof ACCESS_ROLES[number])) {
    throw new HttpsError("invalid-argument", "Choose a valid access role.");
  }
  if (targetUserId === actorId) {
    throw new HttpsError("permission-denied", "You cannot change your own access.");
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
});

export function reactionDelta(before: unknown, after: unknown): number {
  return Number(after === true) - Number(before === true);
}

export function activeCommentDelta(before: unknown, after: unknown): number {
  return Number(after === "active") - Number(before === "active");
}

export const rebuildMySecretChatStats = onCall(async (request) => {
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
});

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
    const occurred = activity?.createdAt instanceof Timestamp ? activity.createdAt.toDate() : new Date();
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
        lastActiveAt: activity?.createdAt ?? FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.create(marker, {
        activityId: event.params.activityId,
        userId,
        dateKey,
        processedAt: FieldValue.serverTimestamp(),
      });
    });
  },
);

export const reviewAppointment = onCall(async (request) => {
  const staffId = request.auth?.uid;
  if (!staffId) throw new HttpsError("unauthenticated", "Sign in is required.");
  const staff = await requireStaff(staffId);
  const input = request.data as Record<string, unknown>;
  const appointmentId = String(input.appointmentId ?? "").trim();
  const action = String(input.action ?? "").trim();
  const reply = String(input.reply ?? "").trim();
  const proposedMillis = Number(input.proposedScheduledAt ?? 0);
  const proposedTime = String(input.proposedScheduledTime ?? "").trim();
  if (!appointmentId || !["confirmed", "declined", "reschedule_proposed"].includes(action)) {
    throw new HttpsError("invalid-argument", "A valid appointment decision is required.");
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
    const before = String(data.status ?? "pending").toLowerCase();
    if (!["pending", "upcoming", "reschedule_proposed"].includes(before)) {
      throw new HttpsError("failed-precondition", "This appointment has already been finalized.");
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
    const title = action === "confirmed" ? "Appointment confirmed" : action === "declined" ? "Appointment update" : "New appointment time proposed";
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
