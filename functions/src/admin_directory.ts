import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {CallableRequest, onCall} from "firebase-functions/v2/https";
import {requireApprovedPortalActor} from "./portal_access";

function role(value: unknown): string {
  const normalized = String(value ?? "").trim().toLowerCase().replace(/[\s_-]+/g, "");
  if (normalized === "student") return "student";
  if (["teaching", "faculty", "teachingpersonnel"].includes(normalized)) return "teaching";
  if (["nonteaching", "nonteachingpersonnel", "staff"].includes(normalized)) return "nonTeaching";
  return "unknown";
}

function isAppUser(data: FirebaseFirestore.DocumentData): boolean {
  return data.accessRole === "appUser" && data.staffAccountStatus == null;
}

async function listPublicAppUsersHandler(request: CallableRequest) {
  await requireApprovedPortalActor(request);
  const db = getFirestore();
  const pageSize = Math.min(Math.max(Number(request.data?.pageSize ?? 25), 1), 50);
  const cursor = String(request.data?.cursor ?? "").trim();
  const search = String(request.data?.search ?? "").trim().toLowerCase().slice(0, 120);
  const roleFilter = String(request.data?.role ?? "").trim();
  const departmentFilter = String(request.data?.department ?? "").trim().toLowerCase().slice(0, 120);
  const courseFilter = String(request.data?.course ?? "").trim().toLowerCase().slice(0, 120);
  const yearFilter = String(request.data?.yearLevel ?? "").trim().toLowerCase().slice(0, 80);
  const profiles = await db.collection("users").get();
  const appUsers = profiles.docs.filter((doc) => isAppUser(doc.data()));
  const appUserIds = new Set(appUsers.map((doc) => doc.id));
  const profilesByUid = new Map(appUsers.map((doc) => [doc.id, doc.data()]));
  const users: Record<string, unknown>[] = [];
  let lastCursor = cursor;
  let exhausted = false;
  while (users.length < pageSize && !exhausted) {
    let query: FirebaseFirestore.Query = db.collection("user_public_ids")
      .orderBy("publicUserId").limit(100);
    if (lastCursor) query = query.startAfter(lastCursor);
    const mappings = await query.get();
    exhausted = mappings.size < 100;
    if (mappings.empty) break;
    for (const mapping of mappings.docs) {
      const publicUserId = String(mapping.data().publicUserId ?? "").trim();
      if (!publicUserId) continue;
      lastCursor = publicUserId;
      if (!appUserIds.has(mapping.id)) continue;
      const profile = profilesByUid.get(mapping.id) ?? {};
      const record = {
        publicUserId,
        populationRole: role(profile.populationRole ?? profile.declaredRole ?? profile.role),
        department: String(profile.department ?? profile.departmentName ?? "").trim(),
        course: String(profile.course ?? profile.courseName ?? "").trim(),
        yearLevel: String(profile.yearLevel ?? "").trim(),
      };
      const searchable = Object.values(record).join(" ").toLowerCase();
      if (search && !searchable.includes(search)) continue;
      if (roleFilter && record.populationRole !== roleFilter) continue;
      if (departmentFilter && !record.department.toLowerCase().includes(departmentFilter)) continue;
      if (courseFilter && !record.course.toLowerCase().includes(courseFilter)) continue;
      if (yearFilter && !record.yearLevel.toLowerCase().includes(yearFilter)) continue;
      users.push(record);
      if (users.length === pageSize) break;
    }
  }
  return {
    users,
    totalAppUsers: appUsers.length,
    // A full page may have unread entries remaining in the fetched batch.
    // Returning the safe cursor can at worst yield one final empty page; it
    // never skips an app user.
    nextCursor: users.length === pageSize && lastCursor ? lastCursor : null,
  };
}

export const listPublicAppUsers = onCall({enforceAppCheck: true}, listPublicAppUsersHandler);
export const listPublicAppUsersDev = onCall({enforceAppCheck: false}, listPublicAppUsersHandler);

async function getAppUserDashboardSummaryHandler(request: CallableRequest) {
  await requireApprovedPortalActor(request, ["counselor", "admin"]);
  const profiles = await getFirestore().collection("users").get();
  const counts = {student: 0, teaching: 0, nonTeaching: 0, unknown: 0};
  const portalCounts = {portalStaff: 0, counselor: 0, admin: 0};
  const now = new Date();
  const monthKeys = Array.from({length: 6}, (_, index) => {
    const value = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 5 + index, 1));
    return `${value.getUTCFullYear()}-${String(value.getUTCMonth() + 1).padStart(2, "0")}`;
  });
  const monthlyActiveUsers = Object.fromEntries(monthKeys.map((key) => [key, 0]));
  let totalAppUsers = 0;
  const appUserIds = new Set<string>();
  for (const document of profiles.docs) {
    const data = document.data();
    if (isAppUser(data)) {
      totalAppUsers++;
      appUserIds.add(document.id);
      counts[role(data.populationRole ?? data.declaredRole ?? data.role) as keyof typeof counts]++;
      continue;
    }
    const accessRole = String(data.accessRole ?? "") as keyof typeof portalCounts;
    if (accessRole in portalCounts && (accessRole === "admin" || data.staffAccountStatus === "approved")) {
      portalCounts[accessRole]++;
    }
  }
  const activeCutoff = now.getTime() - 30 * 24 * 60 * 60 * 1000;
  const activeAppUserIds = new Set<string>();
  const activities = await getFirestore().collection("user_activities").get();
  for (const document of activities.docs) {
    const data = document.data();
    const userId = String(data.userId ?? "");
    if (!appUserIds.has(userId) || !(data.createdAt instanceof Timestamp)) continue;
    const millis = data.createdAt.toMillis();
    if (millis >= activeCutoff) activeAppUserIds.add(userId);
    const date = data.createdAt.toDate();
    const key = `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
    if (key in monthlyActiveUsers) monthlyActiveUsers[key]++;
  }
  const activeAppUsers = activeAppUserIds.size;
  return {totalAppUsers, activeAppUsers, populationCounts: counts, portalCounts, monthlyActiveUsers};
}

export const getAppUserDashboardSummary = onCall({enforceAppCheck: true}, getAppUserDashboardSummaryHandler);
export const getAppUserDashboardSummaryDev = onCall({enforceAppCheck: false}, getAppUserDashboardSummaryHandler);
