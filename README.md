# Noti Android Release Guide

Noti is an Android church-announcement app backed by Firebase Authentication,
Cloud Firestore, Cloud Messaging, and Cloud Functions.

## Production prerequisites

1. In the Firebase project `noti-android-1527`, enable Email/Password and
   **Anonymous** Authentication providers. Anonymous Authentication gives
   each member installation a private Firebase identity used to protect its
   device record.
2. Create each administrator in Firebase Authentication. After the person has
   signed in once, create `users/<their Firebase UID>` in Firestore with:

   ```text
   role: "admin"
   enabled: true
   email: "leader@example.org"
   ```

   The UID is shown in Firebase Authentication's Users list. Do this **before**
   deploying the Firestore rules, otherwise that account cannot access admin
   tools.
3. Enable the Blaze billing plan before deploying the Gen 2 Cloud Function.
   Firebase uses it to deliver announcement push notifications securely.
4. In Google Cloud Console, restrict the Android Firebase API key to package
   `org.ciani01.noti` and the release signing SHA-1/SHA-256 certificates.
5. In Firebase Console, confirm Cloud Messaging API (V1) is enabled. The
   deployed `sendTestPush` and `sendAnnouncementPush` functions use it for
   topic broadcasts.

## Distribution checklist

Before installing the release on church devices or submitting it to Google
Play, complete these checks:

1. In Firebase Authentication, keep Email/Password and Anonymous providers
   enabled. Create only the administrator accounts that should access Noti
   Admin.
2. Ensure every administrator has an enabled `users/<uid>` Firestore record
   with `role: "admin"`. The Cloud Function checks this server-side before
   sending notifications.
3. Deploy the checked-in Firestore rules and Cloud Functions. The function
   runtime account needs Firestore access and the Firebase Cloud Messaging API
   Admin role; both are already configured for this Firebase project.
4. Create a public privacy-policy page before Google Play submission. The app
   collects a generated app device ID, device/app details, FCM token, and
   recent activity time to provide device management and notifications.
5. Build a signed App Bundle for Google Play. Use the signed APK only for
   direct installation on managed devices.

## Secure Firebase deployment

Review the rules, then deploy them and the announcement push function:

```bash
firebase deploy --only firestore:rules,functions --project noti-android-1527
```

The Functions send notifications to the `announcements` topic when an
authorized administrator creates an announcement or sends a test broadcast.
They also record delivery logs in `notification_logs`.

## Production Android signing

Do not use the debug signing key for a distributed app. Generate and back up a
keystore once; losing it prevents future app updates.

```bash
keytool -genkeypair -v \
  -keystore android/noti-release.jks \
  -alias noti-release \
  -keyalg RSA -keysize 4096 -validity 10000
```

Copy `android/key.properties.example` to `android/key.properties`, fill in the
passwords you selected, and keep both the keystore and passwords outside source
control. `key.properties` and `.jks` files are ignored. Back up the keystore
and its passwords somewhere secure; they are required for every future update.

Build the Play Store bundle with symbol files:

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

The output is `build/app/outputs/bundle/release/app-release.aab`.

For managed tablets that install the app directly, build a signed APK:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

The output is `build/app/outputs/flutter-apk/app-release.apk`.

## Local development

Use the Android emulator or a connected Android device:

```bash
flutter run -d emulator-5554
```

The macOS target requires a complete Xcode installation. It is not needed to
build the Android app.
