import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import test from "node:test";

const aliases: Record<string, readonly string[]> = {
  "account_integrity.ts": ["provisionAppUserProfile", "getAssessmentStatus"],
  "account_recovery.ts": [
    "requestRecoveryEmailVerification", "confirmRecoveryEmailVerification",
    "requestPasswordRecovery", "confirmPasswordRecovery",
  ],
  "admin_directory.ts": ["listPublicAppUsers", "getAppUserDashboardSummary"],
  "appointment_workflow.ts": [
    "createAppointmentRequest", "reviewAppointment",
    "respondToAppointmentReschedule", "scheduleAppointmentFollowUp",
  ],
  "assessment/submissions.ts": ["submitQuickAssessment", "submitFullAssessment"],
  "index.ts": [
    "saveSecretChatProfile", "finalizeSecretChatProfilePhoto",
    "removeSecretChatProfilePhoto", "deleteSecretChatPost",
    "registerStaffAccount", "reviewStaffRegistration", "setStaffAccountEnabled",
    "backfillPublicAppUserIds", "previewInactiveAppUserDeletion",
    "deleteInactiveAppUsers", "confirmSuperAdmin", "completeAdminPasswordChange",
    "assignAccessRole", "saveOrganizationRecord", "updateStaffOrganization",
    "rebuildMySecretChatStats",
  ],
  "mind_aid.ts": ["sendMindAidMessage"],
  "service_monitoring.ts": ["getAdminServiceMonitoring"],
};

test("every client callable has paired App Check wrappers around one handler", () => {
  for (const [file, names] of Object.entries(aliases)) {
    const source = readFileSync(join(__dirname, "..", "src", file), "utf8");
    for (const name of names) {
      const handler = `${name}Handler`;
      assert.match(source, new RegExp(`async function ${handler}\\(request: CallableRequest\\)`));
      assert.match(
        source,
        new RegExp(`export const ${name} = onCall\\([\\s\\S]{0,220}?enforceAppCheck: true[\\s\\S]{0,220}?${handler}\\);`),
      );
      assert.match(
        source,
        new RegExp(`export const ${name}Dev = onCall\\([\\s\\S]{0,220}?enforceAppCheck: false[\\s\\S]{0,220}?${handler}\\);`),
      );
    }
  }
});
