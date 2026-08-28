# Firebase runtime verification

## Admin action visibility and staff authentication (2026-07-17)

The Admin portal now shows appointment actions directly on each card instead of
putting the next transition inside a generic dropdown. Pending appointments
show Confirm, Propose Reschedule, and Decline; confirmed appointments show
Start Session; ongoing appointments show Complete Session; completed
appointments show Schedule Follow-up; and outstanding proposals show Replace or
Withdraw Proposal. The lifecycle remains server-owned and preserves
`pending -> confirmed -> ongoing -> completed`.

Approved Portal Staff and Counselors authenticate through their
`staffAccountStatus == approved` decision and no longer require Firebase
mailbox verification. Pending, rejected, disabled, ordinary app-user, and
missing-profile accounts remain blocked. Only the configured administrator
still requires a verified Firebase email and successful `confirmSuperAdmin`
confirmation against `system_config/security.superAdminUid`.

The Admin release was built with identifier `20260717-admin-actions` and
deployed to `mind-mates-cd2cf.web.app`. Hosting now sends
`Cache-Control: no-store, max-age=0, must-revalidate` for the Admin entrypoint
and JavaScript, preventing an old open tab from silently retaining the prior
bundle. The live bundle was checked for the build identifier and all action
labels. Updated staff callables are active as revisions
`registerstaffaccount-00013-bep`, `reviewstaffregistration-00013-hem`, and
`setstaffaccountenabled-00012-baz`.

## Admin directory, analytics, and appointment rollout (2026-07-17)

The completed Admin rollout now uses server-owned, App Check-protected
callables for the anonymous app-user directory, aggregate dashboard, and the
appointment lifecycle. Portal Staff can access the directory and appointment
operations but not analytics. Approved Counselors and the configured
super-administrator can also access aggregate analytics. The directory returns
only public user ID, institutional role, department, course, and year level;
it does not return UID, name, email, School ID, phone, or assessment content.

App-user analytics consistently include only profiles whose `accessRole` is
`appUser` and that have no `staffAccountStatus`. The production analytics
rebuild completed after a managed Firestore backup. It updated two derived
daily aggregates while preserving raw activity and profile data. The immediate
second dry run reported zero creates, updates, or deletes, confirming an
idempotent result.

Appointment creation, staff lifecycle actions, user reschedule responses, and
follow-up creation are now performed by focused callable modules. Requests,
operations, history events, notifications, and direct follow-ups use stable
IDs and payload hashes so a retry cannot silently create duplicates. Unknown
statuses are rejected. Known legacy statuses remain readable through the
canonical pending, confirmed, ongoing, reschedule-proposed, completed,
declined, and cancelled states.

The deployed appointment revisions include
`reviewappointment-00013-huz` and
`respondtoappointmentreschedule-00002-nog`. Firestore Rules keep lifecycle,
history, and notification writes server-owned. A narrowly validated
pending-create compatibility rule remains temporarily for older debug clients;
remove it only after every active debug installation uses the callable-based
client and runtime verification has passed.

Verification completed for this rollout:

- `flutter analyze` completed with no issues;
- all 357 Flutter tests passed;
- all 40 Functions tests passed;
- 14 Firestore/profile rule tests and 8 Secret Chat/Storage rule tests passed;
- the Admin web release bundle built and was deployed successfully;
- the Android debug APK built as debuggable package
  `ph.edu.ucu.mindmates`, was installed with `adb install -r`, and launched
  with the Android App Check debug provider;
- the hosted Admin site returned HTTP 200 with the new directory, aggregate
  dashboard, calendar, and history/archive bundle.

These results verify the build, rules, deployment, and deterministic data
rebuild, but they do not complete the account-level runtime matrix. A protected
callable must still succeed from the registered emulator installation before
marking App Check as valid. Disposable Portal Staff, Counselor, Admin, and app
user accounts must then verify directory permissions, appointment transitions,
reschedule acceptance/decline, follow-up linkage, and Quick/Full Assessment
persistence. Provider activation or an APK launch alone is not evidence that a
callable received `auth: VALID` and `app: VALID`.

## App-user institutional role policy (2026-07-17)

Student, Teaching, and Non-Teaching are self-declared app-user roles. The role
selected during signup is immediately active and is immutable after profile
creation. It is not reviewed or approved in the Admin portal. Profile, Edit
Profile, Home, Quick Assessment, and Full Assessment use that selected role
without a role-verification status.

This policy is separate from staff security. Staff, counselor, and
administrator registrations continue to use `staffAccountStatus`, and only the
super-administrator can approve, reject, enable, disable, or assign portal
access. Staff approval timestamps remain staff metadata; the generic profile
`verificationStatus` is no longer used.

New app-user profiles omit `verificationStatus`, `verifiedAt`, and
`verifiedBy`. The profile migration removes those obsolete fields from app
users, removes only `verificationStatus` from staff profiles, and preserves
roles, institutional data, staff approval metadata, assessments, and historic
audit/correction documents. Run it first as a dry run, then apply it, then
confirm an idempotent dry run:

```powershell
cd functions
npm run profiles:dry-run
npm run profiles:apply
npm run profiles:dry-run
```

The retired role-correction and generic profile-verification callables must not
appear in `firebase functions:list`. Historical `role_correction_requests` and
`role_audit_logs` remain server-controlled and are not deleted.

The production migration completed on 2026-07-17. It scanned four profiles,
removed six obsolete fields from one app-user and three staff profiles, cleared
no Quick Assessment completion flags, and preserved the two assessment
documents. The immediate follow-up dry run reported `changed: 0`; the three
staff profiles remained classified as staff and the app-user profile retained
its selected institutional role. One pre-existing Auth-only account remains
without a profile and is handled by the existing retryable profile-repair flow.

The affected account functions, Firestore Rules/Indexes, and Admin Hosting
bundle were deployed successfully on 2026-07-17. Production function inventory
confirms `provisionAppUserProfile`, `registerStaffAccount`, and
`reviewStaffRegistration` are active, while `requestRoleCorrection`,
`reviewRoleCorrection`, and `reviewProfileVerification` have been deleted. The
hosted Admin site returns HTTP 200, and its release bundle contains none of the
retired endpoint names or app-user verification labels.

## Assessment contract correction (2026-07-16)

The deployed `submitQuickAssessment` and `submitFullAssessment` revisions now
use the shared v1 role contract in
`contracts/assessment_question_ids.v1.json`. Student full assessments retain
the established `sleep_*` and `emotional_*` IDs; Teaching and Non-Teaching
assessments retain `common_sleep_*` and `common_emotional_*`.

Before this correction, authenticated and App Check-valid Student submissions
could reach the backend but fail with `Invalid full-assessment answer`. A
catalog validation failure is now returned as `invalid-argument` instead of an
internal HTTP 500, and automated tests verify that the Flutter and Functions
catalogs match the same contract.

The corrected functions were deployed successfully to `mind-mates-cd2cf`.
The current assessment callable revisions are `submitquickassessment-00010-lar`
and `submitfullassessment-00010-sap`. The deployed functions retain App Check
enforcement and return a correlation ID with a verified response.

Automated verification completed for this revision:

- `flutter analyze`;
- the complete Flutter test suite;
- `npm test` in `functions/`;
- `npm run test:rules` and `npm run test:profile-rules` in `functions/`.

The Android and hosted-web rows below remain a device/browser smoke test. Do
not mark them complete from automated tests or deployment status alone.

| Flow | Android | Hosted web | Required evidence |
| --- | --- | --- | --- |
| Student signup and profile provisioning | Pending | Pending | `users/{uid}` and Auth/App Check valid logs |
| Teaching signup and profile provisioning | Pending | Pending | `users/{uid}` and Auth/App Check valid logs |
| Non-Teaching signup and profile provisioning | Pending | Pending | `users/{uid}` and Auth/App Check valid logs |
| Quick assessment | Pending | Pending | `assessments/quick_{uid}` and completion flag |
| Full assessment | Pending | Pending | one verified `full_{uid}_{submissionId}` document |
| Main profile edit and reload | Pending | Pending | server-confirmed name; protected fields unchanged |
| Secret Chat alias and photo | Pending | Pending | alias reservation, profile document, and Storage object |
| Secret Chat comment and counters | Pending | Pending | comment document and trigger-updated counters |

The Android app uses the Firebase project `mind-mates-cd2cf` and the
registered Android application ID `ph.edu.ucu.mindmates`.

## Android identity stabilization

`ph.edu.ucu.mindmates` is the permanent Android package for development and
future production builds. Gradle, the Android manifest, `MainActivity`,
`google-services.json`, and the Android `FirebaseOptions` must all reference
Firebase app ID `1:842251480963:android:4c05d169dbacf125eb50b6`.

Gradle now stops the build when `google-services.json` identifies another
package or Firebase Android app. The Flutter identity contract test also checks
all Android entrypoints and fails if the legacy `com.example.mind_mates`
activity returns:

```powershell
flutter test test/config/android_firebase_identity_test.dart
```

The legacy Firebase Android app remains in the same Firebase project only as a
temporary rollback reference. No current Android build uses it, and removing
it is deferred until both emulator and physical-phone smoke tests pass. This
does not require deleting or migrating existing Firebase Auth or Firestore
data.

## Local Android debug setup

1. Run the app once in debug mode:

   ```powershell
   flutter run
   ```

2. Copy the Firebase App Check debug token printed by the Android log.
3. In Firebase Console, open App Check for project `mind-mates-cd2cf`, select
   the Android app `ph.edu.ucu.mindmates`, and register that debug token.
4. Restart the app and confirm that protected callable requests no longer
   return an App Check rejection.

The app prints a startup reminder identifying the expected Android package. If
signup cannot create `users/{uid}`, the account is signed out and the Firebase
error is logged instead of allowing a partially initialized session into the
user app.

Use a separate registered token for every installation. Label the emulator
token `pixel-6a-emulator` and the phone token `physical-phone-debug`. Install an
updated build with `adb install -r` so the registered installation token is
preserved. Do not clear app data or uninstall after registering a token unless
you intend to capture and register the replacement token.

Debug tokens cannot be supplied through Dart defines. They must never appear
in source, documentation, shell scripts, logs shared as evidence, or Git.
Debug-only Firebase diagnostics record only the expected package, Firebase app
ID, build/provider mode, Firebase error code, and callable correlation ID. They
do not record account fields, credentials, tokens, or assessment answers.

### Current emulator verification status (2026-07-17)

The rebuilt debug APK was installed with `adb install -r` on `Pixel_6a` and
verified as package `ph.edu.ucu.mindmates`, a debuggable build, and Firebase app
ID `1:842251480963:android:4c05d169dbacf125eb50b6`. The app launches and the
Android debug provider activates without a startup failure.

This does not yet prove that the installation's registered credential is
accepted by protected callables. Complete one signup/profile or status request
and verify the callable log reports both `auth: VALID` and `app: VALID`. If it
returns an App Check rejection, register the credential printed by this exact
AVD installation under the `ph.edu.ucu.mindmates` Firebase app, then preserve
the installation data. Positive signup, Quick Assessment, and Full Assessment
device smoke tests remain pending until that request-level evidence is
recorded.

The release build must use Play Integrity. Do not disable App Check enforcement
on the deployed assessment or MindAid functions.

For the current pre-publish development phase, use a debug APK or `flutter run`
with `AndroidDebugProvider`. No Android SHA-256 or Google Play Console account
is needed for this path. The generated debug token must still be registered
manually in Firebase Console by an account with App Check administration
permission; a Firebase CLI identity without that permission will receive HTTP
403 from the App Check management API.

The release signing certificate for `ph.edu.ucu.mindmates` is registered in
Firebase. A debug emulator is a separate trust path: it must use
`AndroidDebugProvider`, and its generated token must be registered under the
same Android app before protected callables can be exercised.

For an APK installed from Google Play, verify the certificate independently:

1. In Google Play Console, open **Test and release > App integrity** and copy
   the **App signing key certificate SHA-256** for `ph.edu.ucu.mindmates`.
2. In Firebase Console, open **Project settings > Your apps > Android** for
   the same package and add that exact SHA-256. The upload-key SHA is not a
   substitute for the Play App Signing SHA.
3. In **App Check**, select the same Android app, enable **Play Integrity**,
   and keep enforcement enabled for protected callable functions.
4. Install the Play-distributed build (or its testing-track build), then retry
   signup. A sideloaded APK signed by a different key is not production
   evidence.

The Firebase app currently has more than one SHA-256 entry, so the Play
Console value must be compared directly rather than assuming the local
`android/key.properties` certificate is the one used by Google Play.

## Admin authentication verification

The administrator Auth identity, sole admin profile, employee reservation, and
locked `system_config/security` record were found to be internally aligned.
The hosted Admin site and repository use the same registered Firebase Web app,
API key, project, Auth domain, and Hosting domain. Do not delete that identity
to diagnose a raw `invalid-credential` message.

Admin login now separates credential, email-verification, App Check, profile,
staff-authorization, network, and super-administrator-confirmation failures.
Raw Firebase exception text is never displayed. A profile with
`accessRole: admin` cannot enter the portal unless the App Check-protected
`confirmSuperAdmin` callable confirms the locked security UID and returns a
safe correlation ID.

`system_config/security.superAdminUid` is the single authority for Functions
and Firestore Rules; `SUPER_ADMIN_UID` is no longer a deployment parameter.
Use only the guarded `admin:rotate:*` commands documented in
`docs/admin_web_deployment.md` to replace the identity. Preparation and dry-run
steps never delete the current administrator, and finalization remains blocked
until the replacement completes login and its mandatory password change.

This hardening was deployed on 2026-07-17. The App Check-protected
`confirmSuperAdmin` revision is `confirmsuperadmin-00009-him`; all deployed
Functions were verified to have no legacy administrator environment key. The
hosted JavaScript bundle matches the locally verified `admin_main.dart` release
build. Live replacement remains intentionally unstarted until the new email
and one-time password are entered through the rotation utility's hidden local
prompts.

## Local web setup

1. Register the Web app in Firebase App Check for `mind-mates-cd2cf` using the
   reCAPTCHA Enterprise provider and its score-based site key.
2. Keep the production key restricted to `mind-mates-cd2cf.web.app`. Do not add
   `localhost` to its allowed domains.
3. Run the web app. The registered public Enterprise site key is bundled as
   the safe default, so a normal command works:

   ```powershell
   flutter run -d chrome
   ```

4. On localhost, open the browser console and copy the generated `AppCheck
   debug token`. Register it under Firebase Console > App Check > Apps >
   `mind_mates (web)` > Manage debug tokens.
5. Clear localhost site data and restart Flutter after registering or revoking
   a debug token. Each new browser profile generates its own token.

`RECAPTCHA_ENTERPRISE_SITE_KEY` remains available as a build-time override for
another Firebase environment. The Enterprise site key is public configuration;
the localhost debug token remains secret.

For repeatable PowerShell runs and release builds, keep the registered public
site key in the current shell:

```powershell
$env:RECAPTCHA_ENTERPRISE_SITE_KEY='your-registered-site-key'
flutter run -d chrome --dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=$env:RECAPTCHA_ENTERPRISE_SITE_KEY
flutter build web --release --dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=$env:RECAPTCHA_ENTERPRISE_SITE_KEY
```

Register every deployed hosting domain on the Enterprise key. Localhost uses a
registered App Check debug token instead of a production-domain exception. A
debug token is a secret: never commit it or place it in a Dart define.

## New-account smoke test

Use a new Student, Teaching, and Non-Teaching account and verify:

- signup creates `users/{uid}` in `mind-mates-cd2cf`;
- login loads that same profile;
- quick assessment creates `assessments/quick_{uid}`;
- the user profile receives `quickAssessmentCompleted: true`;
- MindAid callable requests reach `sendMindAidMessage` in `asia-southeast1`;
- browser assessment requests show `auth: VALID` and `app: VALID` in Firebase
  callable verification logs;
- profile, appointment, Secret Chat, and admin callable requests do not report
  `function-not-found`, project mismatch, permission denied, or App Check errors.

## Deployment verification

From the repository root:

```powershell
firebase functions:list --project mind-mates-cd2cf
```

The list must include `submitQuickAssessment` and `submitFullAssessment`.
It must also include `provisionAppUserProfile`, `getAssessmentStatus`, and the
four recovery-email/password-recovery callables. For debug account cleanup, it
must include `previewInactiveAppUserDeletion` and `deleteInactiveAppUsers`.

The backend is deployed to the existing project with:

```powershell
firebase deploy --project mind-mates-cd2cf --only functions,firestore:rules,firestore:indexes
```

Profile creation and assessment completion are server-owned. After deployment,
run `npm run profiles:dry-run` from `functions/`, review its aggregate output,
then run `npm run profiles:apply`. Auth-only accounts are preserved and routed
through retryable profile setup.

Password recovery additionally requires the Firebase Trigger Email extension
and SMTP delivery credentials. Never
grant client access to `user_private`, recovery-token, rate-limit, or `mail`
collections.

## Debug inactive-account cleanup

The admin App Users page shows `Delete inactive test users` only in a Flutter
debug build and only after the configured super-administrator session is
confirmed. The Functions backend independently enforces super-administrator
access even if a caller invokes the callable without the UI.

Before testing, create disposable app-user accounts only; do not use staff,
counselor, or administrator accounts. Set their Firestore `lastActiveAt` (or,
when absent, `createdAt`) to more than seven days ago. Accounts with neither
timestamp are reported and skipped.

1. Deploy Functions, then run the admin portal in debug mode.
2. Open User Management > App Users and select
   `Delete inactive test users`.
3. Verify the preview contains only the expected public user IDs and cutoff.
4. Type `DELETE`, confirm, and wait for the completion summary.
5. Verify the deleted UID is absent from Firebase Authentication, `users`,
   UID-owned Firestore records and subcollections, public-ID mappings, Secret
   Chat content, and `secret_chat_profiles/{uid}/` Storage files.
6. Verify recent app users and every staff/counselor/admin account remain.
7. Re-run the action to confirm it is idempotent and retries any job previously
   recorded as failed in `_account_deletion_jobs`.

The cleanup preserves anonymous daily aggregate totals but removes nested
UID-addressable analytics records. Each run adds a UID-free summary event to
`admin_audit_logs`.
