# Firebase runtime verification

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

The corrected functions were deployed successfully to `mind-mates-cd2cf` at
2026-07-16 14:10 UTC. `submitFullAssessment` is active on revision
`submitfullassessment-00005-zek`; the only `Invalid full-assessment answer`
entries visible immediately after deployment were the historical pre-deploy
requests from 13:52-13:53 UTC.

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

The release build must use Play Integrity. Do not disable App Check enforcement
on the deployed assessment or MindAid functions.

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
