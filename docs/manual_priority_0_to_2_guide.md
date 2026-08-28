# MindMate Manual Implementation Guide: Priorities 0–2

This guide is for manually completing the current MindMate work from highest to
lowest priority. Perform the tasks in order. Do not skip a prerequisite task,
because later modules depend on Firebase configuration, authentication, rules,
and safety decisions.

## How to use this guide

For each task:

1. Read the required setup.
2. Inspect every listed file before editing.
3. Make one small change at a time.
4. Run the verification commands.
5. Check the completion criteria before continuing.

Never edit generated files unless the task specifically says to regenerate them.
Do not commit secrets, App Check debug tokens, service-account keys, or private
student data.

## Baseline setup

Install and verify:

```powershell
flutter --version
firebase --version
node --version
npm --version
```

From the repository root:

```powershell
flutter pub get
cd functions
npm ci
npm run build
cd ..
flutter analyze
```

Required local files/configuration:

- `firebase.json`
- `.firebaserc`
- `lib/firebase_options.dart`
- `lib/core/config/app_environment.dart`
- `android/app/google-services.json`
- `android/app/build.gradle.kts`
- `ios/Runner/Info.plist`
- `web/index.html`
- `web/firebase-messaging-sw.js`
- `functions/.env` or Firebase Secret Manager values, if required by Functions

Use the Firebase project selected by `.firebaserc` and confirm it with:

```powershell
firebase use
firebase projects:list
```

Baseline verification:

```powershell
flutter analyze
flutter test
cd functions
npm test
cd ..
```

Record the baseline failures before making changes.

# Priority 0 — Release blockers

## P0-1. Firebase identity, environments, and App Check

### Goal

Ensure Android, iOS, web, Functions, and Firebase all target the intended
project and that App Check behaves correctly in development and production.

### Files to inspect

- `firebase.json`
- `.firebaserc`
- `lib/firebase_options.dart`
- `lib/core/config/app_environment.dart`
- `lib/core/config/android_firebase_identity.dart`
- `lib/services/firebase/firebase_app_check_service.dart`
- `lib/services/firebase/firebase_callable_router.dart`
- `android/app/build.gradle.kts`
- `android/app/google-services.json`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `web/index.html`
- `test/config/android_firebase_identity_test.dart`
- `test/config/app_environment_test.dart`
- `test/services/firebase_app_check_service_test.dart`
- `docs/firebase_development.md`

### Manual steps

1. Choose the canonical Android application ID. Use the same value in:
   `android/app/build.gradle.kts`, `AndroidManifest.xml`, and
   `google-services.json`.
2. In Firebase Console, open the selected project and register exactly that
   Android package. Add the correct SHA-1/SHA-256 fingerprints for debug and
   release signing.
3. Register the iOS bundle ID and web app used by `lib/firebase_options.dart`.
4. Regenerate Firebase configuration only after the registrations are correct:

   ```powershell
   flutterfire configure --project <project-id>
   ```

5. Confirm `firebase.json` points Functions, Firestore, Storage, and Hosting to
   the intended project.
6. In Firebase Console, configure App Check for Android, iOS, and web.
7. Register the Android debug App Check token from the debug run. Never place
   that token in source code or a Dart define.
8. Keep App Check enforcement enabled for production callables. Use development
   aliases only for local development, as documented in `firebase_callable_router.dart`.
9. Verify the web App Check site key is present in the approved environment
   configuration.

### Commands

```powershell
flutter test test/config/android_firebase_identity_test.dart
flutter test test/config/app_environment_test.dart
flutter test test/services/firebase_app_check_service_test.dart
flutter build apk --debug
flutter build web
```

### Completion criteria

- One Android package matches the Firebase registration.
- No identity-alignment test failure remains.
- Debug App Check works on the intended developer device.
- Production callables still enforce App Check.
- No API keys, tokens, or service-account credentials were added to Git.

## P0-2. Authentication and account recovery

### Files to inspect

- `lib/providers/auth_provider.dart`
- `lib/repositories/auth_repository.dart`
- `lib/services/auth/auth_service.dart`
- `lib/services/auth/recovery_service.dart`
- `lib/features/authentication/screens/login_screen.dart`
- `lib/features/authentication/screens/signup_screen.dart`
- `lib/features/authentication/screens/forgot_password_screen.dart`
- `lib/features/authentication/screens/reset_password_screen.dart`
- `lib/features/authentication/screens/recovery_email_screen.dart`
- `lib/features/authentication/screens/finish_account_setup_screen.dart`
- `lib/features/authentication/auth_flow_routes.dart`
- `functions/src/account_recovery.ts`
- `functions/src/account_integrity.ts`
- `functions/src/index.ts`
- `firestore.rules`
- `test/providers/auth_provider_test.dart`
- `test/features/authentication/startup_auth_flow_test.dart`
- `test/features/authentication/recovery_flow_test.dart`

### Manual steps

1. Trace signup from form validation through Firebase Auth and profile
   provisioning.
2. Ensure profile lookup/provisioning failures preserve the authenticated user
   and display a retry action.
3. Separate App Check errors, duplicate-account errors, network errors, and
   profile failures in the user-facing error mapper.
4. Verify sign-out clears the cached user/profile state.
5. Verify password-reset links route correctly on web and mobile.
6. Verify disabled, pending, rejected, and approved staff accounts.
7. Confirm Firestore clients cannot directly create protected user profiles.

### Commands

```powershell
flutter test test/providers/auth_provider_test.dart
flutter test test/features/authentication
flutter test test/services/firebase_error_message_test.dart
```

### Completion criteria

- All authentication tests pass.
- A profile setup failure gives a retryable state rather than signing the user
  out unnecessarily.
- Recovery links work for valid, expired, and already-used links.
- No raw Firebase exception text is shown to users.

## P0-3. Security, privacy, retention, and deletion

### Files to inspect

- `firestore.rules`
- `storage.rules`
- `functions/src/profile_rules.rules.ts`
- `functions/src/firebase_secret_chat_rules.rules.ts`
- `functions/src/firestore_sleep_rules.rules.ts`
- `functions/src/user_activity_rules.rules.ts`
- `functions/src/admin_security.ts`
- `functions/src/admin_directory.ts`
- `lib/services/firebase/storage_service.dart`
- `lib/repositories/user_repository.dart`
- `lib/repositories/secret_chat_repository.dart`
- `lib/repositories/report_repository.dart`
- `lib/repositories/mind_aid_context_repository.dart`
- `lib/features/profile/screens/profile_screen.dart`
- `docs/support_contact_audit.md`

### Manual steps

1. Inventory every collection and Storage path containing sensitive data.
2. For each collection, document owner access, staff access, admin access,
   create/update/delete authority, and retention period.
3. Add a callable account-deletion workflow that removes or anonymizes data
   according to the approved retention policy.
4. Add user-facing deletion confirmation and re-authentication.
5. Remove orphaned profile photos and other Storage files during deletion.
6. Confirm analytics never includes raw assessment answers, private mood notes,
   or AI transcripts.
7. Run Firebase Emulator Suite rules tests before deployment.

### Commands

```powershell
firebase emulators:start --only firestore,storage,functions
cd functions
npm test
cd ..
```

### Completion criteria

- Every sensitive collection has a documented owner and retention policy.
- Account deletion is tested and auditable.
- Staff access is role-limited and logged.
- Storage files cannot be read by unauthorized users.

## P0-4. Assessment governance and crisis safety

### Files to inspect

- `docs/assessment_policy.md`
- `docs/assessment_safety_protocol.md`
- `lib/features/student_assessment/config/assessment_policy.dart`
- `lib/features/student_assessment/services/student_assessment_calculator.dart`
- `lib/features/student_assessment/services/assessment_interpretation_engine.dart`
- `lib/features/student_assessment/services/assessment_safety_config.dart`
- `functions/src/assessment/catalog.ts`
- `functions/src/assessment/calculator.ts`
- `functions/src/assessment/submission_policy.ts`
- `functions/src/assessment/submissions.ts`
- `functions/src/mind_aid.ts`
- `lib/core/config/support_contact_config.dart`

### Manual steps

1. Mark all current assessments as experimental in product copy.
2. Obtain written professional review of wording, scoring, weights,
   thresholds, and follow-up recommendations.
3. Record the approved question-set and algorithm versions.
4. Add consent and privacy text before the first question.
5. Keep self-harm/crisis screening disabled until the complete safety protocol
   is approved.
6. Verify emergency, campus, and after-hours contacts independently.
7. Define counselor notification ownership, acknowledgment deadlines, and
   failure behavior.
8. Red-team crisis phrases in both local MindAid and server Functions.

### Commands

```powershell
flutter test test/features/student_assessment
cd functions
npm test -- --test-name-pattern assessment
npm test -- --test-name-pattern mind_aid
cd ..
```

### Completion criteria

- No assessment is described as a diagnosis or validated clinical instrument.
- Safety escalation has verified contacts and an operational owner.
- The app never claims a notification was delivered without confirmation.

# Priority 1 — Core user workflows

## P1-1. Student assessment experience

### Files

- `lib/features/quick_assessment/`
- `lib/features/student_assessment/`
- `lib/providers/assessment_provider.dart`
- `lib/repositories/assessment_repository.dart`
- `functions/src/assessment/`
- `contracts/assessment_question_ids.v2.json`
- `firestore.rules`
- `test/features/quick_assessment/`
- `test/features/student_assessment/`
- `test/repositories/assessment_submission_client_test.dart`

### Manual steps

1. Test every role and question branch.
2. Test back navigation, app restart, incomplete responses, duplicate submit,
   and network retry.
3. Confirm the client cannot forge scores or classifications.
4. Confirm the server and Dart question contracts match.
5. Add assessment history and an explanation of each result band.

### Verify

```powershell
flutter test test/features/quick_assessment test/features/student_assessment
cd functions; npm test -- --test-name-pattern assessment; cd ..
```

## P1-2. Mood tracking

### Files

- `lib/features/mood/screens/log_mood_screen.dart`
- `lib/providers/mood_provider.dart`
- `lib/repositories/mood_repository.dart`
- `lib/models/mood_model.dart`
- `functions/src/mood_logging.ts`
- `functions/src/mood_rules.rules.ts`
- `firestore.rules`
- `test/repositories/mood_repository_test.dart`
- `test/models/mood_model_test.dart`

### Manual steps

1. Test creating, editing, deleting, and reloading a daily mood.
2. Test the Asia/Manila date boundary.
3. Add offline draft/queue behavior.
4. Add trend charts and clear empty states.
5. Add user deletion controls.

### Verify

```powershell
flutter test test/repositories/mood_repository_test.dart test/models/mood_model_test.dart
```

## P1-3. Sleep and breathing

### Files

- `lib/features/sleep/`
- `lib/providers/sleep_provider.dart`
- `lib/repositories/sleep_repository.dart`
- `lib/features/breathing/`
- `lib/providers/breathing_provider.dart`
- `lib/repositories/breathing_repository.dart`
- `functions/src/sleep_wellness.ts`
- `functions/src/breathing_sessions.ts`
- `functions/src/firestore_sleep_rules.rules.ts`
- `functions/src/breathing_session_rules.rules.ts`
- `test/features/sleep/`
- `test/features/breathing/`

### Manual steps

1. Verify local encrypted storage and cloud synchronization.
2. Test time zones, overnight sleep, invalid times, and edits.
3. Add retry and conflict behavior when synchronization fails.
4. Confirm staff see only approved shared summaries.
5. Verify breathing sessions are recorded once, even after retries.

### Verify

```powershell
flutter test test/features/sleep test/features/breathing
cd functions; npm test -- --test-name-pattern "sleep|breathing"; cd ..
```

## P1-4. Counseling and appointments

### Files

- `lib/features/counseling/screens/services_screen.dart`
- `lib/features/counseling/screens/pacc_counseling_screen.dart`
- `lib/features/counseling/screens/service_detail_screen.dart`
- `lib/features/counseling/widgets/appointment_details_sheet.dart`
- `lib/features/home/screens/home_appointment_calendar_screen.dart`
- `lib/providers/appointment_provider.dart`
- `lib/repositories/appointment_repository.dart`
- `lib/models/appointment_model.dart`
- `functions/src/appointment_workflow.ts`
- `functions/src/index.ts`
- `firestore.rules`
- `docs/appointment_submission_audit.md`
- `test/features/counseling/services_screen_test.dart`
- `test/providers/appointment_provider_test.dart`

### Manual steps

1. Replace fixed client-only slots with server-provided availability.
2. Add holidays, counselor schedules, closures, and time-zone handling.
3. Keep server validation and transactional duplicate prevention.
4. Test today, future dates, no availability, cancellation, rescheduling,
   network failure, and retry.
5. Add appointment reminders and user notification preferences.

### Verify

```powershell
flutter test test/features/counseling test/providers/appointment_provider_test.dart
cd functions; npm test -- --test-name-pattern appointment; cd ..
```

## P1-5. MindAid AI companion

### Files

- `lib/features/mind_aid/`
- `lib/providers/mind_aid_provider.dart`
- `lib/repositories/mind_aid_repository_screen.dart`
- `lib/repositories/mind_aid_context_repository.dart`
- `lib/services/firebase/mind_aid_cloud_service.dart`
- `assets/data/mind_aid/`
- `functions/src/mind_aid.ts`
- `functions/src/mind_aid_cx_spec.ts`
- `functions/src/configure_mind_aid_cx.ts`
- `functions/src/mind_aid_*_rules.rules.ts`
- `docs/mind_aid_cx_operations.md`
- `test/features/mind_aid/`
- `functions/src/mind_aid.test.ts`

### Manual steps

1. Keep Dialogflow production rollout disabled during review.
2. Test local fallback, cloud success, timeout, offline mode, and rate limits.
3. Test ordinary support, assessment support, counseling handoff, and crisis
   disclosures in English and Taglish.
4. Confirm unknown action types are ignored.
5. Add consent, transcript deletion, and privacy explanations.
6. Monitor only aggregate metrics; do not export raw transcripts.

### Verify

```powershell
flutter test test/features/mind_aid
cd functions
npm run build
npm test -- --test-name-pattern mind_aid
cd ..
```

# Priority 2 — Completion and quality improvements

## P2-1. Dashboard and placeholder features

### Files

- `lib/features/home/screens/home_screen.dart`
- `lib/features/home/widgets/home_dashboard_widgets.dart`
- `lib/features/home/models/home_dashboard_data.dart`
- `lib/routes/route_names.dart`
- `lib/routes/app_pages.dart`
- `lib/features/profile/screens/mental_health_insights_screen.dart`
- `test/features/home/home_screen_test.dart`
- `test/features/insights/insights_screen_test.dart`

### Manual steps

1. Inventory every dashboard card and its callback.
2. Replace `BlankHomeFeaturePage` destinations with real screens.
3. Remove cards that are not ready instead of showing misleading actions.
4. Replace “Coming soon” and “Video coming soon” content with real content or
   an explicit unavailable state.
5. Add route and widget tests for every card.

### Verify

```powershell
rg -n "BlankHomeFeaturePage|Coming soon|Video coming soon" lib
flutter test test/features/home test/features/insights
```

## P2-2. Secret Chat moderation and privacy

### Files

- `lib/features/secret_chat/`
- `lib/providers/secret_chat_provider.dart`
- `lib/repositories/secret_chat_repository.dart`
- `lib/models/secret_chat_model.dart`
- `lib/models/secret_chat_profile.dart`
- `lib/features/secret_chat/domain/secret_chat_safety_validator.dart`
- `functions/src/firebase_secret_chat_rules.rules.ts`
- `functions/src/index.ts`
- `storage.rules`
- `test/repositories/secret_chat_repository_test.dart`
- `test/providers/secret_chat_provider_test.dart`

### Manual steps

1. Add report, block, mute, and moderation-queue workflows.
2. Add spam/rate limits and abuse monitoring.
3. Document the limits of anonymity.
4. Add profile-photo deletion and orphan cleanup.
5. Define content retention and deletion behavior.

### Verify

```powershell
flutter test test/repositories/secret_chat_repository_test.dart test/providers/secret_chat_provider_test.dart
cd functions; npm test -- --test-name-pattern secret_chat; cd ..
```

## P2-3. Facial emotion recognition decision

### Files

- `lib/features/facial_emotion/`
- `lib/providers/facial_emotion_provider.dart`
- `lib/services/ai/facial_emotion_service.dart`
- `lib/services/ai/emotion_classifier.dart`
- `lib/features/home/models/home_dashboard_data.dart`
- `lib/features/home/screens/home_screen.dart`
- `pubspec.yaml` camera and image dependencies
- Android/iOS camera permission manifests

### Manual steps

1. Decide whether this feature is genuinely required.
2. If yes, implement permission handling, camera capture, inference, consent,
   accuracy limitations, result storage, and deletion.
3. If no, remove the dashboard card, unused dependencies, and misleading copy.
4. Do not infer a mental-health diagnosis from facial emotion output.

### Verify

```powershell
rg -n "Facial Recognition|facial|emotion" lib android ios
flutter analyze
```

## P2-4. Admin, notifications, accessibility, localization, and documentation

### Files

- `lib/admin_main.dart`
- `lib/features/admin/`
- `lib/services/firebase/notification_service.dart`
- `lib/services/firebase/app_notification_service.dart`
- `lib/providers/theme_provider.dart`
- `lib/core/theme/`
- `lib/core/constants/app_strings.dart`
- `web/firebase-messaging-sw.js`
- `README.md`
- `docs/`
- `.github/workflows/`

### Manual steps

1. Add admin search, filtering, queue states, and audit-visible bulk actions.
2. Test push notification registration, refresh, expiry, and multiple devices.
3. Add notification preferences and appointment reminders.
4. Add accessibility labels, keyboard navigation, contrast checks, and large
   text testing.
5. Decide whether dark mode is supported; `lib/app.dart` currently forces light
   mode.
6. Add localization infrastructure and translate user-facing strings.
7. Expand `README.md` with setup, environments, testing, deployment, App Check,
   release signing, and known limitations.

### Verify

```powershell
flutter analyze
flutter test
cd functions; npm run build; npm test; cd ..
```

# Final Priority 0–2 release checklist

Before release, confirm:

- [ ] Firebase identity tests pass.
- [ ] App Check is configured on every target platform.
- [ ] Authentication and recovery tests pass.
- [ ] Firestore and Storage rules tests pass.
- [ ] Account deletion and retention behavior is documented.
- [ ] Assessment approval and safety sign-off are recorded.
- [ ] Appointment availability is accurate and server-validated.
- [ ] MindAid safety and fallback tests pass.
- [ ] No dashboard card opens an unintended blank page.
- [ ] No user-facing feature is labeled complete while showing placeholder content.
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] `cd functions; npm run build; npm test` passes.
- [ ] Production deployment is performed only after staging verification.
