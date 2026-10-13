# Noti Release Checklist

## Firebase

- Email/Password and Anonymous Authentication are enabled.
- Every director has an enabled Firestore `users/<uid>` record with
  `role: "director"`.
- Firestore rules and both Cloud Functions are deployed to `noti-android-1527`.
- The function runtime service account has Firestore access and Firebase Cloud
  Messaging API Admin access.
- A test broadcast is received on a physical Android device with notifications
  enabled.

## Android

- Keep `android/noti-release.jks` and `android/key.properties` backed up in a
  secure password manager or encrypted storage. Never commit them.
- Register the release SHA-1 and SHA-256 fingerprints in Firebase/Google Cloud
  before enabling any Android OAuth provider in the future.
- Test the signed release APK on a phone and a tablet, including notification
  permission, sign-in, PIN verification, creating/editing announcements, and
  device registration.

## Distribution

- Use the signed `.aab` for Google Play and let Play App Signing manage store
  delivery.
- Use the signed `.apk` only for direct installation on managed devices.
- Publish a privacy policy that explains the device information and FCM token
  stored for device management and notifications.
