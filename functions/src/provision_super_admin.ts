import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";

const EXPECTED_PROJECT = "mindmate-dev-4e91c";

async function main(): Promise<void> {
  if (process.argv.includes("--apply")) {
    throw new Error(
      "Direct super-administrator provisioning is disabled. Use the guarded admin:rotate workflow.",
    );
  }
  if (!getApps().length) initializeApp({projectId: EXPECTED_PROJECT});
  const db = getFirestore();
  const [admins, security] = await Promise.all([
    db.collection("users").where("accessRole", "==", "admin").get(),
    db.collection("system_config").doc("security").get(),
  ]);
  const configuredUid = String(security.data()?.superAdminUid ?? "");
  const profile = admins.size === 1 ? admins.docs[0] : null;
  const user = profile ? await getAuth().getUser(profile.id).catch(() => null) : null;
  console.log(JSON.stringify({
    mode: "dry-run",
    projectMatches: true,
    adminProfileCount: admins.size,
    uniqueAdminProfile: admins.size === 1,
    securityUidConfigured: Boolean(configuredUid),
    securityUidMatchesProfile: Boolean(profile && configuredUid === profile.id),
    authUserExists: user != null,
    authUserEnabled: user != null && !user.disabled,
    authEmailVerified: user?.emailVerified === true,
    passwordProviderConfigured: user?.providerData.some((item) => item.providerId === "password") === true,
  }));
}

void main().catch((error) => {
  console.error(error instanceof Error ? error.message : "Administrator health check failed.");
  process.exitCode = 1;
});
