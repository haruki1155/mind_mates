import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {after, before, beforeEach, test} from "node:test";
import {assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment} from "@firebase/rules-unit-testing";
import {doc, getDoc, serverTimestamp, setDoc, Timestamp, updateDoc} from "firebase/firestore";

let environment: RulesTestEnvironment;
before(async () => {
  environment = await initializeTestEnvironment({
    projectId: "mind-mates-profile-rules-test",
    firestore: {rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8")},
  });
});
beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

function profile(id: string, accessRole = "appUser") {
  return {
    id, email: `${id}@mindmate.local`, name: "Profile User",
    firstName: "Profile", middleName: "", lastName: "User",
    schoolId: "S-1", employeeId: "", department: "CITE", course: "BSIT",
    yearLevel: "2", sector: "", position: "", role: "student",
    populationRole: "student", declaredRole: "student", accessRole,
    profileVersion: 2, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  };
}

test("profiles are server-created and owners can edit structured display fields", async () => {
  const db = environment.authenticatedContext("owner").firestore();
  const ref = doc(db, "users/owner");
  await assertFails(setDoc(ref, profile("owner")));
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/owner"), profile("owner"));
  });
  await assertSucceeds(updateDoc(ref, {firstName: "Updated", updatedAt: serverTimestamp()}));
  await assertFails(updateDoc(ref, {name: "Updated User", updatedAt: serverTimestamp()}));
});

test("owner cannot forge assessment completion", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/owner"), profile("owner"));
  });
  const ref = doc(environment.authenticatedContext("owner").firestore(), "users/owner");
  await assertFails(updateDoc(ref, {quickAssessmentCompleted: true}));
  await assertFails(updateDoc(ref, {quickAssessmentCompletedAt: Timestamp.now()}));
});

test("owner cannot promote or change the signup institutional role", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/owner"), profile("owner"));
  });
  const ref = doc(environment.authenticatedContext("owner").firestore(), "users/owner");
  await assertFails(updateDoc(ref, {accessRole: "admin"}));
  await assertFails(updateDoc(ref, {verificationStatus: "verified"}));
  await assertFails(updateDoc(ref, {schoolId: "OTHER"}));
  await assertFails(updateDoc(ref, {populationRole: "teaching"}));
});

test("owners cannot transfer stored records to another user", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/owner"), profile("owner"));
    await setDoc(doc(context.firestore(), "reports/report-1"), {
      userId: "owner", title: "Private report", generatedAt: Timestamp.now(),
    });
  });
  const ref = doc(environment.authenticatedContext("owner").firestore(), "reports/report-1");
  await assertFails(updateDoc(ref, {userId: "another-user"}));
});

test("counselors cannot edit administrator-curated insight configuration", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/counselor"), profile("counselor", "counselor"));
    await setDoc(doc(context.firestore(), "users/admin"), profile("admin", "admin"));
  });
  await assertFails(setDoc(
    doc(environment.authenticatedContext("counselor").firestore(), "insight_categories/cat-1"),
    {name: "Private category"},
  ));
  await assertSucceeds(setDoc(
    doc(environment.authenticatedContext("admin").firestore(), "insight_categories/cat-1"),
    {name: "Curated category"},
  ));
});

test("super-administrator rotation state is server-only", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/admin"), profile("admin", "admin"));
    await setDoc(doc(context.firestore(), "system_config/security"), {superAdminUid: "admin"});
    await setDoc(doc(context.firestore(), "_super_admin_rotations/current"), {status: "prepared"});
  });
  const rotation = doc(
    environment.authenticatedContext("admin").firestore(),
    "_super_admin_rotations/current",
  );
  await assertFails(getDoc(rotation));
  await assertFails(setDoc(rotation, {status: "finalized"}));
});

test("service monitoring aggregates are readable only by approved clinical staff and never client-writable", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/counselor"), {
      ...profile("counselor", "counselor"), staffAccountStatus: "approved",
    });
    await setDoc(doc(context.firestore(), "users/admin"), profile("admin", "admin"));
    await setDoc(doc(context.firestore(), "system_config/security"), {superAdminUid: "admin"});
    await setDoc(doc(context.firestore(), "service_monitoring_daily/2026-07-17_mindaid"), {
      serviceKey: "mindaid", dateKey: "2026-07-17", successCount: 1,
    });
  });
  await assertSucceeds(getDoc(doc(environment.authenticatedContext("counselor").firestore(), "service_monitoring_daily/2026-07-17_mindaid")));
  await assertSucceeds(getDoc(doc(environment.authenticatedContext("admin").firestore(), "service_monitoring_daily/2026-07-17_mindaid")));
  await assertFails(getDoc(doc(environment.authenticatedContext("app-user").firestore(), "service_monitoring_daily/2026-07-17_mindaid")));
  await assertFails(setDoc(doc(environment.authenticatedContext("counselor").firestore(), "service_monitoring_daily/2026-07-17_other"), {serviceKey: "sleep_quality"}));
});

test("appointment requests and lifecycle history are server-owned", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/owner"), profile("owner"));
    await setDoc(doc(context.firestore(), "users/admin"), profile("admin", "admin"));
    await setDoc(doc(context.firestore(), "system_config/security"), {superAdminUid: "admin"});
    await setDoc(doc(context.firestore(), "appointments/existing-appointment"), {
      userId: "owner", status: "pending", scheduledAt: Timestamp.now(),
    });
  });
  await assertFails(setDoc(
    doc(environment.authenticatedContext("owner").firestore(), "appointments/forged-appointment"),
    {userId: "owner", status: "completed", assignedStaffId: "forged"},
  ));
  await assertSucceeds(setDoc(
    doc(environment.authenticatedContext("owner").firestore(), "appointments/compatible-pending"),
    {
      userId: "owner", fullName: "Profile User", concern: "Needs support",
      scheduledAt: Timestamp.fromDate(new Date(Date.now() + 86_400_000)),
      scheduledTime: "10:00 AM", location: "PACC Office", status: "pending",
      counselorName: "", assignedStaffId: "", staffReply: "", reviewedAt: null,
      proposedScheduledAt: null, proposedScheduledTime: "",
      parentAppointmentId: "", rootAppointmentId: "", startedAt: null,
      completedAt: null, statusBeforeReschedule: "", proposedBy: "", proposedAt: null,
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    },
  ));
  await assertFails(setDoc(
    doc(environment.authenticatedContext("owner").firestore(), "appointments/forged-assignee"),
    {
      userId: "owner", fullName: "Profile User", concern: "Needs support",
      scheduledAt: Timestamp.fromDate(new Date(Date.now() + 86_400_000)),
      scheduledTime: "10:00 AM", location: "PACC Office", status: "pending",
      counselorName: "Fake", assignedStaffId: "attacker", staffReply: "",
      reviewedAt: null, proposedScheduledAt: null, proposedScheduledTime: "",
      parentAppointmentId: "", rootAppointmentId: "", startedAt: null,
      completedAt: null, statusBeforeReschedule: "", proposedBy: "", proposedAt: null,
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    },
  ));
  await assertFails(updateDoc(
    doc(environment.authenticatedContext("admin").firestore(), "appointments/existing-appointment"),
    {status: "completed"},
  ));
  await assertFails(setDoc(
    doc(environment.authenticatedContext("admin").firestore(), "appointments/existing-appointment/history/forged"),
    {status: "completed"},
  ));
});

test("only approved portal accounts can read appointment operations", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/owner"), profile("owner"));
    await setDoc(doc(context.firestore(), "users/approved-staff"), {
      ...profile("approved-staff", "portalStaff"),
      staffAccountStatus: "approved",
    });
    await setDoc(doc(context.firestore(), "users/pending-staff"), {
      ...profile("pending-staff", "portalStaff"),
      staffAccountStatus: "pending",
    });
    await setDoc(doc(context.firestore(), "appointments/appointment-access"), {
      userId: "owner", status: "pending", scheduledAt: Timestamp.now(),
    });
  });
  const path = "appointments/appointment-access";
  await assertSucceeds(getDoc(doc(
    environment.authenticatedContext("approved-staff").firestore(), path,
  )));
  await assertFails(getDoc(doc(
    environment.authenticatedContext("pending-staff").firestore(), path,
  )));
  await assertFails(getDoc(doc(
    environment.authenticatedContext("ordinary-user").firestore(), path,
  )));
});
