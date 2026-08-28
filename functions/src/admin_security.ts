export function superAdminUidFromSecurity(
  data: FirebaseFirestore.DocumentData | undefined,
): string | null {
  const value = String(data?.superAdminUid ?? "").trim();
  return value || null;
}

export function isSuperAdminIdentity(
  uid: string,
  security: FirebaseFirestore.DocumentData | undefined,
  profile: FirebaseFirestore.DocumentData | undefined,
): boolean {
  return superAdminUidFromSecurity(security) === uid && profile?.accessRole === "admin";
}
