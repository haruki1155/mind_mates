import {getFirestore, Timestamp, FieldValue} from "firebase-admin/firestore";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {requireApprovedPortalActor} from "./portal_access";

export const SERVICE_CATALOG = [
  {serviceKey: "quick_assessment", displayLabel: "Quick Assessment", activityTypes: ["quickAssessment"]},
  {serviceKey: "full_assessment", displayLabel: "Full Assessment", activityTypes: ["fullAssessment"]},
  {serviceKey: "appointments", displayLabel: "Appointments", activityTypes: ["appointmentRequested"]},
  {serviceKey: "mindaid", displayLabel: "MindAid", activityTypes: ["mindAidMessage"]},
  {serviceKey: "log_mood", displayLabel: "Log Mood", activityTypes: ["moodCheckIn"]},
  {serviceKey: "sleep_quality", displayLabel: "Sleep Quality", activityTypes: ["sleepQuality"]},
  {serviceKey: "breathing", displayLabel: "Breathing", activityTypes: ["breathingSession"]},
  {serviceKey: "secret_chat", displayLabel: "Secret Chat", activityTypes: ["secretChatPost", "secretChatComment", "secretChatInteraction"]},
] as const;

export const SERVICE_HEALTH_THRESHOLDS = {
  latencyMs: 3000,
  errorRate: 0.05,
  staleHours: 24,
  retentionDays: 365,
} as const;

const catalogByType = new Map<string, string>();
for (const service of SERVICE_CATALOG) {
  for (const type of service.activityTypes) catalogByType.set(type, service.serviceKey);
}

export function serviceKeyForActivity(type: unknown): string | null {
  return catalogByType.get(String(type ?? "")) ?? null;
}

export function normalizeServiceErrorCode(value: unknown): string {
  const code = String(value ?? "unknown").toLowerCase();
  if (code.includes("permission") || code.includes("unauthenticated")) return "permission_denied";
  if (code.includes("timeout") || code.includes("deadline")) return "timeout";
  if (code.includes("invalid") || code.includes("argument")) return "validation_error";
  if (code.includes("network") || code.includes("unavailable")) return "dependency_unavailable";
  return "internal_error";
}

export async function recordServiceSuccess(serviceKey: string, latencyMs = 0): Promise<void> {
  if (!SERVICE_CATALOG.some((service) => service.serviceKey === serviceKey)) return;
  const db = getFirestore();
  const dateKey = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Manila", year: "numeric", month: "2-digit", day: "2-digit",
  }).format(new Date());
  const ref = db.collection("service_monitoring_daily").doc(`${dateKey}_${serviceKey}`);
  await ref.set({
    serviceKey,
    dateKey,
    successCount: FieldValue.increment(1),
    totalLatencyMs: FieldValue.increment(Math.max(0, Math.round(latencyMs))),
    lastSuccessAt: FieldValue.serverTimestamp(),
    lastTelemetryAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

export async function recordServiceError(serviceKey: string, errorCode: unknown, latencyMs = 0): Promise<void> {
  if (!SERVICE_CATALOG.some((service) => service.serviceKey === serviceKey)) return;
  const db = getFirestore();
  const dateKey = new Intl.DateTimeFormat("en-CA", {timeZone: "Asia/Manila", year: "numeric", month: "2-digit", day: "2-digit"}).format(new Date());
  const ref = db.collection("service_monitoring_daily").doc(`${dateKey}_${serviceKey}`);
  const safeCode = normalizeServiceErrorCode(errorCode);
  await ref.set({serviceKey, dateKey, errorCount: FieldValue.increment(1), totalLatencyMs: FieldValue.increment(Math.max(0, Math.round(latencyMs))), [`safeErrorCodeCounts.${safeCode}`]: FieldValue.increment(1), lastTelemetryAt: FieldValue.serverTimestamp()}, {merge: true});
}

export function classifyServiceHealth(args: {
  hasEvidence: boolean;
  lastTelemetryAt: Date | null;
  successCount: number;
  errorCount: number;
  averageLatencyMs: number;
  now: Date;
}): "healthy" | "stale" | "degraded" | "unavailable" {
  if (!args.hasEvidence) return "unavailable";
  if (!args.lastTelemetryAt || args.now.getTime() - args.lastTelemetryAt.getTime() > SERVICE_HEALTH_THRESHOLDS.staleHours * 3600000) return "stale";
  const total = args.successCount + args.errorCount;
  if (args.averageLatencyMs > SERVICE_HEALTH_THRESHOLDS.latencyMs || (total > 0 && args.errorCount / total > SERVICE_HEALTH_THRESHOLDS.errorRate)) return "degraded";
  return "healthy";
}

async function getAdminServiceMonitoringHandler(request: CallableRequest) {
  await requireApprovedPortalActor(request, ["counselor", "admin"]);
  const days = Number(request.data?.days ?? 7);
  if (![7, 30, 90].includes(days)) throw new HttpsError("invalid-argument", "Monitoring range must be 7, 30, or 90 days.");
  const requestedService = String(request.data?.serviceKey ?? "").trim();
  const services = requestedService ? SERVICE_CATALOG.filter((service) => service.serviceKey === requestedService) : SERVICE_CATALOG;
  if (requestedService && services.length === 0) throw new HttpsError("invalid-argument", "Unknown service.");
  const db = getFirestore();
  const cutoff = Date.now() - days * 86400000;
  const [profiles, activities, telemetry, mindAid] = await Promise.all([
    db.collection("users").get(), db.collection("user_activities").get(),
    db.collection("service_monitoring_daily").get(), db.collection("mind_aid_analytics_daily").get(),
  ]);
  const appUserIds = new Set(profiles.docs.filter((doc) => doc.data().accessRole === "appUser" && doc.data().staffAccountStatus == null).map((doc) => doc.id));
  const activityByService = new Map<string, {count: number; users: Set<string>; trend: Map<string, number>; last: Date | null}>();
  for (const service of SERVICE_CATALOG) activityByService.set(service.serviceKey, {count: 0, users: new Set(), trend: new Map(), last: null});
  for (const doc of activities.docs) {
    const data = doc.data();
    const occurred = data.createdAt instanceof Timestamp ? data.createdAt.toDate() : null;
    const serviceKey = serviceKeyForActivity(data.type);
    const userId = String(data.userId ?? "");
    if (!occurred || occurred.getTime() < cutoff || !serviceKey || !appUserIds.has(userId)) continue;
    const aggregate = activityByService.get(serviceKey)!;
    const dateKey = new Intl.DateTimeFormat("en-CA", {timeZone: "Asia/Manila", year: "numeric", month: "2-digit", day: "2-digit"}).format(occurred);
    aggregate.count++; aggregate.users.add(userId); aggregate.trend.set(dateKey, (aggregate.trend.get(dateKey) ?? 0) + 1);
    if (!aggregate.last || occurred > aggregate.last) aggregate.last = occurred;
  }
  const now = new Date();
  const result = services.map((service) => {
    const aggregate = activityByService.get(service.serviceKey)!;
    const rows = telemetry.docs.filter((doc) => doc.data().serviceKey === service.serviceKey && String(doc.data().dateKey ?? "") >= new Intl.DateTimeFormat("en-CA", {timeZone: "Asia/Manila", year: "numeric", month: "2-digit", day: "2-digit"}).format(new Date(cutoff)));
    let successCount = 0; let errorCount = 0; let totalLatencyMs = 0; let lastTelemetryAt: Date | null = null; let lastSuccessAt: Date | null = aggregate.last; const safeErrorCodeCounts: Record<string, number> = {};
    for (const row of rows) { const data = row.data(); successCount += Number(data.successCount ?? 0); errorCount += Number(data.errorCount ?? 0); totalLatencyMs += Number(data.totalLatencyMs ?? 0); for (const [code, count] of Object.entries((data.safeErrorCodeCounts ?? {}) as Record<string, unknown>)) safeErrorCodeCounts[code] = (safeErrorCodeCounts[code] ?? 0) + Number(count ?? 0); const telemetryAt = data.lastTelemetryAt instanceof Timestamp ? data.lastTelemetryAt.toDate() : null; if (telemetryAt && (!lastTelemetryAt || telemetryAt > lastTelemetryAt)) lastTelemetryAt = telemetryAt; const successAt = data.lastSuccessAt instanceof Timestamp ? data.lastSuccessAt.toDate() : null; if (successAt && (!lastSuccessAt || successAt > lastSuccessAt)) lastSuccessAt = successAt; }
    const total = successCount + errorCount;
    const mindAidRows = service.serviceKey === "mindaid" ? mindAid.docs.filter((doc) => String(doc.data().dateKey ?? "") >= new Intl.DateTimeFormat("en-CA", {timeZone: "Asia/Manila", year: "numeric", month: "2-digit", day: "2-digit"}).format(new Date(cutoff))) : [];
    const turnCount = mindAidRows.reduce((sum, doc) => sum + Number(doc.data().turnCount ?? 0), 0);
    const fallbackCount = mindAidRows.reduce((sum, doc) => sum + Number(doc.data().fallbackCount ?? 0), 0);
    return {serviceKey: service.serviceKey, displayLabel: service.displayLabel, activityCount: aggregate.count, activeUserCount: aggregate.users.size, dailyTrend: Array.from(aggregate.trend.entries()).sort(([a], [b]) => a.localeCompare(b)).map(([dateKey, count]) => ({dateKey, count})), lastSuccessfulActivityAt: lastSuccessAt?.toISOString() ?? null, healthState: classifyServiceHealth({hasEvidence: rows.length > 0 || aggregate.count > 0, lastTelemetryAt, successCount, errorCount, averageLatencyMs: total ? Math.round(totalLatencyMs / total) : 0, now}), successCount, errorCount, averageLatencyMs: total ? Math.round(totalLatencyMs / total) : 0, safeErrorCodeCounts, telemetryFreshness: lastTelemetryAt?.toISOString() ?? null, ...(service.serviceKey === "mindaid" ? {turnCount, fallbackCount, fallbackRate: turnCount ? fallbackCount / turnCount : 0} : {})};
  });
  return {days, services: result};
}

export const getAdminServiceMonitoring = onCall({enforceAppCheck: true}, getAdminServiceMonitoringHandler);
export const getAdminServiceMonitoringDev = onCall({enforceAppCheck: false}, getAdminServiceMonitoringHandler);

export const purgeServiceMonitoring = onSchedule("every 24 hours", async () => {
  const cutoff = Date.now() - SERVICE_HEALTH_THRESHOLDS.retentionDays * 86400000;
  const snapshot = await getFirestore().collection("service_monitoring_daily").get();
  const writer = getFirestore().bulkWriter();
  for (const document of snapshot.docs) {
    const dateKey = String(document.data().dateKey ?? "");
    const parsed = Date.parse(`${dateKey}T00:00:00Z`);
    if (Number.isFinite(parsed) && parsed < cutoff) writer.delete(document.ref);
  }
  await writer.close();
});
