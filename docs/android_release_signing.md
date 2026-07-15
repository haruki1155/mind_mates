# Android release configuration

Release builds must not use the Android debug keystore or the template
`com.example.mind_mates` application ID.

Provide the production Firebase Android app and package name through the
Gradle property `androidApplicationId`, and create an untracked
`android/key.properties` file with:

```properties
keyAlias=...
storeFile=.../release-upload.jks
storePassword=...
keyPassword=...
```

The keystore and passwords must be supplied by the deployment environment or
local secret manager. The Firebase Android configuration must contain a client
for the same production package name before release builds are enabled.
