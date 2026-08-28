import {getFirestore} from "firebase-admin/firestore";
import {HttpsError, CallableRequest} from "firebase-functions/v2/https";
import {superAdminUidFromSecurity} from "./admin_security";

export type PortalRole = "portalStaff" | "counselor" | "admin";

export type ApprovedPortalActor = {
  uid: string;
  accessRole: PortalRole;
  displayName: string;
};

export function isApprovedPortalIdentity(
  uid: string,
  profile: Record<string, unknown>,
  superAdminUid: string | null,
  allowed: readonly PortalRole[] = ["portalStaff", "counselor", "admin"],
): boolean {
  const accessRole = String(profile.accessRole ?? "") as PortalRole;
  if (!allowed.includes(accessRole)) return false;
  if (accessRole === "admin") return Boolean(uid) && uid === superAdminUid;
  return profile.staffAccountStatus === "approved";
}

export function authenticatedUid(request: Pick<CallableRequest, "auth">): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  return uid;
}

export async function requireApprovedPortalActor(
  request: Pick<CallableRequest, "auth">,
  allowed: readonly PortalRole[] = ["portalStaff", "counselor", "admin"],
): Promise<ApprovedPortalActor> {
  const uid = authenticatedUid(request);
  const db = getFirestore();
  const [profile, security] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("system_config").doc("security").get(),
  ]);
  if (!profile.exists) throw new HttpsError("permission-denied", "Approved portal access is required.");
  const data = profile.data() ?? {};
  const accessRole = String(data.accessRole ?? "") as PortalRole;
  const superAdminUid = superAdminUidFromSecurity(security.data());
  if (!isApprovedPortalIdentity(uid, data, superAdminUid, allowed)) {
    throw new HttpsError("permission-denied", "This portal account is not approved.");
  }
  const displayName = String(data.name ?? `${data.firstName ?? ""} ${data.lastName ?? ""}`).trim();
  return {uid, accessRole, displayName: displayName || "Counseling staff"};
}
