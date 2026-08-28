# MindMate Admin web deployment

Firebase Hosting is reserved for the staff administration portal. The student
and wellness application is distributed only as a native mobile application.

## Build and verify

From the repository root, run:

```powershell
flutter pub get
flutter test test/app_bootstrap_test.dart
flutter analyze
flutter build web --release --target lib/admin_main.dart --dart-define=APP_ENV=production --dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=YOUR_RECAPTCHA_ENTERPRISE_SITE_KEY
```

The production web entry point must remain `lib/admin_main.dart`. The default
`lib/main.dart` also selects the admin portal when compiled for web as a safety
measure, but deployment automation uses the explicit admin target.

## Deploy

Deploy Functions and Rules without a duplicated administrator parameter:

```powershell
firebase deploy --only functions --project mind-mates-cd2cf
firebase deploy --only firestore:rules,firestore:indexes --project mind-mates-cd2cf
```

The locked `system_config/security.superAdminUid` field is the sole runtime
authority used by Functions and Firestore Rules. The matching user must have
`accessRole: admin`. Client code cannot write the security document or the
private `_super_admin_rotations` collection.

Before opening the redesigned User Management page, preview and apply stable
anonymous IDs for existing app users:

```powershell
cd functions
npm run public-ids:dry-run
npm run public-ids:apply
cd ..
```

Future app-user profiles receive a privacy-safe `USR-XXXXXX` identifier from
the deployed `assignPublicIdOnUserCreate` trigger. The UID mappings and public
ID reservations are server-only collections.

```powershell
firebase deploy --only hosting:admin --project mind-mates-cd2cf
```

After deployment, open `https://mind-mates-cd2cf.web.app/` in a private browser
window and confirm it displays `MindMate Admin`. Approved `portalStaff` and
`counselor` profiles may enter; only the configured super-administrator can
approve registrations, change access, disable accounts, or maintain the
organization directory.

Do not deploy a generic mobile web bundle to this Hosting site.

## Staging admin web

`mindmate-staging` has its own Default Web App, Hosting site, and reCAPTCHA
Enterprise key (`MindMate Admin - Staging`, restricted to
`mindmate-staging.web.app`). Reuse that existing web app registration; do not
create a second one.

Release builds are rejected for any environment other than production (see
`AppEnvironmentConfig.validate`), matching the same rule already enforced for
Android release builds. Build the staging admin bundle in `--profile` mode
instead of `--release`:

```powershell
flutter build web --profile --target lib/admin_main.dart --dart-define=APP_ENV=staging --dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=6Le17JgtAAAAACbHth-LPHcS_P2n4ejBuddUYReM
firebase deploy --only hosting:admin --project mindmate-staging
```

The very first super-administrator in a brand-new project cannot be created by
`admin:rotate:*` (it only rotates an existing admin) or by
`provision_super_admin.ts` (dry-run only). Use the staging-only, guarded
bootstrap script instead, which refuses to run against any project except
`mindmate-staging` and refuses if an admin already exists:

```powershell
cd functions
npm run staging-admin:bootstrap:dry-run -- --email <new-admin-email>
npm run staging-admin:bootstrap:apply -- --email <new-admin-email> --out <local-output-path>
```

The generated password is written only to the local `--out` file, never to
the terminal, logs, or chat. Sign in once, then delete that file.

## Guarded super-administrator replacement

Never send an administrator email or password through chat, a command-line
argument, a Dart define, or a committed environment file. The rotation utility
accepts both through non-echoing terminal prompts and prints only boolean/count
checks.

From `functions/`, use this sequence:

```powershell
npm run admin:dry-run
npm run admin:rotate:prepare
npm run admin:rotate:prepare:apply
```

The candidate is created as pending Portal Staff and the current administrator
remains active. Sign in once with the one-time password. If the mailbox is not
verified, the Admin portal sends a Firebase verification message and signs the
candidate out. Follow that message, sign in again, and expect the pending
approval response. This proves mailbox and password control without granting
administrator access.

Preview and apply the atomic cutover only after those checks pass:

```powershell
npm run admin:rotate:cutover
npm run admin:rotate:cutover:apply
```

The cutover promotes the candidate, disables the old profile, transfers the
employee-ID reservation, changes the locked security UID, and writes an audit
event in one Firestore transaction. The old Auth identity remains available
for rollback until final verification.

Sign in as the replacement on the hosted site, complete the mandatory password
change, restart the browser, and verify User Management. Then preview and apply
finalization:

```powershell
npm run admin:rotate:finalize
npm run admin:rotate:finalize:apply
```

Finalization refuses to delete anything until the replacement is the active
security UID, has signed in after cutover, and has completed its password
change. It deletes only the old Auth identity and profile; historical audit
records remain immutable. Before finalization, recover with:

```powershell
npm run admin:rotate:rollback
npm run admin:rotate:rollback:apply
```
