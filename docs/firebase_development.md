# Firebase development

MindMates uses isolated Firebase projects. Testers must use the staging Android
flavor, which is permanently configured for `mindmate-staging`; it cannot use
production Firebase credentials.

| Environment | Firebase project | Android package | Intended use |
| --- | --- | --- | --- |
| development | `mindmate-dev-4e91c` | `com.example.mind_mates.dev` | local developer work |
| staging | `mindmate-staging` | `com.example.mind_mates.staging` | tester builds and test data |
| production | `mind-mates-cd2cf` | `com.example.mind_mates` | public release only |

Do not use `APP_ENV=staging` for the admin web until a separate staging web app
has been registered and its generated Firebase options have been added. The
app intentionally fails instead of falling back to production web credentials.

## Staging Android for testers

Staging debug builds use the protected callable names in `mindmate-staging`.
They use Firebase App Check's Android debug provider instead of Play Integrity.
Each tester must have their debug token registered in the **staging** Firebase
project; never register it in production.

```text
flutter run --flavor staging --dart-define=APP_ENV=staging
```

Build a shareable tester APK with:

```text
flutter build apk --debug --flavor staging --dart-define=APP_ENV=staging
```

## Production Android

Release builds use the original callable names, such as `getAssessmentStatus`
and `submitQuickAssessment`. Those wrappers explicitly use
`enforceAppCheck: true`; Android release builds activate Play Integrity.

```text
flutter build apk --release --flavor production --dart-define=APP_ENV=production
```

Release startup rejects any environment other than `production`.

## Deploying Functions

Deploy to staging explicitly; do not rely on the Firebase CLI default project.

```text
npx -y firebase-tools@latest deploy --project mindmate-staging --only functions,firestore:rules,firestore:indexes,storage
```

Before tester sign-up, enable Email/Password authentication in
`mindmate-staging`, create its default Firestore database and Storage bucket,
and register tester App Check debug tokens. The profile provisioning callable
must be deployed before a new account can complete setup.

After deployment, verify these production-named Functions exist in the
**staging** project:

- Production: `getAssessmentStatus`, `submitQuickAssessment`,
  `submitFullAssessment`, `provisionAppUserProfile`, `sendMindAidMessage`.
The `Dev` aliases are local-development compatibility endpoints. Do not use or
distribute them to external testers.
