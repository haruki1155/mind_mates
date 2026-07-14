# MindMate Admin web deployment

Firebase Hosting is reserved for the staff administration portal. The student
and wellness application is distributed only as a native mobile application.

## Build and verify

From the repository root, run:

```powershell
flutter pub get
flutter test test/app_bootstrap_test.dart
flutter analyze
flutter build web --release --target lib/admin_main.dart --dart-define=RECAPTCHA_V3_SITE_KEY=YOUR_RECAPTCHA_V3_SITE_KEY
```

The production web entry point must remain `lib/admin_main.dart`. The default
`lib/main.dart` also selects the admin portal when compiled for web as a safety
measure, but deployment automation uses the explicit admin target.

## Deploy

```powershell
firebase deploy --only hosting --project mind-mates-cd2cf
```

After deployment, open `https://mind-mates-cd2cf.web.app/` in a private browser
window and confirm it displays `MindMate Admin`. Only Firebase users whose
`users/{uid}.role` is `admin` or `counselor` may enter the portal.

Do not deploy a generic mobile web bundle to this Hosting site.
