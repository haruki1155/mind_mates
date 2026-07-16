import {AssessmentRole, roleFromPopulation} from "./catalog";

export type QuickProfileRoleDecision = "match" | "backfill" | "mismatch";

export function quickProfileRoleDecision(
  profile: Record<string, unknown>,
  requestedRole: AssessmentRole,
): QuickProfileRoleDecision {
  const storedRole = roleFromPopulation(profile.populationRole) ??
    roleFromPopulation(profile.declaredRole) ??
    roleFromPopulation(profile.role);
  if (!storedRole) return "backfill";
  return storedRole === requestedRole ? "match" : "mismatch";
}

export function submissionHashesMatch(
  storedHash: unknown,
  requestedHash: string,
): boolean {
  return typeof storedHash === "string" && storedHash === requestedHash;
}
