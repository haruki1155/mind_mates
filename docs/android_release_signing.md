# Android release configuration

MindMates uses the permanent Android application ID and namespace
`ph.edu.ucu.mindmates`. Release builds must not use the Android debug keystore.

Generate and securely back up an upload keystore:

```powershell
keytool -genkeypair -v `
  -keystore android/upload-keystore.jks `
  -alias mindmates-upload `
  -keyalg RSA `
  -keysize 4096 `
  -validity 10000
```

Create an untracked `android/key.properties` file with:

```properties
keyAlias=mindmates-upload
storeFile=upload-keystore.jks
storePassword=...
keyPassword=...
```

The keystore and passwords must be supplied by the deployment environment or
local secret manager. Never commit or lose them.

Register `ph.edu.ucu.mindmates` in Firebase project `mind-mates-cd2cf`, add the
upload certificate SHA-1 and SHA-256 fingerprints, and replace
`android/app/google-services.json`. Update the Android `apiKey` and `appId` in
`lib/firebase_options.dart` from that same Firebase Android client while
preserving all other platform configurations.

After synchronization, build without a Gradle application-ID override:

```powershell
Remove-Item Env:ORG_GRADLE_PROJECT_androidApplicationId -ErrorAction SilentlyContinue
flutter build appbundle --release
```
